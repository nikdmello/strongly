import Foundation

enum EquipmentType: String, CaseIterable {
    case bodyweight = "Bodyweight"
    case gym = "Gym"
    case both = "Both"
}

struct WorkoutRequest {
    let duration: Int
    let targetMuscles: [MuscleGroup]
    let equipment: EquipmentType
    let preferredExercises: [String]
}

struct GeneratedWorkout {
    let exercises: [ExerciseLog]
    let estimatedDuration: Int
    let reasoning: String
}

struct UserTrainingProfile {
    var recentWorkouts: [WorkoutSession]
    var exerciseCompletionRates: [String: Double]
    var lastWorkedMuscles: [MuscleGroup: Date]
    var consecutiveWorkoutDays: Int
    var totalVolumeLast7Days: [MuscleGroup: Int]

    init(sessions: [WorkoutSession]) {
        self.recentWorkouts = Array(sessions.prefix(10))
        self.exerciseCompletionRates = Self.calculateCompletionRates(sessions)
        self.lastWorkedMuscles = Self.calculateLastWorked(sessions)
        self.consecutiveWorkoutDays = Self.calculateConsecutiveDays(sessions)
        self.totalVolumeLast7Days = Self.calculateWeeklyVolume(sessions)
    }

    private static func calculateCompletionRates(_ sessions: [WorkoutSession]) -> [String: Double] {
        var rates: [String: (completed: Int, total: Int)] = [:]

        for session in sessions.prefix(20) {
            for exercise in session.exercises {
                let completed = exercise.sets.filter { $0.completed }.count
                let total = exercise.sets.count
                guard total > 0 else { continue }
                let current = rates[exercise.name] ?? (0, 0)
                rates[exercise.name] = (current.completed + completed, current.total + total)
            }
        }

        return rates.compactMapValues {
            $0.total > 0 ? Double($0.completed) / Double($0.total) : nil
        }
    }

    private static func calculateLastWorked(_ sessions: [WorkoutSession]) -> [MuscleGroup: Date] {
        var lastWorked: [MuscleGroup: Date] = [:]

        for session in sessions.sorted(by: { $0.date > $1.date }) {
            for exercise in session.exercises {
                if let ex = ExerciseDatabase.shared.getExercise(named: exercise.name) {
                    for muscle in ex.primaryMuscles {
                        if lastWorked[muscle] == nil {
                            lastWorked[muscle] = session.date
                        }
                    }
                }
            }
        }

        return lastWorked
    }

    private static func calculateConsecutiveDays(_ sessions: [WorkoutSession]) -> Int {
        let sorted = sessions.sorted(by: { $0.date > $1.date })
        var count = 0
        var lastDate = Date()

        for session in sorted {
            let daysDiff = Calendar.current.dateComponents([.day], from: session.date, to: lastDate).day ?? 999
            if daysDiff <= 1 {
                count += 1
                lastDate = session.date
            } else {
                break
            }
        }

        return count
    }

    private static func calculateWeeklyVolume(_ sessions: [WorkoutSession]) -> [MuscleGroup: Int] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.date >= weekAgo }

        var volume: [MuscleGroup: Int] = [:]
        for session in recentSessions {
            for exercise in session.exercises {
                if let ex = ExerciseDatabase.shared.getExercise(named: exercise.name) {
                    let setCount = exercise.sets.filter { $0.completed }.count
                    for muscle in ex.primaryMuscles {
                        volume[muscle, default: 0] += setCount
                    }
                }
            }
        }
        return volume
    }
}

struct ExerciseScore {
    let exercise: Exercise
    let score: Double
    let reasons: [String]
}

@MainActor
class WorkoutGenerator {
    static let shared = WorkoutGenerator()
    private let repository: WorkoutRepository

    init(repository: WorkoutRepository = FileSystemWorkoutRepository()) {
        self.repository = repository
    }

