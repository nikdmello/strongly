import Foundation

enum Difficulty: String, Codable {
    case beginner
    case intermediate
    case advanced
}

enum ExerciseFocus: String, Codable {
    case strength
    case mobility
}

struct Exercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let equipment: Equipment
    let isCompound: Bool
    let difficulty: Difficulty
    let focus: ExerciseFocus

    init(id: UUID = UUID(), name: String, primaryMuscles: [MuscleGroup], secondaryMuscles: [MuscleGroup] = [], equipment: Equipment, isCompound: Bool, difficulty: Difficulty = .intermediate, focus: ExerciseFocus = .strength) {
        self.id = id
        self.name = name
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.isCompound = isCompound
        self.difficulty = difficulty
        self.focus = focus
    }
}

final class ExerciseDatabase {
    static let shared = ExerciseDatabase()

    let exercises: [Exercise] = [

        Exercise(name: "Bench Press", primaryMuscles: [.chestLower], secondaryMuscles: [.triceps, .shoulderFront], equipment: .barbell, isCompound: true),
        Exercise(name: "Incline Bench Press", primaryMuscles: [.chestUpper], secondaryMuscles: [.shoulderFront, .triceps], equipment: .barbell, isCompound: true),
        Exercise(name: "Dumbbell Press", primaryMuscles: [.chestLower], secondaryMuscles: [.triceps, .shoulderFront], equipment: .dumbbell, isCompound: true),
        Exercise(name: "Incline Dumbbell Press", primaryMuscles: [.chestUpper], secondaryMuscles: [.shoulderFront, .triceps], equipment: .dumbbell, isCompound: true),
        Exercise(name: "Push-ups", primaryMuscles: [.chestLower], secondaryMuscles: [.triceps, .shoulderFront], equipment: .bodyweight, isCompound: true, difficulty: .beginner),
        Exercise(name: "Cable Fly", primaryMuscles: [.chestLower], equipment: .cable, isCompound: false),
        Exercise(name: "Dumbbell Fly", primaryMuscles: [.chestLower], equipment: .dumbbell, isCompound: false),

        Exercise(name: "Deadlift", primaryMuscles: [.backThickness, .hamstrings, .glutes], secondaryMuscles: [.abs], equipment: .barbell, isCompound: true, difficulty: .advanced),
        Exercise(name: "Barbell Row", primaryMuscles: [.backThickness], secondaryMuscles: [.biceps, .shoulderRear], equipment: .barbell, isCompound: true),
        Exercise(name: "Pull-ups", primaryMuscles: [.backWidth], secondaryMuscles: [.biceps], equipment: .bodyweight, isCompound: true),
        Exercise(name: "Lat Pulldown", primaryMuscles: [.backWidth], secondaryMuscles: [.biceps], equipment: .cable, isCompound: true),
        Exercise(name: "Dumbbell Row", primaryMuscles: [.backThickness], secondaryMuscles: [.biceps], equipment: .dumbbell, isCompound: true),
        Exercise(name: "Seated Cable Row", primaryMuscles: [.backThickness], secondaryMuscles: [.biceps], equipment: .cable, isCompound: true),
        Exercise(name: "T-Bar Row", primaryMuscles: [.backThickness], secondaryMuscles: [.biceps], equipment: .barbell, isCompound: true),

        Exercise(name: "Overhead Press", primaryMuscles: [.shoulderFront], secondaryMuscles: [.shoulderSide, .triceps], equipment: .barbell, isCompound: true),
        Exercise(name: "Dumbbell Shoulder Press", primaryMuscles: [.shoulderFront], secondaryMuscles: [.shoulderSide, .triceps], equipment: .dumbbell, isCompound: true),
        Exercise(name: "Lateral Raise", primaryMuscles: [.shoulderSide], equipment: .dumbbell, isCompound: false),
        Exercise(name: "Front Raise", primaryMuscles: [.shoulderFront], equipment: .dumbbell, isCompound: false),
        Exercise(name: "Face Pull", primaryMuscles: [.shoulderRear], secondaryMuscles: [.backThickness], equipment: .cable, isCompound: false),
        Exercise(name: "Arnold Press", primaryMuscles: [.shoulderFront], secondaryMuscles: [.shoulderSide, .triceps], equipment: .dumbbell, isCompound: true),

        Exercise(name: "Barbell Curl", primaryMuscles: [.biceps], equipment: .barbell, isCompound: false),
        Exercise(name: "Dumbbell Curl", primaryMuscles: [.biceps], equipment: .dumbbell, isCompound: false),
        Exercise(name: "Hammer Curl", primaryMuscles: [.biceps], equipment: .dumbbell, isCompound: false),
        Exercise(name: "Preacher Curl", primaryMuscles: [.biceps], equipment: .dumbbell, isCompound: false),
        Exercise(name: "Tricep Pushdown", primaryMuscles: [.triceps], equipment: .cable, isCompound: false),
        Exercise(name: "Skull Crusher", primaryMuscles: [.triceps], equipment: .barbell, isCompound: false),
        Exercise(name: "Overhead Tricep Extension", primaryMuscles: [.triceps], equipment: .dumbbell, isCompound: false),
        Exercise(name: "Dips", primaryMuscles: [.chestLower, .triceps], secondaryMuscles: [.shoulderFront], equipment: .bodyweight, isCompound: true),

        Exercise(name: "Squat", primaryMuscles: [.quads], secondaryMuscles: [.glutes, .abs], equipment: .barbell, isCompound: true),
        Exercise(name: "Front Squat", primaryMuscles: [.quads], secondaryMuscles: [.glutes, .abs], equipment: .barbell, isCompound: true, difficulty: .advanced),
        Exercise(name: "Leg Press", primaryMuscles: [.quads], secondaryMuscles: [.glutes], equipment: .machine, isCompound: true),
        Exercise(name: "Romanian Deadlift", primaryMuscles: [.hamstrings, .glutes], secondaryMuscles: [.backThickness], equipment: .barbell, isCompound: true),
        Exercise(name: "Leg Curl", primaryMuscles: [.hamstrings], equipment: .machine, isCompound: false),
        Exercise(name: "Leg Extension", primaryMuscles: [.quads], equipment: .machine, isCompound: false),
        Exercise(name: "Lunges", primaryMuscles: [.quads, .glutes], secondaryMuscles: [.abs], equipment: .dumbbell, isCompound: true),
        Exercise(name: "Bulgarian Split Squat", primaryMuscles: [.quads, .glutes], equipment: .dumbbell, isCompound: true),
        Exercise(name: "Calf Raise", primaryMuscles: [.calves], equipment: .machine, isCompound: false),

        Exercise(name: "Plank", primaryMuscles: [.abs], equipment: .bodyweight, isCompound: false, difficulty: .beginner),
        Exercise(name: "Crunches", primaryMuscles: [.abs], equipment: .bodyweight, isCompound: false, difficulty: .beginner),
        Exercise(name: "Cable Crunch", primaryMuscles: [.abs], equipment: .cable, isCompound: false),
        Exercise(name: "Hanging Leg Raise", primaryMuscles: [.abs], equipment: .bodyweight, isCompound: false, difficulty: .advanced),
        Exercise(name: "Russian Twist", primaryMuscles: [.abs], equipment: .bodyweight, isCompound: false),

        Exercise(name: "Scapular Push-up", primaryMuscles: [.shoulderRear, .shoulderFront], secondaryMuscles: [.chestUpper], equipment: .bodyweight, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Wall Slides", primaryMuscles: [.shoulderRear, .shoulderSide], equipment: .bodyweight, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Thoracic Rotation", primaryMuscles: [.backThickness, .abs], equipment: .bodyweight, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Cat-Cow", primaryMuscles: [.backThickness, .abs], equipment: .bodyweight, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Hip Airplane", primaryMuscles: [.glutes, .hamstrings], secondaryMuscles: [.abs], equipment: .bodyweight, isCompound: false, difficulty: .advanced, focus: .mobility),
        Exercise(name: "90/90 Hip Switch", primaryMuscles: [.glutes, .hamstrings], equipment: .bodyweight, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Deep Squat Hold", primaryMuscles: [.quads, .glutes, .calves], equipment: .bodyweight, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Ankle Dorsiflexion Drill", primaryMuscles: [.calves], equipment: .band, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Cossack Squat", primaryMuscles: [.quads, .glutes, .hamstrings], equipment: .bodyweight, isCompound: false, difficulty: .intermediate, focus: .mobility),
        Exercise(name: "Dead Bug", primaryMuscles: [.abs], secondaryMuscles: [.glutes], equipment: .bodyweight, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Bird Dog", primaryMuscles: [.abs, .glutes], secondaryMuscles: [.backThickness], equipment: .bodyweight, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Side Plank Reach", primaryMuscles: [.abs, .shoulderSide], equipment: .bodyweight, isCompound: false, difficulty: .beginner, focus: .mobility),
        Exercise(name: "Goblet Squat Hold", primaryMuscles: [.quads, .glutes, .abs], equipment: .dumbbell, isCompound: false, difficulty: .intermediate, focus: .mobility),
        Exercise(name: "Farmer Carry", primaryMuscles: [.backThickness, .abs, .glutes], equipment: .dumbbell, isCompound: true, difficulty: .intermediate, focus: .mobility),
        Exercise(name: "Single-Arm Overhead Carry", primaryMuscles: [.shoulderSide, .abs, .glutes], equipment: .dumbbell, isCompound: false, difficulty: .intermediate, focus: .mobility),
        Exercise(name: "Turkish Get-Up", primaryMuscles: [.shoulderFront, .abs, .glutes], secondaryMuscles: [.hamstrings], equipment: .dumbbell, isCompound: true, difficulty: .advanced, focus: .mobility)
    ]

    func search(_ query: String) -> [Exercise] {
        guard !query.isEmpty else { return exercises }

        let normalized = query.lowercased()
        return exercises.filter {
            $0.name.lowercased().contains(normalized)
        }
    }

    func filter(
        muscles: Set<MuscleGroup> = [],
        equipment: Equipment? = nil,
        difficulty: Difficulty? = nil,
        source: [Exercise]? = nil
    ) -> [Exercise] {
        var filtered = source ?? exercises

        if !muscles.isEmpty {
            filtered = filtered.filter { exercise in
                let targets = Set(exercise.primaryMuscles + exercise.secondaryMuscles)
                return !targets.isDisjoint(with: muscles)
            }
        }

        if let equipment = equipment {
            filtered = filtered.filter { $0.equipment == equipment }
        }

        if let difficulty = difficulty {
            filtered = filtered.filter { $0.difficulty == difficulty }
        }

        return filtered
    }

    func getExercise(named name: String) -> Exercise? {
        exercises.first { $0.name.lowercased() == name.lowercased() }
    }
}
