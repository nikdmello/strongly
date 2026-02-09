import Foundation
import Combine

enum WeightUnit: String, CaseIterable, Codable {
    case lb
    case kg

    var symbol: String {
        switch self {
        case .lb: return "lb"
        case .kg: return "kg"
        }
    }
}

enum WeightConverter {
    static let lbToKg: Double = 0.45359237

    static func toDisplay(weightLb: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .lb: return weightLb
        case .kg: return weightLb * lbToKg
        }
    }

    static func toStorage(weightInput: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .lb: return weightInput
        case .kg: return weightInput / lbToKg
        }
    }
}

enum WeightFormatter {
    static func format(_ weightLb: Double, unit: WeightUnit) -> String {
        let display = WeightConverter.toDisplay(weightLb: weightLb, unit: unit)
        return String(format: "%.1f", display)
    }
}

@MainActor
final class UnitSettingsStore: ObservableObject {
    static let shared = UnitSettingsStore()

    @Published var unit: WeightUnit {
        didSet { save() }
    }

    private let key = "weight_unit_v1"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: key),
           let stored = WeightUnit(rawValue: raw) {
            unit = stored
        } else {
            unit = .lb
        }
    }

    private func save() {
        UserDefaults.standard.set(unit.rawValue, forKey: key)
    }
}

struct RepRange {
    let min: Int
    let max: Int
}

struct ExerciseProgress: Codable {
    var lastWeightLb: Double
    var nextWeightLb: Double
    var failStreak: Int
    var lastUpdated: Date
}

@MainActor
final class ExerciseProgressStore: ObservableObject {
    static let shared = ExerciseProgressStore()

    private var progress: [String: ExerciseProgress] = [:]
    private let key = "exercise_progress_v1"

    private init() {
        load()
    }

    func entry(for exerciseName: String) -> ExerciseProgress? {
        progress[exerciseName.lowercased()]
    }

    func set(_ entry: ExerciseProgress, for exerciseName: String) {
        progress[exerciseName.lowercased()] = entry
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: ExerciseProgress].self, from: data) else {
            progress = [:]
            return
        }
        progress = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum ProgressionEngine {
    static let incrementLb: Double = 5
    static let deloadFactor: Double = 0.9
    static let stallLimit = 3

    static func repRange(for exercise: Exercise) -> RepRange {
        if exercise.isCompound {
            return RepRange(min: 5, max: 10)
        }
        return RepRange(min: 10, max: 20)
    }

    static func suggestedWeightLb(for exerciseName: String, history: [WorkoutSession]) -> Double {
        if let entry = ExerciseProgressStore.shared.entry(for: exerciseName) {
            return entry.nextWeightLb
        }
        if let last = lastCompletedWeightLb(for: exerciseName, history: history) {
            return last
        }
        return 0
    }

    static func suggestedReps(for exercise: Exercise) -> Int {
        repRange(for: exercise).min
    }

    static func updateProgress(from session: WorkoutSession) {
        for exerciseLog in session.exercises {
            guard let exercise = ExerciseDatabase.shared.getExercise(named: exerciseLog.name) else { continue }
            let completed = exerciseLog.sets.filter { $0.completed }
            guard let firstSet = completed.first else { continue }

            let reps = completed.map { $0.reps }
            let range = repRange(for: exercise)
            let hitTop = reps.allSatisfy { $0 >= range.max }
            let belowMinCount = reps.filter { $0 < range.min }.count
            let belowMin = belowMinCount >= max(1, reps.count / 2)

            let currentWeight = firstSet.weight
            var nextWeight = currentWeight
            var failStreak = ExerciseProgressStore.shared.entry(for: exerciseLog.name)?.failStreak ?? 0

            if hitTop {
                nextWeight = roundToIncrement(currentWeight + incrementLb)
                failStreak = 0
            } else if belowMin {
                failStreak += 1
                if failStreak >= stallLimit {
                    nextWeight = roundToIncrement(currentWeight * deloadFactor)
                    failStreak = 0
                }
            } else {
                failStreak = 0
            }

            let entry = ExerciseProgress(
                lastWeightLb: currentWeight,
                nextWeightLb: max(0, nextWeight),
                failStreak: failStreak,
                lastUpdated: Date()
            )
            ExerciseProgressStore.shared.set(entry, for: exerciseLog.name)
        }
    }

    private static func lastCompletedWeightLb(for exerciseName: String, history: [WorkoutSession]) -> Double? {
        for session in history.sorted(by: { $0.date > $1.date }) {
            if let log = session.exercises.first(where: { $0.name.lowercased() == exerciseName.lowercased() }) {
                if let set = log.sets.first(where: { $0.completed }) {
                    return set.weight
                }
            }
        }
        return nil
    }

    private static func roundToIncrement(_ weight: Double) -> Double {
        guard incrementLb > 0 else { return weight }
        return (weight / incrementLb).rounded() * incrementLb
    }
}