    func generateIntelligentWorkout(request: WorkoutRequest) async -> GeneratedWorkout {
        let history = (try? await repository.fetchAll()) ?? []
        let profile = UserTrainingProfile(sessions: history)

        let strategy = determineStrategy(profile: profile, request: request)

        let scoredExercises = scoreAllExercises(
            profile: profile,
            request: request,
            strategy: strategy
        )

        if scoredExercises.isEmpty {
            return GeneratedWorkout(
                exercises: [],
                estimatedDuration: 0,
                reasoning: "No exercises available for selected equipment. Try 'Both' or add more exercises to database."
            )
        }

        let selectedExercises = selectOptimalExercises(
            scored: scoredExercises,
            request: request,
            strategy: strategy
        )

        if selectedExercises.isEmpty {
            return GeneratedWorkout(
                exercises: [],
                estimatedDuration: 0,
                reasoning: "Unable to generate workout. Try selecting different muscle groups or reducing duration."
            )
        }

        let exerciseLogs = await buildExerciseLogs(
            exercises: selectedExercises,
            profile: profile,
            strategy: strategy,
            history: history
        )

        let reasoning = buildIntelligentReasoning(
            profile: profile,
            strategy: strategy,
            selected: selectedExercises,
            request: request
        )

        let setsPerExercise = 3
        let timePerSet = 3

        return GeneratedWorkout(
            exercises: exerciseLogs,
            estimatedDuration: exerciseLogs.count * setsPerExercise * timePerSet,
            reasoning: reasoning
        )
    }

    private func determineStrategy(profile: UserTrainingProfile, request: WorkoutRequest) -> WorkoutStrategy {

        if profile.consecutiveWorkoutDays >= 5 {
            return .deload
        }

        let volumes = profile.totalVolumeLast7Days
        let maxVolume = volumes.values.max() ?? 0
        let minVolume = volumes.values.min() ?? 0

        if maxVolume > 0 && Double(minVolume) / Double(maxVolume) < 0.5 {
            return .balancing
        }

        return .progressive
    }

    private func scoreAllExercises(
        profile: UserTrainingProfile,
        request: WorkoutRequest,
        strategy: WorkoutStrategy
    ) -> [ExerciseScore] {
        var scored: [ExerciseScore] = []

        for exercise in ExerciseDatabase.shared.exercises {

            if request.equipment == .bodyweight && exercise.equipment != .bodyweight {
                continue
            }
            if request.equipment == .gym && exercise.equipment == .bodyweight {
                continue
            }

            let score = scoreExercise(exercise, profile: profile, request: request, strategy: strategy)
            scored.append(score)
        }

        return scored.sorted { $0.score > $1.score }
    }

    private func scoreExercise(
        _ exercise: Exercise,
        profile: UserTrainingProfile,
        request: WorkoutRequest,
        strategy: WorkoutStrategy
    ) -> ExerciseScore {
        var score = 0.0
        var reasons: [String] = []

        let (targetScore, targetReason) = scoreTargetMuscles(exercise, request: request)
        score += targetScore
        if let reason = targetReason { reasons.append(reason) }

        let (recoveryScore, recoveryReason) = scoreRecovery(exercise, profile: profile)
        score += recoveryScore
        if let reason = recoveryReason { reasons.append(reason) }

        if let completionRate = profile.exerciseCompletionRates[exercise.name] {
            score += completionRate * 15
            if completionRate > WorkoutConstants.highCompletionRate {
                reasons.append("High success rate")
            }
        }

        if exercise.primaryMuscles.count > 1 {
            score += 15
            reasons.append("Compound movement")
        }

        if request.preferredExercises.contains(exercise.name) {
            score += 10
            reasons.append("You do this often")
        }

        score += scoreStrategy(exercise, profile: profile, strategy: strategy, reasons: &reasons)

        return ExerciseScore(exercise: exercise, score: score, reasons: reasons)
    }

    private func scoreTargetMuscles(_ exercise: Exercise, request: WorkoutRequest) -> (Double, String?) {
        let overlap = exercise.primaryMuscles.filter { request.targetMuscles.contains($0) }.count
        guard overlap > 0 else { return (0, nil) }

        let score = Double(overlap) * 20
        let muscles = exercise.primaryMuscles.map { $0.displayName }.joined(separator: ", ")
        return (score, "Targets \(muscles)")
    }

    private func scoreRecovery(_ exercise: Exercise, profile: UserTrainingProfile) -> (Double, String?) {
        var minDaysSinceWorked = 999.0
        var criticalMuscle: MuscleGroup?

        for muscle in exercise.primaryMuscles {
            if let lastDate = profile.lastWorkedMuscles[muscle] {
                let days = Date().timeIntervalSince(lastDate) / WorkoutConstants.secondsPerDay
                if days < minDaysSinceWorked {
                    minDaysSinceWorked = days
                    criticalMuscle = muscle
                }
            }
        }

        let recoveryWindow: Double
        if let muscle = criticalMuscle {
            switch muscle {
            case .chestUpper, .chestLower, .backWidth, .backThickness, .quads, .hamstrings, .glutes, .calves:
                recoveryWindow = 3.0
            case .shoulderFront, .shoulderSide, .shoulderRear:
                recoveryWindow = 2.5
            case .biceps, .triceps:
                recoveryWindow = 2.0
            case .abs:
                recoveryWindow = 1.5
            }
        } else {
            recoveryWindow = 3.0
        }

        if minDaysSinceWorked >= recoveryWindow {
            return (30, "Fully recovered (\(Int(minDaysSinceWorked))d rest)")
        } else if minDaysSinceWorked >= recoveryWindow * 0.7 {
            return (15, "Adequate recovery")
        } else {
            return (-10, "Recently trained")
        }
    }

