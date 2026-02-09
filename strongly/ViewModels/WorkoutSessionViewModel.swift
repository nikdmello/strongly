





import SwiftUI
import Combine

@MainActor
final class WorkoutSessionViewModel: ObservableObject {
    @Published var currentSession: WorkoutSession?
    @Published var isActive = false
    @Published var error: Error?
    @Published var isSaving = false
    @Published var isCompleting = false
    
    private let repository: WorkoutRepository
    private var saveTask: Task<Void, Never>?
    private var startTime: Date?
    private var retryCount = 0
    
    init(repository: WorkoutRepository) {
        self.repository = repository
    }
    
    func loadSession(_ session: WorkoutSession) {
        currentSession = session
        isActive = true
        startTime = Date()
    }
    
    
    
    func startWorkout() {
        currentSession = WorkoutSession(exercises: [])
        startTime = Date()
        isActive = true
        error = nil
    }
    
    func startWorkoutWithPreloaded(_ exercises: [ExerciseLog]) {
        currentSession = WorkoutSession(exercises: exercises)
        startTime = Date()
        isActive = true
        error = nil
    }
    

    
    
    
    func addExercise(_ exercise: Exercise) async {
        guard var session = currentSession else { return }
        
        let sets = (0..<3).map { _ in
            ExerciseSet(weight: 0, reps: 10, completed: false)
        }
        
        session.exercises.append(ExerciseLog(name: exercise.name, sets: sets, notes: ""))
        currentSession = session
        autoSave()
        
        HapticFeedback.medium.trigger()
    }
    
    func addExercise(_ name: String) async {
        guard let exercise = ExerciseDatabase.shared.getExercise(named: name) else { return }
        await addExercise(exercise)
    }
    
    func deleteExercise(exerciseId: UUID) {
        guard var session = currentSession else { return }
        session.exercises.removeAll { $0.id == exerciseId }
        currentSession = session
        autoSave()
    }
    
    
    
    func addSet(to exerciseId: UUID, weight: Double, reps: Int) {
        let sanitizedWeight = (weight * 10).rounded() / 10
        
        guard sanitizedWeight > 0, sanitizedWeight <= 1000 else {
            let unit = UnitSettingsStore.shared.unit
            let maxDisplay = WeightConverter.toDisplay(weightLb: 1000, unit: unit)
            let message = "Weight must be between 0.1 and \(Int(maxDisplay))\(unit.symbol)"
            error = NSError(domain: "WorkoutSession", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            return 
        }
        guard reps > 0, reps <= 100 else { 
            error = NSError(domain: "WorkoutSession", code: 2, userInfo: [NSLocalizedDescriptionKey: "Reps must be between 1 and 100"])
            return 
        }
        
        guard var session = currentSession,
              let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        
        let set = ExerciseSet(weight: sanitizedWeight, reps: reps, completed: false)
        session.exercises[exerciseIndex].sets.append(set)
        currentSession = session
        autoSave()
        
        HapticFeedback.medium.trigger()
    }
    
    func updateSet(setId: UUID, weight: Double, reps: Int) {
        guard var session = currentSession else { return }
        
        for exerciseIndex in session.exercises.indices {
            if let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) {
                session.exercises[exerciseIndex].sets[setIndex] = ExerciseSet(
                    id: setId,
                    weight: weight,
                    reps: reps,
                    completed: true
                )
                currentSession = session
                autoSave()
                return
            }
        }
    }
    
    func toggleSetCompletion(setId: UUID) {
        guard var session = currentSession else { return }
        
        for exerciseIndex in session.exercises.indices {
            if let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) {
                let currentSet = session.exercises[exerciseIndex].sets[setIndex]
                session.exercises[exerciseIndex].sets[setIndex] = ExerciseSet(
                    id: setId,
                    weight: currentSet.weight,
                    reps: currentSet.reps,
                    completed: !currentSet.completed
                )
                currentSession = session
                autoSave()
                HapticFeedback.light.trigger()
                return
            }
        }
    }
    
    func deleteSet(setId: UUID) {
        guard var session = currentSession else { return }
        
        for exerciseIndex in session.exercises.indices {
            session.exercises[exerciseIndex].sets.removeAll { $0.id == setId }
        }
        
        currentSession = session
        autoSave()
    }
    
    
    
    func completeWorkout() async {
        guard !isCompleting else { return }
        guard var session = currentSession else { return }
        
        isCompleting = true
        defer { isCompleting = false }
        
        if let start = startTime {
            session.duration = Date().timeIntervalSince(start)
        }
        
        isSaving = true
        
        do {
            try await repository.save(session)
            await MainActor.run {
                ProgressionEngine.updateProgress(from: session)
            }
            currentSession = nil
            isActive = false
            error = nil
        } catch {
            self.error = error
            HapticFeedback.error.trigger()
        }
        
        isSaving = false
    }
    
    func cancelWorkout() {
        saveTask?.cancel()
        currentSession = nil
        isActive = false
        error = nil
        startTime = nil
    }
    
    
    
    private func autoSave() {
        guard let session = currentSession else { return }
        
        saveTask?.cancel()
        retryCount = 0
        
        saveTask = Task {
            try? await Task.sleep(nanoseconds: WorkoutConstants.autoSaveDelay)
            
            if !Task.isCancelled {
                await performSave(session)
            }
        }
    }
    
    private func performSave(_ session: WorkoutSession) async {
        do {
            try await repository.save(session)
            retryCount = 0
        } catch {
            if retryCount < 3 {
                retryCount += 1
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    await performSave(session)
                }
            } else {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    deinit {
        saveTask?.cancel()
    }
}
