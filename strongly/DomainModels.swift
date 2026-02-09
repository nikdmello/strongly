




import Foundation



struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    var exercises: [ExerciseLog]
    var notes: String
    var duration: TimeInterval
    var caloriesBurned: Int
    
    init(id: UUID = UUID(), date: Date = Date(), exercises: [ExerciseLog] = [], notes: String = "", duration: TimeInterval = 0, caloriesBurned: Int = 0) {
        self.id = id
        self.date = date
        self.exercises = exercises
        self.notes = notes
        self.duration = duration
        self.caloriesBurned = caloriesBurned
    }
}

struct ExerciseLog: Identifiable, Codable {
    let id: UUID
    let name: String
    var sets: [ExerciseSet]
    var notes: String
    
    init(id: UUID = UUID(), name: String, sets: [ExerciseSet] = [], notes: String = "") {
        self.id = id
        self.name = name
        self.sets = sets
        self.notes = notes
    }
}

struct ExerciseSet: Identifiable, Codable {
    let id: UUID
    var weight: Double
    var reps: Int
    var completed: Bool
    
    init(id: UUID = UUID(), weight: Double = 0, reps: Int = 0, completed: Bool = true) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.completed = completed
    }
}

struct ExerciseHistory {
    let exerciseName: String
    let lastWorkout: Date
    let sets: [ExerciseSet]
    
    var suggestedWeight: Double {
        guard let lastSet = sets.first else { return 0 }
        let allCompleted = sets.allSatisfy { $0.completed && $0.reps >= lastSet.reps }
        return allCompleted ? lastSet.weight + 5 : lastSet.weight
    }
    
    var suggestedReps: Int {
        sets.first?.reps ?? 0
    }
}



struct SocialWorkout: Identifiable, Codable {
    let id: UUID
    let title: String
    let youtubeURL: String
    let creator: String
    let tags: [String]
    var upvotes: Int
    var downvotes: Int
    let submittedBy: String
    let dateAdded: Date
    
    var score: Int { upvotes - downvotes }
}

enum VoteType: String, Codable {
    case up, down, none
}





struct MomentumSession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    var endDate: Date?
    let commitmentMinutes: Int 
    var actualMinutes: Int
    var extended: Bool 
    var completed: Bool
    
    init(id: UUID = UUID(), startDate: Date = Date(), endDate: Date? = nil, commitmentMinutes: Int = 5, actualMinutes: Int = 0, extended: Bool = false, completed: Bool = false) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.commitmentMinutes = commitmentMinutes
        self.actualMinutes = actualMinutes
        self.extended = extended
        self.completed = completed
    }
    
    var duration: TimeInterval {
        guard let end = endDate else { return 0 }
        return end.timeIntervalSince(startDate)
    }
}


