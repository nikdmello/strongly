import Foundation
import Combine

extension Notification.Name {
    static let autopilotTelemetry = Notification.Name("autopilotTelemetry")
}

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
    static func dailyRequired(
        remainingSets: Double,
        eligibleSessionsIncludingToday: Int
    ) -> Double {
        guard remainingSets > 0 else { return 0 }
        guard eligibleSessionsIncludingToday > 0 else { return ceil(remainingSets) }
        return ceil(remainingSets / Double(eligibleSessionsIncludingToday))
    }

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
    @Published private(set) var deferredLeftovers: [MuscleGroup: Double] {
        didSet { saveDeferredLeftovers() }
    }
    @Published private(set) var recentDeferDates: [Date] {
        didSet { saveRecentDeferDates() }
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
    private let deferredLeftoversKey = "split_plan_deferred_leftovers_v1"
    private let recentDeferDatesKey = "split_plan_recent_defer_dates_v1"
    private let weeklyVolumeResetKey = "split_plan_weekly_volume_reset_v1"
    private let preferredSessionDurationCapMinutes = 60
    private let hardSessionDurationCapMinutes = 90
    private let defaults: UserDefaults
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(
        repository: WorkoutRepository = FileSystemWorkoutRepository(),
        userDefaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.defaults = userDefaults
        let initialPlan: SplitPlan
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(SplitPlan.self, from: data) {
            initialPlan = decoded
        } else {
            initialPlan = SplitPlan.defaultPlan()
        }
        self.plan = initialPlan
        self.currentDayIndex = Self.todayDayIndex(in: initialPlan)
        if let data = defaults.data(forKey: overridesKey),
           let decoded = try? JSONDecoder().decode([String: DayOverride].self, from: data) {
            self.dayOverrides = decoded
        } else {
            self.dayOverrides = [:]
        }
        if let data = defaults.data(forKey: restShiftKey),
           let decoded = try? JSONDecoder().decode(RestShiftRecord.self, from: data) {
            self.lastRestShift = decoded
        } else {
            self.lastRestShift = nil
        }
        if let data = defaults.data(forKey: deferredLeftoversKey),
           let decoded = try? JSONDecoder().decode([MuscleGroup: Double].self, from: data) {
            self.deferredLeftovers = decoded
        } else {
            self.deferredLeftovers = [:]
        }
        if let data = defaults.data(forKey: recentDeferDatesKey),
           let decoded = try? JSONDecoder().decode([Date].self, from: data) {
            self.recentDeferDates = decoded
        } else {
            self.recentDeferDates = []
        }
        self.weeklyVolumeResetDate = defaults.object(forKey: weeklyVolumeResetKey) as? Date
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

        var rawTargets: [MuscleGroup: Double] = [:]
        let todaysMuscles = Set(day.resolvedMuscles())
        for muscle in todaysMuscles {
            let weeklyTarget = plan.weeklyTargets[muscle] ?? TrainingTargets.advancedWeeklySets
            let completed = weeklyCompletedSets[muscle] ?? 0
            let carry = deferredLeftovers[muscle] ?? 0
            let baseRemaining = max(0, weeklyTarget - completed)
            let remaining = max(baseRemaining, carry)
            let eligible = eligibleSessionsIncludingToday(
                for: muscle,
                from: date,
                windowDays: 7
            )
            rawTargets[muscle] = VolumeEngine.dailyRequired(
                remainingSets: remaining,
                eligibleSessionsIncludingToday: eligible
            )
        }

        return scaledTargetsForSession(day: day, targets: rawTargets)
    }

    func requiredTargetsForToday() -> [MuscleGroup: Double] {
        targetsForDate(Date())
    }

    func requiredSetBudget(for date: Date = Date()) -> Int {
        let day = dayConfig(for: date)
        let targets = targetsForDate(date)
        return requiredSetBudget(for: day, targets: targets)
    }

    func requiredSetBudget(
        for day: SplitDayConfig,
        targets: [MuscleGroup: Double]
    ) -> Int {
        guard !day.isRest else { return 0 }
        let rawSets = rawRequiredSetBudget(for: day, targets: targets)
        let preferredCap = setCapacity(for: day.dayType, maxMinutes: preferredSessionDurationCapMinutes)
        let hardCap = setCapacity(for: day.dayType, maxMinutes: hardSessionDurationCapMinutes)
        if rawSets <= preferredCap {
            return rawSets
        }
        return min(rawSets, hardCap)
    }

    func plannedSetBudget(
        for day: SplitDayConfig,
        targets: [MuscleGroup: Double],
        durationMinutes: Int
    ) -> Int {
        guard !day.isRest else { return 0 }

        let required = requiredSetBudget(for: day, targets: targets)
        let recommended = recommendedWorkoutDurationMinutes(for: day, targets: targets)
        let hardCap = setCapacity(for: day.dayType, maxMinutes: hardSessionDurationCapMinutes)
        guard recommended > 0 else {
            return min(required, hardCap)
        }

        let ratio = Double(durationMinutes) / Double(recommended)
        let scaled = Int(round(Double(required) * ratio))
        let boundedScaled = min(max(required, scaled), hardCap)
        return max(required, boundedScaled)
    }

    private func rawRequiredSetBudget(
        for day: SplitDayConfig,
        targets: [MuscleGroup: Double]
    ) -> Int {
        guard !day.isRest else { return 0 }
        let totalCredits = targets.values.reduce(0, +)
        let creditPerSet = max(estimatedCreditPerSet(for: day.dayType), 0.75)
        let quotaSets = Int(ceil(totalCredits / creditPerSet))
        return max(day.resolvedMuscles().count, quotaSets)
    }

    func recommendedWorkoutDurationMinutes(for date: Date = Date()) -> Int {
        let day = dayConfig(for: date)
        let targets = targetsForDate(date)
        return recommendedWorkoutDurationMinutes(for: day, targets: targets)
    }

    func recommendedWorkoutDurationMinutes(
        for day: SplitDayConfig,
        targets: [MuscleGroup: Double]
    ) -> Int {
        if day.isRest {
            return 0
        }
        let requiredSets = requiredSetBudget(for: day, targets: targets)
        let warmup = warmupMinutes(for: day.dayType)
        let minutesPerSet = estimatedMinutesPerSet(for: day.dayType)
        let raw = warmup + (Double(requiredSets) * minutesPerSet)
        let roundedUpToFive = Int(ceil(raw / 5.0) * 5.0)
        return max(30, min(hardSessionDurationCapMinutes, roundedUpToFive))
    }

    func workoutMeetsQuota(
        exercises: [ExerciseLog],
        date: Date = Date()
    ) -> Bool {
        let required = targetsForDate(date)
        let planned = MuscleTracker.setCredits(for: exercises, completedOnly: false)
        return MuscleTracker.meetsQuota(required: required, plannedCredits: planned)
    }

    func completionDeficits(for session: WorkoutSession, date: Date = Date()) -> [MuscleGroup: Double] {
        let required = targetsForDate(date)
        guard !required.isEmpty else { return [:] }
        let achieved = MuscleTracker.setCredits(for: session.exercises, completedOnly: true)
        return MuscleTracker.deficits(required: required, achieved: achieved)
    }

    func deferLeftovers(_ deficits: [MuscleGroup: Double]) {
        guard !deficits.isEmpty else { return }
        for (muscle, value) in deficits {
            deferredLeftovers[muscle, default: 0] += value
        }
        trackDeferTelemetry(deficits: deficits)
    }

    private func consumeDeferredLeftovers(with session: WorkoutSession) {
        guard !deferredLeftovers.isEmpty else { return }
        let achieved = MuscleTracker.setCredits(for: session.exercises, completedOnly: true)
        var updated = deferredLeftovers
        for (muscle, value) in updated {
            let remaining = max(0, value - (achieved[muscle] ?? 0))
            if remaining <= 0.0001 {
                updated.removeValue(forKey: muscle)
            } else {
                updated[muscle] = remaining
            }
        }
        deferredLeftovers = updated
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
        deferredLeftovers = [:]
        recentDeferDates = []
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

    func advanceAfterWorkout(session: WorkoutSession) {
        consumeDeferredLeftovers(with: session)
        currentDayIndex = Self.todayDayIndex(in: plan)
    }

    func recordGeneratedQuotaResult(
        required: [MuscleGroup: Double],
        planned: [MuscleGroup: Double],
        context: String
    ) {
        let deficits = MuscleTracker.deficits(required: required, achieved: planned)
        guard !deficits.isEmpty else { return }
        let summary = deficits
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { "\($0.key.rawValue):\(String(format: "%.1f", $0.value))" }
            .joined(separator: ",")
        postAutopilotTelemetry(
            name: "autopilot_quota_miss",
            payload: [
                "context": context,
                "deficits": summary
            ]
        )
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plan) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func saveCursor() {
        defaults.set(currentDayIndex, forKey: cursorKey)
    }

    private func saveOverrides() {
        if let data = try? JSONEncoder().encode(dayOverrides) {
            defaults.set(data, forKey: overridesKey)
        }
    }

    private func saveRestShift() {
        if let lastRestShift {
            if let data = try? JSONEncoder().encode(lastRestShift) {
                defaults.set(data, forKey: restShiftKey)
            }
        } else {
            defaults.removeObject(forKey: restShiftKey)
        }
    }

    private func saveDeferredLeftovers() {
        if deferredLeftovers.isEmpty {
            defaults.removeObject(forKey: deferredLeftoversKey)
            return
        }
        if let data = try? JSONEncoder().encode(deferredLeftovers) {
            defaults.set(data, forKey: deferredLeftoversKey)
        }
    }

    private func saveRecentDeferDates() {
        if recentDeferDates.isEmpty {
            defaults.removeObject(forKey: recentDeferDatesKey)
            return
        }
        if let data = try? JSONEncoder().encode(recentDeferDates) {
            defaults.set(data, forKey: recentDeferDatesKey)
        }
    }

    private func saveWeeklyVolumeResetDate() {
        if let weeklyVolumeResetDate {
            defaults.set(weeklyVolumeResetDate, forKey: weeklyVolumeResetKey)
        } else {
            defaults.removeObject(forKey: weeklyVolumeResetKey)
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

    private func eligibleSessionsIncludingToday(
        for muscle: MuscleGroup,
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
            if Set(day.resolvedMuscles()).contains(muscle) {
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

    private func warmupMinutes(for dayType: DayType) -> Double {
        switch dayType {
        case .legs, .lower:
            return 8
        case .rest:
            return 0
        default:
            return 6
        }
    }

    private func estimatedMinutesPerSet(for dayType: DayType) -> Double {
        switch dayType {
        case .legs, .lower:
            return 2.9
        case .full:
            return 2.8
        case .push, .pull, .upper:
            return 2.7
        case .rest:
            return 0
        }
    }

    private func estimatedCreditPerSet(for dayType: DayType) -> Double {
        switch dayType {
        case .legs, .lower:
            return 1.1
        case .full:
            return 1.4
        case .push, .pull, .upper:
            return 1.3
        case .rest:
            return 1.0
        }
    }

    private func setCapacity(for dayType: DayType, maxMinutes: Int) -> Int {
        guard maxMinutes > 0 else { return 0 }
        let warmup = warmupMinutes(for: dayType)
        let minutesPerSet = estimatedMinutesPerSet(for: dayType)
        guard minutesPerSet > 0 else { return 0 }
        let workingMinutes = max(0, Double(maxMinutes) - warmup)
        let capacity = Int(floor(workingMinutes / minutesPerSet))
        return max(1, capacity)
    }

    private func scaledTargetsForSession(
        day: SplitDayConfig,
        targets: [MuscleGroup: Double]
    ) -> [MuscleGroup: Double] {
        guard !day.isRest else { return [:] }
        guard !targets.isEmpty else { return [:] }

        let rawSetBudget = rawRequiredSetBudget(for: day, targets: targets)
        let preferredCap = setCapacity(for: day.dayType, maxMinutes: preferredSessionDurationCapMinutes)
        let hardCap = setCapacity(for: day.dayType, maxMinutes: hardSessionDurationCapMinutes)
        let boundedSetBudget: Int
        if rawSetBudget <= preferredCap {
            boundedSetBudget = rawSetBudget
        } else {
            boundedSetBudget = min(rawSetBudget, hardCap)
        }

        let creditPerSet = max(estimatedCreditPerSet(for: day.dayType), 0.75)
        let maxCredits = Double(boundedSetBudget) * creditPerSet
        let currentCredits = targets.values.reduce(0, +)
        guard currentCredits > 0, currentCredits > maxCredits else {
            return targets
        }

        let scale = maxCredits / currentCredits
        var scaled: [MuscleGroup: Double] = [:]
        for (muscle, value) in targets {
            scaled[muscle] = max(0, value * scale)
        }
        return scaled
    }

    private func trackDeferTelemetry(deficits: [MuscleGroup: Double]) {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        recentDeferDates = (recentDeferDates + [now]).filter { $0 >= cutoff }

        let deficitTotal = deficits.values.reduce(0, +)
        postAutopilotTelemetry(
            name: "autopilot_defer_leftovers",
            payload: [
                "count_7d": "\(recentDeferDates.count)",
                "deficit_total": String(format: "%.1f", deficitTotal)
            ]
        )

        if recentDeferDates.count >= 3 {
            postAutopilotTelemetry(
                name: "autopilot_repeated_defer",
                payload: [
                    "count_7d": "\(recentDeferDates.count)"
                ]
            )
        }
    }

    private func postAutopilotTelemetry(name: String, payload: [String: String]) {
        var info: [String: String] = payload
        info["name"] = name
        NotificationCenter.default.post(
            name: .autopilotTelemetry,
            object: nil,
            userInfo: info
        )
    }
}
