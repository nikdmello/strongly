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

struct ExerciseTargetContribution: Hashable {
    let muscle: MuscleGroup
    let completedCredit: Double
    let plannedCredit: Double
}

struct WorkoutFlowView: View {
    let initialSession: WorkoutSession?
    let repository: WorkoutRepository
    let preloadedExercises: [ExerciseLog]
    let targetOverrides: [MuscleGroup: Double]

    @StateObject private var sessionViewModel: WorkoutSessionViewModel
    @StateObject private var restTimer = RestTimerViewModel()
    @EnvironmentObject private var planStore: SplitPlanStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var unitStore = UnitSettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showExercisePicker = false
    @State private var showCelebration = false
    @State private var celebrationMessage = ""
    @State private var showCancelAlert = false
    @State private var isCompleted = false

    init(
        initialSession: WorkoutSession?,
        repository: WorkoutRepository,
        preloadedExercises: [ExerciseLog] = [],
        targetOverrides: [MuscleGroup: Double] = [:]
    ) {
        self.initialSession = initialSession
        self.repository = repository
        self.preloadedExercises = preloadedExercises
        self.targetOverrides = targetOverrides
        self._sessionViewModel = StateObject(wrappedValue: WorkoutSessionViewModel(repository: repository))
    }

    var body: some View {
        ZStack {
            StarfieldBackground()
            if isCompleted {
                completionView
            } else {
                workoutView
            }
        }
        .preferredColorScheme(.dark)
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
                .foregroundColor(.spaceNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.m)
                .background(Color.spaceGlow)
                .cornerRadius(14)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.bottom, Spacing.s)
            .background(Color.clear)
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
                .background(Color.spaceGlow)
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                restTimer.resume()
            }
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
                        restTimer.adjustActiveTimer(by: -15)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.body)
                            .foregroundColor(.spaceGlow)
                    }

                    Button {
                        restTimer.stopTimer()
                    } label: {
                        Text("\(restTimer.remainingTime)s")
                            .font(.body)
                            .foregroundColor(.spaceGlow)
                            .monospacedDigit()
                    }

                    Button {
                        restTimer.adjustActiveTimer(by: 15)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                            .foregroundColor(.spaceGlow)
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
        .background(Color.clear)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 2)

                Rectangle()
                    .fill(Color.spaceGlow)
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
        let todayTargets = todayTargetSets
        let focusTargetMuscles = Set(todayTargets.keys)
        let focusProgress = focusProgress(for: session, targetMuscles: focusTargetMuscles)
        let effectiveTargets = focusProgress.planned.filter { $0.value > 0 }
        let orderedFocusMuscles = effectiveTargets.keys.sorted { $0.displayName < $1.displayName }
        let completedWorkSets = completedSets(session)
        let totalWorkSets = totalSets(session)

        return List {
            if !orderedFocusMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Text("Today’s Focus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Text("\(completedWorkSets) / \(totalWorkSets) work sets complete")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                    }

                    GeometryReader { geo in
                        let completion = totalWorkSets > 0
                            ? min(Double(completedWorkSets) / Double(totalWorkSets), 1.0)
                            : 0
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 8)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.spaceGlow)
                                    .frame(width: max(8, geo.size.width * completion), height: 8)
                            }
                    }
                    .frame(height: 8)

                    VStack(spacing: 10) {
                        ForEach(orderedFocusMuscles, id: \.self) { muscle in
                            let target = effectiveTargets[muscle] ?? 0
                            let completed = focusProgress.completed[muscle] ?? 0
                            let planned = focusProgress.planned[muscle] ?? 0
                            TodayFocusProgressRow(
                                muscle: muscle,
                                target: target,
                                completed: completed,
                                planned: planned
                            )
                        }
                    }
                }
                .padding(Spacing.m)
                .themedCard(cornerRadius: 18)
                .listRowInsets(EdgeInsets(top: Spacing.m, leading: Spacing.m, bottom: Spacing.s, trailing: Spacing.m))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if session.exercises.isEmpty {
                VStack(spacing: Spacing.m) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.55))

                    VStack(spacing: Spacing.xs) {
                        Text("Ready to start?")
                            .font(.title)
                            .foregroundColor(.white)

                        Text("Add your first exercise below")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                    }

                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
                .themedCard(cornerRadius: 18)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.m, bottom: Spacing.m, trailing: Spacing.m))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(session.exercises) { exercise in
                    MinimalExerciseCard(
                        exercise: exercise,
                        targetContributions: targetContributions(
                            for: exercise,
                            targets: effectiveTargets.isEmpty ? todayTargets : effectiveTargets
                        ),
                        showDeleteButton: false,
                        onAddSet: { weight, reps in
                            sessionViewModel.addSet(to: exercise.id, weight: weight, reps: reps)
                            showSetCelebration()
                            restTimer.startTimer(nextStep: nil)
                        },
                        onToggleSet: { setId in
                            let wasCompleted = exercise.sets.first(where: { $0.id == setId })?.completed ?? false
                            let nextStep = !wasCompleted ? nextStepAfterCompletingSet(setId: setId, session: session) : nil
                            sessionViewModel.toggleSetCompletion(setId: setId)
                            if !wasCompleted {
                                restTimer.startTimer(nextStep: nextStep)
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
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.m, bottom: Spacing.xs, trailing: Spacing.m))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            HapticFeedback.warning.trigger()
                            sessionViewModel.deleteExercise(exerciseId: exercise.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(Color.clear)
    }

    private var todayTargetSets: [MuscleGroup: Double] {
        if !targetOverrides.isEmpty {
            return targetOverrides
        }
        return planStore.targetsForDate()
    }

    private func focusProgress(
        for session: WorkoutSession,
        targetMuscles: Set<MuscleGroup>
    ) -> (completed: [MuscleGroup: Double], planned: [MuscleGroup: Double]) {
        var completed: [MuscleGroup: Double] = [:]
        var planned: [MuscleGroup: Double] = [:]

        for exercise in session.exercises {
            guard let metadata = ExerciseDatabase.shared.getExercise(named: exercise.name) else { continue }
            let completedSetCount = Double(exercise.sets.filter { $0.completed }.count)
            let plannedSetCount = Double(exercise.sets.count)

            var weightedMuscles: [(muscle: MuscleGroup, weight: Double)] = []
            for muscle in metadata.primaryMuscles where targetMuscles.contains(muscle) {
                weightedMuscles.append((muscle: muscle, weight: 1.0))
            }
            for muscle in metadata.secondaryMuscles where targetMuscles.contains(muscle) {
                weightedMuscles.append((muscle: muscle, weight: TrainingTargets.secondaryMuscleCredit))
            }

            let totalWeight = weightedMuscles.reduce(0.0) { $0 + $1.weight }
            guard totalWeight > 0 else { continue }

            for weighted in weightedMuscles {
                let normalizedWeight = weighted.weight / totalWeight
                completed[weighted.muscle, default: 0] += completedSetCount * normalizedWeight
                planned[weighted.muscle, default: 0] += plannedSetCount * normalizedWeight
            }
        }

        return (completed, planned)
    }

    private func targetContributions(
        for exercise: ExerciseLog,
        targets: [MuscleGroup: Double]
    ) -> [ExerciseTargetContribution] {
        guard !targets.isEmpty else { return [] }
        guard let metadata = ExerciseDatabase.shared.getExercise(named: exercise.name) else { return [] }

        var completed: [MuscleGroup: Double] = [:]
        var planned: [MuscleGroup: Double] = [:]
        let completedSetCount = Double(exercise.sets.filter { $0.completed }.count)
        let plannedSetCount = Double(exercise.sets.count)
        let targetMuscles = Set(targets.keys)

        for muscle in metadata.primaryMuscles where targetMuscles.contains(muscle) {
            completed[muscle, default: 0] += completedSetCount
            planned[muscle, default: 0] += plannedSetCount
        }
        for muscle in metadata.secondaryMuscles where targetMuscles.contains(muscle) {
            completed[muscle, default: 0] += completedSetCount * TrainingTargets.secondaryMuscleCredit
            planned[muscle, default: 0] += plannedSetCount * TrainingTargets.secondaryMuscleCredit
        }

        return planned.keys
            .sorted { $0.displayName < $1.displayName }
            .map { muscle in
                ExerciseTargetContribution(
                    muscle: muscle,
                    completedCredit: completed[muscle] ?? 0,
                    plannedCredit: planned[muscle] ?? 0
                )
            }
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

    private var canComplete: Bool {
        guard let session = sessionViewModel.currentSession else { return false }
        return completedSets(session) > 0
    }

    private func formatSets(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func nextStepAfterCompletingSet(setId: UUID, session: WorkoutSession) -> RestTimerNextStep? {
        guard let activeExerciseIndex = session.exercises.firstIndex(where: { exercise in
            exercise.sets.contains(where: { $0.id == setId })
        }) else {
            return nil
        }

        let activeExercise = session.exercises[activeExerciseIndex]
        guard let toggledSetIndex = activeExercise.sets.firstIndex(where: { $0.id == setId }) else {
            return nil
        }

        let completedSetCount = activeExercise.sets.enumerated().reduce(0) { partial, pair in
            let (index, set) = pair
            if index == toggledSetIndex {
                return partial + 1
            }
            return partial + (set.completed ? 1 : 0)
        }
        let totalSets = max(activeExercise.sets.count, 1)
        if completedSetCount < totalSets {
            return RestTimerNextStep(
                exerciseName: activeExercise.name,
                setNumber: completedSetCount + 1,
                totalSets: totalSets,
                isSameExercise: true
            )
        }

        let nextExerciseStart = activeExerciseIndex + 1
        if nextExerciseStart < session.exercises.count {
            for exercise in session.exercises[nextExerciseStart...] {
                if let firstIncompleteSet = exercise.sets.firstIndex(where: { !$0.completed }) {
                    return RestTimerNextStep(
                        exerciseName: exercise.name,
                        setNumber: firstIncompleteSet + 1,
                        totalSets: max(exercise.sets.count, 1),
                        isSameExercise: false
                    )
                }
            }
        }

        for exercise in session.exercises {
            if exercise.id == activeExercise.id { continue }
            if let firstIncompleteSet = exercise.sets.firstIndex(where: { !$0.completed }) {
                return RestTimerNextStep(
                    exerciseName: exercise.name,
                    setNumber: firstIncompleteSet + 1,
                    totalSets: max(exercise.sets.count, 1),
                    isSameExercise: false
                )
            }
        }

        return nil
    }

    private var completionView: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("💪")
                .font(.system(size: 80))

            Text("Workout Complete")
                .font(.title)
                .foregroundColor(.white)
                .padding(.top, Spacing.m)

            if let session = sessionViewModel.currentSession {
                VStack(spacing: Spacing.s) {
                    HStack(spacing: Spacing.xl) {
                        VStack(spacing: 4) {
                            Text("\(completedSets(session))")
                                .font(.title)
                                .foregroundColor(.white)
                            Text("sets")
                                .font(.detail)
                                .foregroundColor(.graphite)
                        }

                        VStack(spacing: 4) {
                            Text("\(session.exercises.count)")
                                .font(.title)
                                .foregroundColor(.white)
                            Text("exercises")
                                .font(.detail)
                                .foregroundColor(.graphite)
                        }

                        VStack(spacing: 4) {
                            Text("\(Int(displayVolume(totalVolume(session))))")
                                .font(.title)
                                .foregroundColor(.white)
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
                    .foregroundColor(.spaceNavy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)
                    .background(Color.spaceGlow)
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

struct TodayFocusProgressRow: View {
    let muscle: MuscleGroup
    let target: Double
    let completed: Double
    let planned: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                MuscleBadge(muscle: muscle, compact: true)

                Spacer()

                Text("\(formatSets(displayCompleted)) / \(formatSets(target))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }

            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(
                                    width: max(4, CGFloat(plannedRatio) * geo.size.width),
                                    height: 6
                                )
                        }
                    }
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(muscle.tint)
                                .frame(
                                    width: max(4, CGFloat(completedRatio) * geo.size.width),
                                    height: 6
                                )
                        }
                    }

                Text("scheduled \(formatSets(scheduled))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(scheduled >= target ? .spaceGlow : .white.opacity(0.6))
            }
        }
    }

    private var displayCompleted: Double {
        min(completed, target)
    }

    private var scheduled: Double {
        min(planned, target)
    }

    private var completedRatio: Double {
        guard target > 0 else { return 0 }
        return min(max(displayCompleted / target, 0), 1)
    }

    private var plannedRatio: Double {
        guard target > 0 else { return 0 }
        return min(max(scheduled / target, 0), 1)
    }

    private func formatSets(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

struct MinimalExerciseCard: View {
    let exercise: ExerciseLog
    let targetContributions: [ExerciseTargetContribution]
    var showDeleteButton: Bool = true
    let onAddSet: (Double, Int) -> Void
    let onToggleSet: (UUID) -> Void
    let onDeleteSet: (UUID) -> Void
    let onReplace: () -> Void
    let onDeleteExercise: () -> Void

    @ObservedObject private var unitStore = UnitSettingsStore.shared
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var showDemo = false
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
                        .foregroundColor(.white)

                    if !exercise.notes.isEmpty {
                        Text(exercise.notes)
                            .font(.detail)
                            .foregroundColor(.white.opacity(0.68))
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    ExerciseCompletionBadge(
                        completed: completedSetCount,
                        total: exercise.sets.count
                    )

                    if exerciseMetadata != nil {
                        Button {
                            showDemo = true
                        } label: {
                            Image(systemName: "play.rectangle.fill")
                                .font(.detail)
                                .foregroundColor(.spaceGlow)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    if showDeleteButton {
                        Button {
                            HapticFeedback.warning.trigger()
                            onDeleteExercise()
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.red.opacity(0.9))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .sheet(isPresented: $showDemo) {
                if let exerciseMetadata {
                    ExerciseDemoSheet(exercise: exerciseMetadata)
                }
            }

            if !targetContributions.isEmpty {
                VStack(spacing: 6) {
                    ForEach(visibleContributions, id: \.muscle) { contribution in
                        ExerciseContributionRow(
                            muscle: contribution.muscle,
                            completed: contribution.completedCredit,
                            planned: contribution.plannedCredit,
                            valueText: "\(formatSets(contribution.completedCredit))/\(formatSets(contribution.plannedCredit))"
                        )
                    }
                    if targetContributions.count > 3 {
                        Text("+\(targetContributions.count - 3) more")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.horizontal, Spacing.m)
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
                    .submitLabel(.next)
                    .frame(width: 70)
                    .padding(Spacing.s)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .weight)
                    .onSubmit {
                        focusedField = .reps
                    }

                Text("×")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.55))

                TextField("reps", text: $repsText)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .frame(width: 60)
                    .padding(Spacing.s)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .reps)
                    .onSubmit {
                        if canAddSet { addSet() }
                    }

                Spacer()

                Button {
                    addSet()
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(canAddSet ? .spaceNavy : .white.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .background(canAddSet ? Color.spaceGlow : Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .disabled(!canAddSet)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.m)
        }
        .padding(.vertical, Spacing.s)
        .themedCard(cornerRadius: 18)
        .onAppear {
            if let lastSet = exercise.sets.last {
                weightText = WeightFormatter.format(lastSet.weight, unit: unitStore.unit)
                repsText = "\(lastSet.reps)"
            } else {
                if weightText.isEmpty {
                    weightText = "0"
                }
                if repsText.isEmpty {
                    repsText = "\(defaultReps)"
                }
            }
        }
    }

    private var canAddSet: Bool {
        guard let weight = Double(weightText), let reps = Int(repsText) else {
            return false
        }
        let weightLb = WeightConverter.toStorage(weightInput: weight, unit: unitStore.unit)
        return weightLb >= 0 && weightLb <= 1000 && reps > 0 && reps <= 100
    }

    private var exerciseMetadata: Exercise? {
        ExerciseDatabase.shared.getExercise(named: exercise.name)
    }

    private var visibleContributions: [ExerciseTargetContribution] {
        Array(targetContributions.prefix(3))
    }

    private var completedSetCount: Int {
        exercise.sets.filter { $0.completed }.count
    }

    private var defaultReps: Int {
        guard let exercise = exerciseMetadata else { return 10 }
        if exercise.focus == .mobility {
            return 12
        }
        if exercise.isCompound {
            return exercise.equipment == .bodyweight ? 12 : 8
        }
        if exercise.primaryMuscles.contains(.abs) {
            return 15
        }
        return 12
    }

    private func addSet() {
        guard let weight = Double(weightText), let reps = Int(repsText) else {

            HapticFeedback.error.trigger()
            return
        }
        let weightLb = WeightConverter.toStorage(weightInput: weight, unit: unitStore.unit)
        guard weightLb >= 0, weightLb <= 1000 else {
            HapticFeedback.error.trigger()
            return
        }
        guard reps > 0, reps <= 100 else {
            HapticFeedback.error.trigger()
            return
        }
        onAddSet(weightLb, reps)
        HapticFeedback.light.trigger()
        focusedField = nil
    }

    private func formatSets(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

struct ExerciseDemoSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @State private var animate = false

    var body: some View {
        NavigationView {
            ZStack {
                StarfieldBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.spaceGlow.opacity(0.12))
                                .frame(width: 130, height: 130)
                            Image(systemName: demoSymbol)
                                .font(.system(size: 56, weight: .semibold))
                                .foregroundColor(.spaceGlow)
                                .scaleEffect(animate ? 1.08 : 0.92)
                                .animation(
                                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                    value: animate
                                )
                        }
                        .padding(.top, 16)

                        Text(exercise.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            Text(exercise.focus.rawValue.capitalized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.spaceNavy)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.spaceGlow)
                                .clipShape(Capsule())

                            Text(exercise.equipment.rawValue.capitalized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                                    MuscleBadge(muscle: muscle, compact: true)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Form Cues")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)

                            ForEach(formCues, id: \.self) { cue in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.spaceGlow)
                                    Text(cue)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .themedCard(cornerRadius: 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Visual Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            animate = true
        }
    }

    private var demoSymbol: String {
        exercise.primaryMuscles.first?.symbolName ?? "figure.strengthtraining.traditional"
    }

    private var formCues: [String] {
        if exercise.focus == .mobility {
            return [
                "Move slowly through full range",
                "Pause for control at end range",
                "Keep breathing steady"
            ]
        }
        if exercise.isCompound {
            return [
                "Brace core before each rep",
                "Control the lowering phase",
                "Drive with full-body tension"
            ]
        }
        return [
            "Control start and finish positions",
            "Avoid momentum and swinging",
            "Stop if form breaks down"
        ]
    }
}

struct MinimalSetRow: View {
    let index: Int
    let set: ExerciseSet
    let onToggle: () -> Void
    let onDelete: () -> Void
    @ObservedObject private var unitStore = UnitSettingsStore.shared

    var body: some View {
        HStack(spacing: Spacing.s) {
            Button(action: onToggle) {
                Image(systemName: set.completed ? "checkmark.square.fill" : "square")
                    .font(.title)
                    .foregroundColor(set.completed ? .spaceGlow : .white.opacity(0.45))
            }
            .buttonStyle(.plain)

            Text("\(index)")
                .font(.body)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            Text("\(WeightFormatter.format(set.weight, unit: unitStore.unit))\(unitStore.unit.symbol) × \(set.reps)")
                .font(.body)
                .foregroundColor(.white)

            Spacer()

            Button {
                HapticFeedback.warning.trigger()
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.red.opacity(0.9))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ExerciseContributionRow: View {
    let muscle: MuscleGroup
    let completed: Double
    let planned: Double
    let valueText: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: muscle.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(muscle.tint)
                    .frame(width: 18, height: 18)

                Text(muscle.shortName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.95)

                if let subtypeTag = muscle.subtypeTag {
                    Text(subtypeTag)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(muscle.tint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(muscle.tint.opacity(0.16))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 8)

                Text(valueText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.86))
                    .monospacedDigit()
            }

            GeometryReader { geo in
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(muscle.tint)
                            .frame(width: max(4, geo.size.width * progress))
                            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.86), value: progress)
                    }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var progress: CGFloat {
        guard planned > 0 else { return 0 }
        return CGFloat(min(max(completed / planned, 0), 1))
    }
}

private struct ExerciseCompletionBadge: View {
    let completed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("\(completed)/\(max(total, 1))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(total > 0 && completed >= total ? "CLEARED" : "SETS")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(total > 0 && completed >= total ? .spaceGlow : .white.opacity(0.55))
                .tracking(0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    WorkoutFlowView(initialSession: nil, repository: FileSystemWorkoutRepository(), preloadedExercises: [])
        .environmentObject(SplitPlanStore())
}
