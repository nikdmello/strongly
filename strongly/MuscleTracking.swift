




import Foundation

enum MuscleGroup: String, CaseIterable, Codable {
    
    case chestUpper
    case chestLower
    case backWidth
    case backThickness
    case shoulderFront
    case shoulderSide
    case shoulderRear
    
    
    case quads
    case hamstrings
    case glutes
    case calves
    
    
    case biceps
    case triceps
    case abs
    
    var displayName: String {
        switch self {
        case .chestUpper: return "Chest (Upper)"
        case .chestLower: return "Chest (Lower)"
        case .backWidth: return "Back (Width)"
        case .backThickness: return "Back (Thickness)"
        case .shoulderFront: return "Shoulders (Front)"
        case .shoulderSide: return "Shoulders (Side)"
        case .shoulderRear: return "Shoulders (Rear)"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .abs: return "Abs"
        }
    }
    
    var emoji: String {
        switch self {
        case .chestUpper, .chestLower: return "🫀"
        case .backWidth, .backThickness: return "🦾"
        case .shoulderFront, .shoulderSide, .shoulderRear: return "🏋️"
        case .quads, .hamstrings, .glutes, .calves: return "🦵"
        case .biceps, .triceps: return "💪"
        case .abs: return "🔥"
        }
    }
}

enum Equipment: String, CaseIterable, Codable {
    case barbell, dumbbell, cable, machine, bodyweight, band
}

enum TrainingTargets {
    static let advancedWeeklySets: Double = 20
    static let secondaryMuscleCredit: Double = 0.5
}

struct MuscleVolume {
    let muscle: MuscleGroup
    var sets: Double
    var totalVolume: Double 
    
    func progress(targetSets: Double) -> Double {
        guard targetSets > 0 else { return 0 }
        return min((sets / targetSets) * 100, 100)
    }
}

class MuscleTracker {
    static func calculateWeeklyVolume(sessions: [WorkoutSession]) -> [MuscleGroup: MuscleVolume] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.date >= weekAgo }
        
        var volumes: [MuscleGroup: MuscleVolume] = [:]
        
        for session in recentSessions {
            for exercise in session.exercises {
                guard let metadata = matchedExercise(for: exercise.name) else { continue }
                
                let completedSets = exercise.sets.filter { $0.completed }
                let setCount = Double(completedSets.count)
                let volume = completedSets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                
                
                for muscle in metadata.primaryMuscles {
                    if volumes[muscle] == nil {
                        volumes[muscle] = MuscleVolume(muscle: muscle, sets: 0, totalVolume: 0)
                    }
                    volumes[muscle]?.sets += setCount
                    volumes[muscle]?.totalVolume += volume
                }
                
                
                for muscle in metadata.secondaryMuscles {
                    if volumes[muscle] == nil {
                        volumes[muscle] = MuscleVolume(muscle: muscle, sets: 0, totalVolume: 0)
                    }
                    volumes[muscle]?.sets += setCount * TrainingTargets.secondaryMuscleCredit
                    volumes[muscle]?.totalVolume += volume * TrainingTargets.secondaryMuscleCredit
                }
            }
        }
        
        return volumes
    }
    
    private static func matchedExercise(for name: String) -> Exercise? {
        if let exact = ExerciseDatabase.shared.getExercise(named: name) {
            return exact
        }
        
        let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return ExerciseDatabase.shared.exercises.first { exercise in
            let candidate = exercise.name.lowercased()
            return candidate.contains(normalized) || normalized.contains(candidate)
        }
    }
}
