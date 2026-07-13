import XCTest
@testable import strongly

@MainActor
final class SplitPlanAutopilotTests: XCTestCase {
    func testDailyRequiredRoundsUp() {
        XCTAssertEqual(
            VolumeEngine.dailyRequired(
                remainingSets: 10,
                eligibleSessionsIncludingToday: 3
            ),
            4
        )
        XCTAssertEqual(
            VolumeEngine.dailyRequired(
                remainingSets: 2.01,
                eligibleSessionsIncludingToday: 2
            ),
            2
        )
        XCTAssertEqual(
            VolumeEngine.dailyRequired(
                remainingSets: 0,
                eligibleSessionsIncludingToday: 3
            ),
            0
        )
    }

    func testCarryoverIncreasesNextEligibleQuota() async {
        let seededSession = makeCompletedSession(
            exerciseName: "Incline Bench Press",
            completedSets: 18
        )
        let store = await makeStore(sessions: [seededSession])
        configureSchedule(
            in: store,
            todayType: .push,
            tomorrowType: .push,
            chestUpperWeeklyTarget: 20
        )

        let today = Date()
        let todayRequired = store.targetsForDate(today)[.chestUpper] ?? 0
        XCTAssertEqual(todayRequired, 1)

        store.deferLeftovers([.chestUpper: 6])

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let tomorrowRequired = store.targetsForDate(tomorrow)[.chestUpper] ?? 0
        XCTAssertEqual(tomorrowRequired, 3)
    }

    func testWorkoutMeetsQuotaWithoutDrift() async {
        let store = await makeStore()
        configureSchedule(
            in: store,
            todayType: .push,
            tomorrowType: .rest,
            chestUpperWeeklyTarget: 2
        )

        let passingExercises = [
            ExerciseLog(
                name: "Incline Bench Press",
                sets: [
                    ExerciseSet(weight: 135, reps: 8, completed: false),
                    ExerciseSet(weight: 135, reps: 8, completed: false)
                ]
            )
        ]
        XCTAssertTrue(store.workoutMeetsQuota(exercises: passingExercises))

        let failingExercises = [
            ExerciseLog(
                name: "Incline Bench Press",
                sets: [
                    ExerciseSet(weight: 135, reps: 8, completed: false)
                ]
            )
        ]
        XCTAssertFalse(store.workoutMeetsQuota(exercises: failingExercises))

        await assertGeneratedWorkoutUsesHypertrophyExercisesOnly()
    }

    func testDurationAndSetBudgetAreCappedForExtremeDailyQuota() async {
        let store = await makeStore()
        configureSchedule(
            in: store,
            todayType: .push,
            tomorrowType: .rest,
            chestUpperWeeklyTarget: 300
        )

        let today = Date()
        let day = store.dayConfig(for: today)
        let targets = store.targetsForDate(today)
        let setBudget = store.requiredSetBudget(for: day, targets: targets)
        let duration = store.recommendedWorkoutDurationMinutes(for: day, targets: targets)

        XCTAssertLessThanOrEqual(setBudget, 31)
        XCTAssertLessThanOrEqual(duration, 90)
        XCTAssertEqual(duration, 90)
    }

    func testPlannedSetBudgetScalesWithDuration() async {
        let store = await makeStore()
        configureSchedule(
            in: store,
            todayType: .push,
            tomorrowType: .push,
            chestUpperWeeklyTarget: 20
        )

        let today = Date()
        let day = store.dayConfig(for: today)
        let targets = store.targetsForDate(today)
        let required = store.requiredSetBudget(for: day, targets: targets)
        let recommended = store.recommendedWorkoutDurationMinutes(for: day, targets: targets)
        let extended = store.plannedSetBudget(
            for: day,
            targets: targets,
            durationMinutes: min(90, recommended + 20)
        )
        let shortened = store.plannedSetBudget(
            for: day,
            targets: targets,
            durationMinutes: max(30, recommended - 20)
        )

        XCTAssertGreaterThanOrEqual(extended, required)
        XCTAssertGreaterThanOrEqual(shortened, required)
    }

