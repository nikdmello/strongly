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
        let trainingDays = 4
        let splitType: SplitType = .upperLower
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

struct DayOverride: Codable {
    let dayType: DayType
    let customMuscles: [MuscleGroup]?
}

struct RestShiftRecord: Codable {
    let trainDateKey: String
    let makeupRestDateKey: String
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
            return [.quads, .hamstrings, .glutes, .calves, .abs]
        case .upper:
            return [
                .chestUpper, .chestLower,
                .backWidth, .backThickness,
                .shoulderFront, .shoulderSide, .shoulderRear
            ]
        case .lower:
            return [.quads, .hamstrings, .glutes, .calves, .abs]
        case .full:
            return MuscleGroup.allCases
        case .rest:
            return []
        }
    }
}

struct VolumeEngine {
    static func perSessionTargets(plan: SplitPlan) -> [MuscleGroup: Double] {
        var totals: [MuscleGroup: Double] = [:]
        var counts: [MuscleGroup: Int] = [:]

        for day in plan.days where !day.isRest {
            let dayTargets = targetsForDay(plan: plan, day: day)
            for (muscle, target) in dayTargets {
                totals[muscle, default: 0] += target
                counts[muscle, default: 0] += 1
            }
        }

        var perSession: [MuscleGroup: Double] = [:]
        for muscle in MuscleGroup.allCases {
            let sessionCount = counts[muscle] ?? 0
            if sessionCount > 0 {
                perSession[muscle] = (totals[muscle] ?? 0) / Double(sessionCount)
            } else {
                perSession[muscle] = 0
            }
        }
        return perSession
    }

    static func targetsForDay(plan: SplitPlan, dayIndex: Int) -> [MuscleGroup: Double] {
        guard dayIndex >= 0 && dayIndex < plan.days.count else { return [:] }
        let day = plan.days[dayIndex]
        guard !day.isRest else { return [:] }

        return targetsForDay(plan: plan, day: day)
    }

    static func targetsForDay(plan: SplitPlan, day: SplitDayConfig) -> [MuscleGroup: Double] {
        guard !day.isRest else { return [:] }

        let perSessionByGroup = perSessionTargetsByGroup(plan: plan)
        let groupedMuscles = Dictionary(grouping: day.resolvedMuscles()) { $0.trainingGroup }
        var targets: [MuscleGroup: Double] = [:]
        for (group, muscles) in groupedMuscles {
            guard !muscles.isEmpty else { continue }
            let groupTarget = perSessionByGroup[group] ?? 0
            let perMuscleTarget = groupTarget / Double(muscles.count)
            for muscle in muscles {
                targets[muscle] = perMuscleTarget
            }
        }
        return targets
    }

    static func perSessionTargetsByGroup(plan: SplitPlan) -> [MuscleTrainingGroup: Double] {
        let weeklyTargets = weeklyTargetsByGroup(plan: plan)
        let weeklySessions = weeklySessionsPerGroup(plan: plan)
        var perSession: [MuscleTrainingGroup: Double] = [:]

        for group in MuscleTrainingGroup.allCases {
            let target = weeklyTargets[group] ?? TrainingTargets.advancedWeeklySets
            let sessions = weeklySessions[group] ?? 0
            perSession[group] = sessions > 0 ? target / Double(sessions) : 0
        }

        return perSession
    }

    static func weeklyTargetsByGroup(plan: SplitPlan) -> [MuscleTrainingGroup: Double] {
        var targets: [MuscleTrainingGroup: Double] = [:]

        for group in MuscleTrainingGroup.allCases {
            let values = group.muscles.compactMap { plan.weeklyTargets[$0] }
            if values.isEmpty {
                targets[group] = TrainingTargets.advancedWeeklySets
            } else {
                let sum = values.reduce(0, +)
                targets[group] = sum / Double(values.count)
            }
        }

        return targets
    }

    static func weeklySessionsPerGroup(plan: SplitPlan) -> [MuscleTrainingGroup: Int] {
        var counts: [MuscleTrainingGroup: Int] = [:]

        for day in plan.days where !day.isRest {
            let dayGroups = Set(day.resolvedMuscles().map { $0.trainingGroup })
            for group in dayGroups {
                counts[group, default: 0] += 1
            }
        }

        return counts
    }

