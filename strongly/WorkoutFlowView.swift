




import SwiftUI

enum WorkoutConstants {
    static let restTimerDuration = 90
    static let autoSaveDelay: UInt64 = 1_000_000_000
    static let celebrationDuration = 1.5
    static let minWeight = 0.0
    static let maxWeight = 1000.0
    static let minReps = 0
    static let maxReps = 100
    
    
    static let secondsPerDay: TimeInterval = 86400
    static let fullRecoveryDays = 2.0
    static let adequateRecoveryDays = 1.0
    static let highCompletionRate = 0.8
    static let lowVolumeThreshold = 10
}

struct WorkoutFlowView: View {
    let initialSession: WorkoutSession?
    let repository: WorkoutRepository
    let preloadedExercises: [ExerciseLog]
    
    @StateObject private var sessionViewModel: WorkoutSessionViewModel
    @StateObject private var restTimer = RestTimerViewModel()
    @StateObject private var planStore = SplitPlanStore()
    @ObservedObject private var unitStore = UnitSettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showExercisePicker = false
    @State private var showCelebration = false
    @State private var celebrationMessage = ""
    @State private var showCancelAlert = false
    @State private var isCompleted = false
    
    init(initialSession: WorkoutSession?, repository: WorkoutRepository, preloadedExercises: [ExerciseLog] = []) {
        self.initialSession = initialSession
        self.repository = repository
        self.preloadedExercises = preloadedExercises
        self._sessionViewModel = StateObject(wrappedValue: WorkoutSessionViewModel(repository: repository))
    }
    
    var body: some View {
        ZStack {
            if isCompleted {
                completionView
            } else {
                workoutView
            }
        }
        .background(Color.paper)
    }
    
