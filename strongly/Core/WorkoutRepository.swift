import Foundation
import Combine

@MainActor
protocol WorkoutRepository {
    func save(_ session: WorkoutSession) async throws
    func fetchAll() async throws -> [WorkoutSession]
    func delete(_ sessionId: UUID) async throws
    func getHistory(for exerciseName: String) async -> ExerciseHistory?
}

@MainActor
final class FileSystemWorkoutRepository: WorkoutRepository, ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []
    
    private nonisolated(unsafe) let persistence: PersistenceService
    private let storageKey = "workout_sessions"
    private var isLoaded = false
    
    nonisolated init(persistence: PersistenceService = FileSystemPersistence()) {
        self.persistence = persistence
    }
    
    func save(_ session: WorkoutSession) async throws {
        
        let fileManager = FileManager.default
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            if let attributes = try? fileManager.attributesOfFileSystem(forPath: documentsPath.path),
               let freeSize = attributes[.systemFreeSize] as? Int64 {
                if freeSize < 10_000_000 { 
                    throw NSError(domain: "WorkoutRepository", code: 100, 
                                userInfo: [NSLocalizedDescriptionKey: "Storage full. Free up space and try again."])
                }
            }
        }
        
        if !isLoaded {
            try await loadFromDisk()
        }
        
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        
        try await persistence.save(sessions, key: storageKey)
    }
    
    func fetchAll() async throws -> [WorkoutSession] {
        if !isLoaded {
            try await loadFromDisk()
        }
        return sessions.sorted { $0.date > $1.date }
    }
    
    func delete(_ sessionId: UUID) async throws {
        sessions.removeAll { $0.id == sessionId }
        try await persistence.save(sessions, key: storageKey)
    }
    
    func getHistory(for exerciseName: String) async -> ExerciseHistory? {
        let recentSessions = sessions
            .sorted { $0.date > $1.date }
            .prefix(10)
        
        for session in recentSessions {
            if let exercise = session.exercises.first(where: { 
                $0.name.lowercased() == exerciseName.lowercased() 
            }) {
                return ExerciseHistory(
                    exerciseName: exercise.name,
                    lastWorkout: session.date,
                    sets: exercise.sets
                )
            }
        }
        
        return nil
    }
    
    private func loadFromDisk() async throws {
        if let loaded = try await persistence.load(key: storageKey, as: [WorkoutSession].self) {
            sessions = loaded
        }
        isLoaded = true
    }
}