    private func assertGeneratedWorkoutUsesHypertrophyExercisesOnly() async {
        let generator = WorkoutGenerator(repository: InMemoryWorkoutRepository(sessions: []))
        let request = WorkoutRequest(
            duration: 45,
            targetMuscles: [.backThickness, .abs],
            equipment: .both,
            allowedEquipment: [.barbell, .dumbbell, .cable, .machine, .bodyweight],
            focus: .strength,
            preferredExercises: []
        )

        let workout = await generator.generateIntelligentWorkout(request: request)

        XCTAssertFalse(workout.exercises.isEmpty)
        for exercise in workout.exercises {
            let metadata = ExerciseDatabase.shared.getExercise(named: exercise.name)
            XCTAssertEqual(metadata?.focus, .strength, "\(exercise.name) should be a hypertrophy exercise")
            XCTAssertEqual(metadata?.isProgressiveHypertrophyCandidate, true, "\(exercise.name) should be a progressible gym exercise")
        }
        XCTAssertFalse(workout.exercises.contains { $0.name == "Cat-Cow" })
        XCTAssertFalse(workout.exercises.contains { ["Push-ups", "Plank", "Crunches", "Russian Twist"].contains($0.name) })
    }

    private func makeStore(sessions: [WorkoutSession] = []) async -> SplitPlanStore {
        let suiteName = "SplitPlanAutopilotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let repository = InMemoryWorkoutRepository(sessions: sessions)
        let store = SplitPlanStore(repository: repository, userDefaults: defaults)
        await refreshWeeklyTotals()
        return store
    }

    private func configureSchedule(
        in store: SplitPlanStore,
        todayType: DayType,
        tomorrowType: DayType,
        chestUpperWeeklyTarget: Double
    ) {
        var nextPlan = store.plan
        for index in nextPlan.days.indices {
            nextPlan.days[index].dayType = .rest
            nextPlan.days[index].customMuscles = nil
        }
        for muscle in MuscleGroup.allCases {
            nextPlan.weeklyTargets[muscle] = 0
        }
        nextPlan.weeklyTargets[.chestUpper] = chestUpperWeeklyTarget

        let todayIndex = weekdayIndex(for: Date(), count: nextPlan.days.count)
        let tomorrowIndex = (todayIndex + 1) % nextPlan.days.count
        nextPlan.days[todayIndex].dayType = todayType
        nextPlan.days[tomorrowIndex].dayType = tomorrowType
        store.plan = nextPlan
    }

    private func makeCompletedSession(
        exerciseName: String,
        completedSets: Int
    ) -> WorkoutSession {
        let sets = (0..<completedSets).map { _ in
            ExerciseSet(weight: 135, reps: 8, completed: true)
        }
        return WorkoutSession(
            date: Date(),
            exercises: [ExerciseLog(name: exerciseName, sets: sets)]
        )
    }

    private func refreshWeeklyTotals() async {
        NotificationCenter.default.post(name: .workoutHistoryDidChange, object: nil)
        try? await Task.sleep(nanoseconds: 80_000_000)
    }

    private func weekdayIndex(for date: Date, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: date)
        return min((weekday + 5) % 7, count - 1)
    }
}

@MainActor
private final class InMemoryWorkoutRepository: WorkoutRepository {
    private var sessions: [WorkoutSession]

    init(sessions: [WorkoutSession]) {
        self.sessions = sessions
    }

    func save(_ session: WorkoutSession) async throws {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func fetchAll() async throws -> [WorkoutSession] {
        sessions
    }

    func delete(_ sessionId: UUID) async throws {
        sessions.removeAll { $0.id == sessionId }
    }

    func getHistory(for exerciseName: String) async -> ExerciseHistory? {
        nil
    }
}