    private var workoutView: some View {
        VStack(spacing: 0) {
            header
            progressBar
            Divider()
            
            workoutContent(sessionViewModel.currentSession ?? WorkoutSession(exercises: []))
            
            
            Button {
                showExercisePicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Exercise")
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.m)
                .background(Color.ink)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.bottom, Spacing.s)
            .background(Color.paper)
        }
        .overlay(alignment: .bottom) {
            if showCelebration {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    Text(celebrationMessage)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.primary)
                .cornerRadius(24)
                .shadow(radius: 10)
                .padding(.bottom, 100)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showCelebration)
            }
        }
        .onAppear {
            if let initial = initialSession {
                sessionViewModel.loadSession(initial)
            } else if sessionViewModel.currentSession == nil {
                if !preloadedExercises.isEmpty {
                    sessionViewModel.startWorkoutWithPreloaded(preloadedExercises)
                } else {
                    sessionViewModel.startWorkout()
                }
            }
            restTimer.resume()
        }
        .interactiveDismissDisabled(sessionViewModel.currentSession?.exercises.isEmpty == false)
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                Task {
                    await sessionViewModel.addExercise(exercise)
                }
            }
        }
        .alert("Discard Workout?", isPresented: $showCancelAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) {
                sessionViewModel.cancelWorkout()
                dismiss()
            }
        } message: {
            Text("Your progress will be lost.")
        }
        .alert("Error", isPresented: .constant(sessionViewModel.error != nil)) {
            Button("OK") { 
                sessionViewModel.error = nil 
            }
        } message: {
            if let error = sessionViewModel.error {
                Text(error.localizedDescription)
            } else {
                Text("Something went wrong")
            }
        }
        .confirmationDialog("Replace Exercise", isPresented: .constant(false), titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var header: some View {
        HStack {
            Button {
                if let session = sessionViewModel.currentSession, !session.exercises.isEmpty {
                    showCancelAlert = true
                } else {
                    sessionViewModel.cancelWorkout()
                    dismiss()
                }
            } label: {
                Text("Cancel")
                    .font(.body)
                    .foregroundColor(.graphite)
            }
            .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            
            if restTimer.isActive {
                HStack(spacing: 4) {
                    Button {
                        let newDuration = restTimer.remainingTime - 15
                        if newDuration > 0 {
                            restTimer.startTimer(duration: newDuration)
                        } else {
                            restTimer.stopTimer()
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.body)
                            .foregroundColor(.graphite)
                    }
                    
                    Button {
                        restTimer.stopTimer()
                    } label: {
                        Text("\(restTimer.remainingTime)s")
                            .font(.body)
                            .foregroundColor(.primary)
                            .monospacedDigit()
                    }
                    
                    Button {
                        restTimer.startTimer(duration: restTimer.remainingTime + 15)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            } else if let session = sessionViewModel.currentSession {
                Text("\(completedSets(session))/\(totalSets(session))")
                    .font(.body)
                    .foregroundColor(.graphite)
            }
            
            Spacer()
            
            Button {
                Task {
                    await completeWorkoutWithSummary()
                }
            } label: {
                Text("Done")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(canComplete ? .ink : .ash)
            }
            .disabled(!canComplete || sessionViewModel.isSaving || sessionViewModel.isCompleting)
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Color.paper)
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.ghost)
                    .frame(height: 2)
                
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: geometry.size.width * progressWidth, height: 2)
                    .animation(Motion.snap, value: progressWidth)
            }
        }
        .frame(height: 2)
    }
    
    private var progressWidth: CGFloat {
        guard let session = sessionViewModel.currentSession else { return 0 }
        return progress(session)
    }
    
    private func workoutContent(_ session: WorkoutSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                ForEach(session.exercises) { exercise in
                    MinimalExerciseCard(
                        exercise: exercise,
                        onAddSet: { weight, reps in
                            sessionViewModel.addSet(to: exercise.id, weight: weight, reps: reps)
                            showSetCelebration()
                            restTimer.startTimer()
                        },
                        onToggleSet: { setId in
                            let wasCompleted = exercise.sets.first(where: { $0.id == setId })?.completed ?? false
                            sessionViewModel.toggleSetCompletion(setId: setId)
                            if !wasCompleted {
                                restTimer.startTimer()
                            }
                        },
                        onDeleteSet: { setId in
                            sessionViewModel.deleteSet(setId: setId)
                        },
                        onReplace: {
                            
                        },
                        onDeleteExercise: {
                            sessionViewModel.deleteExercise(exerciseId: exercise.id)
                        }
                    )
                }
                
                if session.exercises.isEmpty {
                    VStack(spacing: Spacing.m) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 64))
                            .foregroundColor(.ash)
                        
                        VStack(spacing: Spacing.xs) {
                            Text("Ready to start?")
                                .font(.title)
                                .foregroundColor(.ink)
                            
                            Text("Add your first exercise below")
                                .font(.body)
                                .foregroundColor(.graphite)
                        }
                        
                        
                        if let suggestion = smartSuggestion {
                            Text(suggestion)
                                .font(.detail)
                                .foregroundColor(.primary)
                                .padding(.top, Spacing.s)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
                }
            }
            .padding(.vertical, Spacing.m)
        }
        .background(Color.paper)
    }
    
    private var restTimerOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    restTimer.stopTimer()
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: Spacing.l) {
                    VStack(spacing: Spacing.s) {
                        Text("Rest Timer")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        Text("\(restTimer.remainingTime)")
                            .font(.display)
                            .foregroundColor(.text)
                    }
                    
                    HStack(spacing: Spacing.m) {
                        Button("Skip") {
                            restTimer.stopTimer()
                        }
                        .font(.body)
                        .foregroundColor(.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.surface)
                        .cornerRadius(12)
                        
                        Button("+30s") {
                            restTimer.remainingTime += 30
                        }
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.primary)
                        .cornerRadius(12)
                    }
                }
                .padding(Spacing.l)
                .background(Color.surface)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.2), radius: 24, y: 8)
                .padding(Spacing.l)
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            SwiftUI.ProgressView()
                .scaleEffect(1.5)
            Text("Loading workout...")
                .font(.body)
                .foregroundColor(.textSecondary)
            Spacer()
        }
    }
    
    private var savingState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.primary, lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
                
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Text("Saving...")
                .font(.title)
                .foregroundColor(.text)
            
            Spacer()
        }
    }
    
    
    
    private func completedSets(_ session: WorkoutSession) -> Int {
        session.exercises.reduce(0) { $0 + $1.sets.filter { $0.completed }.count }
    }
    
    private func totalSets(_ session: WorkoutSession) -> Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    private func progress(_ session: WorkoutSession) -> CGFloat {
        let total = totalSets(session)
        guard total > 0 else { return 0 }
        return CGFloat(completedSets(session)) / CGFloat(total)
    }
    
    private func showSetCelebration() {
        celebrationMessage = ["Nice!", "Strong!", "Beast!", "Crushing it!", "Let's go!"].randomElement() ?? "Nice!"
        showCelebration = true
        HapticFeedback.light.trigger()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + WorkoutConstants.celebrationDuration) {
            showCelebration = false
        }
    }
    
    private func showCompletionCelebration() {
        celebrationMessage = "Workout Complete! 🎉"
        showCelebration = true
        HapticFeedback.success.trigger()
    }
    
    private func completeWorkoutWithSummary() async {
        guard sessionViewModel.currentSession != nil else { return }
        
        restTimer.stopTimer()
        await sessionViewModel.completeWorkout()
        planStore.advanceAfterWorkout()
        
        if sessionViewModel.error == nil {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isCompleted = true
            }
            HapticFeedback.success.trigger()
        }
    }
    
    private var smartSuggestion: String? {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "💡 Morning workouts boost energy all day"
        } else if hour < 17 {
            return "💡 Afternoon is peak performance time"
        } else {
            return "💡 Evening workouts improve sleep quality"
        }
    }
    
    private var canComplete: Bool {
        guard let session = sessionViewModel.currentSession else { return false }
        return completedSets(session) > 0
    }
    
    private var completionView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Text("💪")
                .font(.system(size: 80))
            
            Text("Workout Complete")
                .font(.title)
                .foregroundColor(.ink)
                .padding(.top, Spacing.m)
            
            if let session = sessionViewModel.currentSession {
                VStack(spacing: Spacing.s) {
                    HStack(spacing: Spacing.xl) {
                        VStack(spacing: 4) {
                            Text("\(completedSets(session))")
                                .font(.title)
                                .foregroundColor(.ink)
                            Text("sets")
                                .font(.detail)
                                .foregroundColor(.graphite)
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(session.exercises.count)")
                                .font(.title)
                                .foregroundColor(.ink)
                            Text("exercises")
                                .font(.detail)
                                .foregroundColor(.graphite)
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(Int(displayVolume(totalVolume(session))))")
                                .font(.title)
                                .foregroundColor(.ink)
                            Text(unitStore.unit.symbol)
                                .font(.detail)
                                .foregroundColor(.graphite)
                        }
                    }
                    .padding(.top, Spacing.l)
                }
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)
                    .background(Color.ink)
                    .cornerRadius(12)
            }
            .padding(Spacing.m)
        }
    }
    
    private func totalVolume(_ session: WorkoutSession) -> Double {
        session.exercises.reduce(0.0) { total, exercise in
            total + exercise.sets.filter { $0.completed }.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        }
    }
    
    private func displayVolume(_ totalVolumeLb: Double) -> Double {
        WeightConverter.toDisplay(weightLb: totalVolumeLb, unit: unitStore.unit)
    }
}