    static func weeklySessionsPerMuscle(plan: SplitPlan) -> [MuscleGroup: Int] {
        var counts: [MuscleGroup: Int] = [:]

        for day in plan.days where !day.isRest {
            for muscle in Set(day.resolvedMuscles()) {
                counts[muscle, default: 0] += 1
            }
        }

        return counts
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
    @Published private(set) var dayOverrides: [String: DayOverride] {
        didSet { saveOverrides() }
    }
    @Published private(set) var lastRestShift: RestShiftRecord? {
        didSet { saveRestShift() }
    }
    @Published private(set) var weeklyCompletedSets: [MuscleGroup: Double]
    @Published private(set) var weeklyVolumeResetDate: Date? {
        didSet { saveWeeklyVolumeResetDate() }
    }

    private let repository: WorkoutRepository
    private var historyChangeCancellable: AnyCancellable?
    private let storageKey = "split_plan_v1"
    private let cursorKey = "split_plan_cursor_v1"
    private let overridesKey = "split_plan_overrides_v1"
    private let restShiftKey = "split_plan_rest_shift_v1"
    private let weeklyVolumeResetKey = "split_plan_weekly_volume_reset_v1"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(repository: WorkoutRepository = FileSystemWorkoutRepository()) {
        self.repository = repository
        let initialPlan: SplitPlan
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(SplitPlan.self, from: data) {
            initialPlan = decoded
        } else {
            initialPlan = SplitPlan.defaultPlan()
        }
        self.plan = initialPlan
        self.currentDayIndex = Self.todayDayIndex(in: initialPlan)
        if let data = UserDefaults.standard.data(forKey: overridesKey),
           let decoded = try? JSONDecoder().decode([String: DayOverride].self, from: data) {
            self.dayOverrides = decoded
        } else {
            self.dayOverrides = [:]
        }
        if let data = UserDefaults.standard.data(forKey: restShiftKey),
           let decoded = try? JSONDecoder().decode(RestShiftRecord.self, from: data) {
            self.lastRestShift = decoded
        } else {
            self.lastRestShift = nil
        }
        self.weeklyVolumeResetDate = UserDefaults.standard.object(forKey: weeklyVolumeResetKey) as? Date
        self.weeklyCompletedSets = [:]

        historyChangeCancellable = NotificationCenter.default.publisher(for: .workoutHistoryDidChange)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshWeeklyCompletedSets() }
            }
        Task { await refreshWeeklyCompletedSets() }
    }

    func applyTemplate(trainingDays: Int, splitType: SplitType) {
        let template = SplitTemplates.template(for: splitType, trainingDays: trainingDays)
        plan.trainingDays = trainingDays
        plan.splitType = splitType
        plan.days = template.enumerated().map { index, type in
            SplitDayConfig(dayIndex: index, dayType: type)
        }
        currentDayIndex = Self.todayDayIndex(in: plan)
        dayOverrides = [:]
        lastRestShift = nil
    }

    func updateDayFromBuilder(_ updatedDay: SplitDayConfig) {
        guard let index = plan.days.firstIndex(where: { $0.id == updatedDay.id }) else { return }
        plan.days[index] = updatedDay
        clearOverridesForCurrentWeek(dayIndex: updatedDay.dayIndex)
    }

    func resetTargets() {
        plan.weeklyTargets = SplitPlan.defaultTargets()
    }

    func currentTrainingDayIndex() -> Int {
        let todayIndex = Self.todayDayIndex(in: plan)
        if currentDayIndex != todayIndex {
            currentDayIndex = todayIndex
        }
        return todayIndex
    }

    func dayConfig(for date: Date = Date()) -> SplitDayConfig {
        let index = Self.todayDayIndex(in: plan, date: date)
        guard index >= 0 && index < plan.days.count else {
            return SplitDayConfig(dayIndex: 0, dayType: .rest)
        }
        var day = plan.days[index]
        if let override = dayOverrides[dateKey(for: date)] {
            day.dayType = override.dayType
            day.customMuscles = override.customMuscles
        }
        day.dayIndex = index
        return day
    }

    func targetsForDate(_ date: Date = Date()) -> [MuscleGroup: Double] {
        let day = dayConfig(for: date)
        guard !day.isRest else { return [:] }

        var targets: [MuscleGroup: Double] = [:]
        let weeklyTargetsByGroup = VolumeEngine.weeklyTargetsByGroup(plan: plan)
        let completedByGroup = weeklyCompletedByGroup()
        var musclesByGroup: [MuscleTrainingGroup: [MuscleGroup]] = [:]

        for muscle in day.resolvedMuscles() {
            if musclesByGroup[muscle.trainingGroup, default: []].contains(muscle) {
                continue
            }
            musclesByGroup[muscle.trainingGroup, default: []].append(muscle)
        }

        for (group, musclesForGroup) in musclesByGroup {
            guard !musclesForGroup.isEmpty else { continue }

            let weeklyTarget = weeklyTargetsByGroup[group] ?? TrainingTargets.advancedWeeklySets
            let completed = completedByGroup[group] ?? 0
            let remaining = max(0, weeklyTarget - completed)
            let sessionsInWindow = sessionsInRollingWeek(
                for: group,
                from: date,
                windowDays: 7
            )

            guard sessionsInWindow > 0 else {
                for muscle in musclesForGroup {
                    targets[muscle] = 0
                }
                continue
            }

            let effectiveSessions = max(sessionsInWindow, 2)
            let rawGroupTargetToday = remaining / Double(effectiveSessions)
            let totalGroupTargetToday = rawGroupTargetToday > 0 ? max(1, Int(rawGroupTargetToday.rounded())) : 0
            let perMuscleTargets = distribute(totalGroupTargetToday, count: musclesForGroup.count)

            for (index, muscle) in musclesForGroup.enumerated() where index < perMuscleTargets.count {
                targets[muscle] = Double(perMuscleTargets[index])
            }
        }

        return targets
    }

    private func weeklyCompletedByGroup() -> [MuscleTrainingGroup: Double] {
        var completed: [MuscleTrainingGroup: Double] = [:]
        for group in MuscleTrainingGroup.allCases {
            let total = group.muscles.reduce(0.0) { partial, muscle in
                partial + (weeklyCompletedSets[muscle] ?? 0)
            }
            completed[group] = total
        }
        return completed
    }

    private func distribute(_ total: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        guard total > 0 else { return Array(repeating: 0, count: count) }

        let base = total / count
        let remainder = total % count
        var result = Array(repeating: base, count: count)
        if remainder > 0 {
            for index in 0..<remainder {
                result[index] += 1
            }
        }
        return result
    }

    func clearWeeklyVolumeForTesting() {
        weeklyVolumeResetDate = Date()
        Task { await refreshWeeklyCompletedSets() }
    }

    func restoreWeeklyVolumeTracking() {
        weeklyVolumeResetDate = nil
        Task { await refreshWeeklyCompletedSets() }
    }

    func weeklyVolumeWindowStart(for date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let rollingStart = calendar.date(byAdding: .day, value: -6, to: startOfDay) ?? startOfDay
        guard let weeklyVolumeResetDate else { return rollingStart }
        return max(rollingStart, weeklyVolumeResetDate)
    }

    func setAgendaForToday(_ dayType: DayType) {
        let today = Date()
        let key = dateKey(for: today)
        dayOverrides[key] = DayOverride(dayType: dayType, customMuscles: nil)
        if lastRestShift != nil {
            lastRestShift = nil
        }
    }

    func resetAgendaForTodayToPlan() {
        let today = Date()
        let key = dateKey(for: today)
        dayOverrides.removeValue(forKey: key)
    }

    func hasAgendaOverrideForToday() -> Bool {
        let key = dateKey(for: Date())
        return dayOverrides[key] != nil
    }

    func canSkipRestToday() -> Bool {
        dayConfig().isRest
    }

    func canUndoRestShift() -> Bool {
        guard let lastRestShift else { return false }
        let today = dateKey(for: Date())
        return lastRestShift.trainDateKey == today || lastRestShift.makeupRestDateKey == today
    }

    @discardableResult
    func skipRestTodayAndShiftCycle() -> Bool {
        let today = Date()
        let todayDay = dayConfig(for: today)
        guard todayDay.isRest else { return false }

        guard let nextTrainingDate = nextTrainingDate(after: today) else { return false }
        let nextTrainingDay = dayConfig(for: nextTrainingDate)
        guard !nextTrainingDay.isRest else { return false }

        let todayKey = dateKey(for: today)
        let nextKey = dateKey(for: nextTrainingDate)

        dayOverrides[todayKey] = DayOverride(
            dayType: nextTrainingDay.dayType,
            customMuscles: nextTrainingDay.customMuscles
        )
        dayOverrides[nextKey] = DayOverride(dayType: .rest, customMuscles: nil)
        lastRestShift = RestShiftRecord(trainDateKey: todayKey, makeupRestDateKey: nextKey)
        return true
    }

    func undoLastRestShift() {
        guard let lastRestShift else { return }
        dayOverrides.removeValue(forKey: lastRestShift.trainDateKey)
        dayOverrides.removeValue(forKey: lastRestShift.makeupRestDateKey)
        self.lastRestShift = nil
    }

    func advanceAfterWorkout() {
        currentDayIndex = Self.todayDayIndex(in: plan)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func saveCursor() {
        UserDefaults.standard.set(currentDayIndex, forKey: cursorKey)
    }

    private func saveOverrides() {
        if let data = try? JSONEncoder().encode(dayOverrides) {
            UserDefaults.standard.set(data, forKey: overridesKey)
        }
    }

    private func saveRestShift() {
        if let lastRestShift {
            if let data = try? JSONEncoder().encode(lastRestShift) {
                UserDefaults.standard.set(data, forKey: restShiftKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: restShiftKey)
        }
    }

    private func saveWeeklyVolumeResetDate() {
        if let weeklyVolumeResetDate {
            UserDefaults.standard.set(weeklyVolumeResetDate, forKey: weeklyVolumeResetKey)
        } else {
            UserDefaults.standard.removeObject(forKey: weeklyVolumeResetKey)
        }
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

    private static func todayDayIndex(in plan: SplitPlan, date: Date = Date()) -> Int {
        guard !plan.days.isEmpty else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: date)
        let mondayBasedIndex = (weekday + 5) % 7
        if mondayBasedIndex < plan.days.count {
            return mondayBasedIndex
        }
        return max(0, min(mondayBasedIndex, plan.days.count - 1))
    }

    private func nextTrainingDate(after date: Date) -> Date? {
        let calendar = Calendar.current
        for offset in 1...7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if !dayConfig(for: candidate).isRest {
                return candidate
            }
        }
        return nil
    }

    private func dateKey(for date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func clearOverridesForCurrentWeek(dayIndex: Int) {
        let weekStart = Self.weekRange(for: Date()).start
        guard let targetDate = Calendar.current.date(byAdding: .day, value: dayIndex, to: weekStart) else { return }
        let targetKey = dateKey(for: targetDate)

        dayOverrides.removeValue(forKey: targetKey)

        if let last = lastRestShift,
           last.trainDateKey == targetKey || last.makeupRestDateKey == targetKey {
            dayOverrides.removeValue(forKey: last.trainDateKey)
            dayOverrides.removeValue(forKey: last.makeupRestDateKey)
            lastRestShift = nil
        }
    }

    private func refreshWeeklyCompletedSets() async {
        let sessions = (try? await repository.fetchAll()) ?? []
        let now = Date()
        let start = weeklyVolumeWindowStart(for: now)
        weeklyCompletedSets = Self.completedSetsByMuscle(
            sessions: sessions,
            from: start,
            through: now
        )
    }

    private func sessionsInRollingWeek(
        for group: MuscleTrainingGroup,
        from startDate: Date,
        windowDays: Int
    ) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        guard windowDays > 0 else { return 0 }

        var count = 0
        for offset in 0..<windowDays {
            guard let current = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let day = dayConfig(for: current)
            if day.isRest { continue }
            let dayGroups = Set(day.resolvedMuscles().map { $0.trainingGroup })
            if dayGroups.contains(group) {
                count += 1
            }
        }
        return count
    }

    private static func weekRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + 5) % 7
        let start = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? startOfDay
        return (start, end)
    }

    private static func completedSetsByMuscle(
        sessions: [WorkoutSession],
        from start: Date,
        through end: Date
    ) -> [MuscleGroup: Double] {
        var completed: [MuscleGroup: Double] = [:]
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end

        for session in sessions where session.date >= start && session.date <= endOfDay {
            for exercise in session.exercises {
                guard let metadata = ExerciseDatabase.shared.getExercise(named: exercise.name) else { continue }
                let setCount = Double(exercise.sets.filter { $0.completed }.count)
                guard setCount > 0 else { continue }

                for muscle in metadata.primaryMuscles {
                    completed[muscle, default: 0] += setCount
                }
                for muscle in metadata.secondaryMuscles {
                    completed[muscle, default: 0] += setCount * TrainingTargets.secondaryMuscleCredit
                }
            }
        }

        return completed
    }
}
