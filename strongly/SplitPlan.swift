import Foundation
import Combine

enum SplitType: String, CaseIterable, Codable {
    case pushPullLegs = "Push/Pull/Legs"
    case upperLower = "Upper/Lower"
    case fullBody = "Full Body"
    case hybrid = "Hybrid (PPL + UL)"
}

enum DayType: String, CaseIterable, Codable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case upper = "Upper"
    case lower = "Lower"
    case full = "Full"
    case rest = "Rest"
}

struct SplitDayConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var dayIndex: Int
    var dayType: DayType
    var customMuscles: [MuscleGroup]?

    init(id: UUID = UUID(), dayIndex: Int, dayType: DayType, customMuscles: [MuscleGroup]? = nil) {
        self.id = id
        self.dayIndex = dayIndex
        self.dayType = dayType
        self.customMuscles = customMuscles
    }

    func resolvedMuscles() -> [MuscleGroup] {
        if let custom = customMuscles {
            return custom
        }
        return DayTypeMuscles.defaultMuscles(for: dayType)
    }

    var isRest: Bool {
        dayType == .rest
    }
}

struct SplitPlan: Codable {
    var trainingDays: Int
    var splitType: SplitType
    var weeklyTargets: [MuscleGroup: Double]
    var days: [SplitDayConfig]

    static func defaultPlan() -> SplitPlan {
        let trainingDays = 5
        let splitType: SplitType = .hybrid
        let template = SplitTemplates.template(for: splitType, trainingDays: trainingDays)
        let days = template.enumerated().map { index, dayType in
            SplitDayConfig(dayIndex: index, dayType: dayType)
        }
        return SplitPlan(
            trainingDays: trainingDays,
            splitType: splitType,
            weeklyTargets: SplitPlan.defaultTargets(),
            days: days
        )
    }

    static func defaultTargets() -> [MuscleGroup: Double] {
        var targets: [MuscleGroup: Double] = [:]
        for muscle in MuscleGroup.allCases {
            targets[muscle] = TrainingTargets.advancedWeeklySets
        }
        return targets
    }
}

enum SplitTemplates {
    static func template(for splitType: SplitType, trainingDays: Int) -> [DayType] {
        switch (splitType, trainingDays) {
        case (.upperLower, 4):
            return [.upper, .lower, .rest, .upper, .lower, .rest, .rest]
        case (.hybrid, 5):
            return [.push, .pull, .legs, .rest, .upper, .lower, .rest]
        case (.pushPullLegs, 6):
            return [.push, .pull, .legs, .push, .pull, .legs, .rest]
        case (.fullBody, 4):
            return [.full, .rest, .full, .rest, .full, .rest, .rest]
        case (.fullBody, 5):
            return [.full, .rest, .full, .rest, .full, .rest, .full]
        case (.fullBody, 6):
            return [.full, .rest, .full, .rest, .full, .rest, .full]
        case (.upperLower, 5):
            return [.upper, .lower, .rest, .upper, .lower, .upper, .rest]
        case (.upperLower, 6):
            return [.upper, .lower, .upper, .lower, .upper, .lower, .rest]
        case (.pushPullLegs, 4):
            return [.push, .pull, .legs, .rest, .push, .rest, .rest]
        case (.pushPullLegs, 5):
            return [.push, .pull, .legs, .rest, .push, .pull, .rest]
        case (.hybrid, 4):
            return [.upper, .lower, .rest, .push, .pull, .rest, .rest]
        case (.hybrid, 6):
            return [.push, .pull, .legs, .upper, .lower, .push, .rest]
        default:
            return [.upper, .lower, .rest, .upper, .lower, .rest, .rest]
        }
    }
}