struct MinimalExerciseCard: View {
    let exercise: ExerciseLog
    let onAddSet: (Double, Int) -> Void
    let onToggleSet: (UUID) -> Void
    let onDeleteSet: (UUID) -> Void
    let onReplace: () -> Void
    let onDeleteExercise: () -> Void
    
    @ObservedObject private var unitStore = UnitSettingsStore.shared
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var showDeleteConfirm = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case weight, reps
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name.uppercased())
                        .font(.label)
                        .foregroundColor(.ink)
                    
                    if !exercise.notes.isEmpty {
                        Text(exercise.notes)
                            .font(.detail)
                            .foregroundColor(.graphite)
                    }
                }
                
                Spacer()
                
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.detail)
                        .foregroundColor(.ash)
                }
            }
            .padding(.horizontal, Spacing.m)
            .confirmationDialog("Delete this exercise?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { onDeleteExercise() }
                Button("Cancel", role: .cancel) {}
            }
            
            if !exercise.sets.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        MinimalSetRow(
                            index: index + 1,
                            set: set,
                            onToggle: { onToggleSet(set.id) },
                            onDelete: { onDeleteSet(set.id) }
                        )
                    }
                }
            }
            
            HStack(spacing: Spacing.s) {
                TextField(unitStore.unit.symbol, text: $weightText)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .frame(width: 70)
                    .padding(Spacing.s)
                    .background(Color.ghost)
                    .foregroundColor(.ink)
                    .focused($focusedField, equals: .weight)
                
                Text("×")
                    .font(.body)
                    .foregroundColor(.ash)
                
                TextField("reps", text: $repsText)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
                    .frame(width: 60)
                    .padding(Spacing.s)
                    .background(Color.ghost)
                    .foregroundColor(.ink)
                    .focused($focusedField, equals: .reps)
                    .onSubmit {
                        if canAddSet { addSet() }
                    }
                
                Spacer()
                
                if focusedField != nil {
                    Button {
                        focusedField = nil
                    } label: {
                        Text("Done")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, Spacing.s)
                            .background(Color.ink)
                            .cornerRadius(8)
                    }
                } else {
                    Button {
                        addSet()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(canAddSet ? .ink : .ash)
                            .frame(width: 32, height: 32)
                            .background(canAddSet ? Color.primary : Color.ghost)
                            .clipShape(Circle())
                    }
                    .disabled(!canAddSet)
                }
            }
            .padding(.horizontal, Spacing.m)
        }
        .onAppear {
            if let lastSet = exercise.sets.last {
                weightText = WeightFormatter.format(lastSet.weight, unit: unitStore.unit)
                repsText = "\(lastSet.reps)"
            }
        }
    }
    
    private var canAddSet: Bool {
        !weightText.isEmpty && !repsText.isEmpty
    }
    
    private func addSet() {
        guard let weight = Double(weightText), let reps = Int(repsText) else {
            
            HapticFeedback.error.trigger()
            return
        }
        let weightLb = WeightConverter.toStorage(weightInput: weight, unit: unitStore.unit)
        guard weightLb > 0, weightLb <= 1000 else {
            HapticFeedback.error.trigger()
            return
        }
        guard reps > 0, reps <= 100 else {
            HapticFeedback.error.trigger()
            return
        }
        onAddSet(weightLb, reps)
        HapticFeedback.light.trigger()
        focusedField = .reps
    }
}

struct MinimalSetRow: View {
    let index: Int
    let set: ExerciseSet
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false
    @ObservedObject private var unitStore = UnitSettingsStore.shared
    
    var body: some View {
        HStack(spacing: Spacing.s) {
            Button(action: onToggle) {
                Image(systemName: set.completed ? "checkmark.square.fill" : "square")
                    .font(.title)
                    .foregroundColor(set.completed ? .primary : .ash)
            }
            
            Text("\(index)")
                .font(.body)
                .foregroundColor(.ash)
                .frame(width: 24)
            
            Text("\(WeightFormatter.format(set.weight, unit: unitStore.unit))\(unitStore.unit.symbol) × \(set.reps)")
                .font(.body)
                .foregroundColor(.ink)
            
            Spacer()
            
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.detail)
                    .foregroundColor(.ash)
            }
            .confirmationDialog("Delete this set?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { onDelete() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
    }
}

#Preview {
    WorkoutFlowView(initialSession: nil, repository: FileSystemWorkoutRepository(), preloadedExercises: [])
}