    private func scoreStrategy(
        _ exercise: Exercise,
        profile: UserTrainingProfile,
        strategy: WorkoutStrategy,
        reasons: inout [String]
    ) -> Double {
        switch strategy {
        case .deload:
            if exercise.primaryMuscles.count > 1 {
                reasons.append("Efficient for deload")
                return 10
            }
        case .balancing:
            let volume = profile.totalVolumeLast7Days[exercise.primaryMuscles.first ?? .chestUpper] ?? 0
            if volume < WorkoutConstants.lowVolumeThreshold {
                reasons.append("Balancing weekly volume")
                return 20
            }
        case .progressive:
            break
        }
        return 0
    }

    private func selectOptimalExercises(
        scored: [ExerciseScore],
        request: WorkoutRequest,
        strategy: WorkoutStrategy
    ) -> [ExerciseScore] {
        let setsPerExercise = 3
        let timePerSet = 3
        let maxExercises = request.duration / (setsPerExercise * timePerSet)

        var selected: [ExerciseScore] = []
        var coveredMuscles: Set<MuscleGroup> = []

        for scored in scored {
            if selected.count >= maxExercises { break }

            let newMuscles = Set(scored.exercise.primaryMuscles).subtracting(coveredMuscles)
            if !newMuscles.isEmpty && request.targetMuscles.contains(where: newMuscles.contains) {
                selected.append(scored)
                coveredMuscles.formUnion(scored.exercise.primaryMuscles)
            }
        }

        for scored in scored {
            if selected.count >= maxExercises { break }
            if !selected.contains(where: { $0.exercise.id == scored.exercise.id }) {
                selected.append(scored)
            }
        }

        return selected
    }

    private func buildExerciseLogs(
        exercises: [ExerciseScore],
        profile: UserTrainingProfile,
        strategy: WorkoutStrategy,
        history: [WorkoutSession]
    ) async -> [ExerciseLog] {
        var logs: [ExerciseLog] = []

        for scored in exercises {
            let suggestedWeight = ProgressionEngine.suggestedWeightLb(for: scored.exercise.name, history: history)
            let suggestedReps = ProgressionEngine.suggestedReps(for: scored.exercise)
            let setsCount = strategy == .deload ? 2 : 3
            let sets = (0..<setsCount).map { _ in
                ExerciseSet(
                    weight: suggestedWeight,
                    reps: suggestedReps,
                    completed: false
                )
            }

            let notes = scored.reasons.prefix(2).joined(separator: " • ")
            logs.append(ExerciseLog(name: scored.exercise.name, sets: sets, notes: notes))
        }

        return logs
    }

    private func buildIntelligentReasoning(
        profile: UserTrainingProfile,
        strategy: WorkoutStrategy,
        selected: [ExerciseScore],
        request: WorkoutRequest
    ) -> String {
        var parts: [String] = []

        switch strategy {
        case .deload:
            parts.append("🔄 Deload week - reduced volume for recovery")
        case .balancing:
            parts.append("⚖️ Balancing muscle groups")
        case .progressive:
            parts.append("📈 Progressive overload focus")
        }

        let targetMuscles = Set(selected.flatMap { $0.exercise.primaryMuscles })
        let muscleNames = targetMuscles.map { $0.displayName }.sorted().joined(separator: ", ")
        parts.append("Targeting: \(muscleNames)")

        let compounds = selected.filter { $0.exercise.primaryMuscles.count > 1 }.count
        let preferred = selected.filter { request.preferredExercises.contains($0.exercise.name) }.count
        if preferred > 0 {
            parts.append("\(preferred) familiar exercises")
        }
        parts.append("\(compounds) compound movements")

        if profile.consecutiveWorkoutDays >= 3 {
            parts.append("💤 \(profile.consecutiveWorkoutDays) consecutive days")
        }

        return parts.joined(separator: " • ")
    }
}

enum WorkoutStrategy {
    case progressive
    case deload
    case balancing
}