enum DayTypeMuscles {
    static func defaultMuscles(for type: DayType) -> [MuscleGroup] {
        switch type {
        case .push:
            return [.chestUpper, .chestLower, .shoulderFront, .shoulderSide, .triceps]
        case .pull:
            return [.backWidth, .backThickness, .shoulderRear, .biceps]
        case .legs:
            return [.quads, .hamstrings, .glutes, .calves]
        case .upper:
            return [
                .chestUpper, .chestLower,
                .backWidth, .backThickness,
                .shoulderFront, .shoulderSide, .shoulderRear,
                .biceps, .triceps
            ]
        case .lower:
            return [.quads, .hamstrings, .glutes, .calves]
        case .full:
            return MuscleGroup.allCases
        case .rest:
            return []
        }
    }
}

struct VolumeEngine {
    static func perSessionTargets(plan: SplitPlan) -> [MuscleGroup: Double] {
        var perSession: [MuscleGroup: Double] = [:]
        for muscle in MuscleGroup.allCases {
            let weekly = plan.weeklyTargets[muscle] ?? TrainingTargets.advancedWeeklySets
            let sessions = max(plan.trainingDays, 1)
            perSession[muscle] = weekly / Double(sessions)
        }

        return perSession
    }

    static func targetsForDay(plan: SplitPlan, dayIndex: Int) -> [MuscleGroup: Double] {
        guard dayIndex >= 0 && dayIndex < plan.days.count else { return [:] }
        let day = plan.days[dayIndex]
        guard !day.isRest else { return [:] }

        let perSession = perSessionTargets(plan: plan)
        var targets: [MuscleGroup: Double] = [:]
        for muscle in day.resolvedMuscles() {
            targets[muscle] = perSession[muscle] ?? 0
        }
        return targets
    }
}

@MainActor
final class SplitPlanStore: ObservableObject {
    @Published var plan: SplitPlan {
        didSet { save() }
    }
    @Published var currentDayIndex: Int {
        didSet { saveCursor() }
    }

    private let storageKey = "split_plan_v1"
    private let cursorKey = "split_plan_cursor_v1"

    init() {
        let initialPlan: SplitPlan
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(SplitPlan.self, from: data) {
            initialPlan = decoded
        } else {
            initialPlan = SplitPlan.defaultPlan()
        }
        self.plan = initialPlan

        if let savedIndex = UserDefaults.standard.object(forKey: cursorKey) as? Int {
            self.currentDayIndex = savedIndex
        } else {
            self.currentDayIndex = Self.firstTrainingDayIndex(in: initialPlan)
        }
    }

    func applyTemplate(trainingDays: Int, splitType: SplitType) {
        let template = SplitTemplates.template(for: splitType, trainingDays: trainingDays)
        plan.trainingDays = trainingDays
        plan.splitType = splitType
        plan.days = template.enumerated().map { index, type in
            SplitDayConfig(dayIndex: index, dayType: type)
        }
        currentDayIndex = Self.firstTrainingDayIndex(in: plan)
    }

    func resetTargets() {
        plan.weeklyTargets = SplitPlan.defaultTargets()
    }

    func currentTrainingDayIndex() -> Int {
        if plan.days.isEmpty {
            return 0
        }
        if !plan.days[currentDayIndex].isRest {
            return currentDayIndex
        }
        let nextIndex = Self.nextTrainingDayIndex(from: currentDayIndex, in: plan)
        currentDayIndex = nextIndex
        return nextIndex
    }

    func advanceAfterWorkout() {
        currentDayIndex = Self.nextTrainingDayIndex(from: currentDayIndex, in: plan)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func saveCursor() {
        UserDefaults.standard.set(currentDayIndex, forKey: cursorKey)
    }

    private static func firstTrainingDayIndex(in plan: SplitPlan) -> Int {
        for (index, day) in plan.days.enumerated() {
            if !day.isRest {
                return index
            }
        }
        return 0
    }

    private static func nextTrainingDayIndex(from index: Int, in plan: SplitPlan) -> Int {
        guard !plan.days.isEmpty else { return 0 }
        let count = plan.days.count
        for offset in 1...count {
            let candidate = (index + offset) % count
            if !plan.days[candidate].isRest {
                return candidate
            }
        }
        return index
    }
}
