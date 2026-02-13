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

    init(initialSession: WorkoutSession?, repository: WorkoutRepository, preloadedExercises: [ExerciseLog] = []) {
        self.initialSession = initialSession
        self.repository = repository
        self.preloadedExercises = preloadedExercises
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
        let focusProgress = focusProgress(for: session, targets: todayTargets)
        let orderedFocusMuscles = todayTargets.keys.sorted { $0.displayName < $1.displayName }
        let totalTargetSets = todayTargets.values.reduce(0, +)
        let totalCompletedFocusSets = orderedFocusMuscles.reduce(0.0) { partial, muscle in
            partial + min(focusProgress.completed[muscle] ?? 0, todayTargets[muscle] ?? 0)
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if !todayTargets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            Text("Today’s Focus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            Text("\(formatSets(totalCompletedFocusSets)) / \(formatSets(totalTargetSets)) sets complete")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.65))
                        }

                        GeometryReader { geo in
                            let completion = totalTargetSets > 0 ? min(totalCompletedFocusSets / totalTargetSets, 1.0) : 0
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
                                let target = todayTargets[muscle] ?? 0
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
                }

                ForEach(session.exercises) { exercise in
                    MinimalExerciseCard(
                        exercise: exercise,
                        targetContributions: targetContributions(for: exercise, targets: todayTargets),
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
                }
            }
            .padding(.vertical, Spacing.m)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.clear)
    }

    private var todayTargetSets: [MuscleGroup: Double] {
        planStore.targetsForDate()
    }

    private func focusProgress(
        for session: WorkoutSession,
        targets: [MuscleGroup: Double]
    ) -> (completed: [MuscleGroup: Double], planned: [MuscleGroup: Double]) {
        var completed: [MuscleGroup: Double] = [:]
        var planned: [MuscleGroup: Double] = [:]
        let targetMuscles = Set(targets.keys)

        for exercise in session.exercises {
            guard let metadata = ExerciseDatabase.shared.getExercise(named: exercise.name) else { continue }
            let completedSetCount = Double(exercise.sets.filter { $0.completed }.count)
            let plannedSetCount = Double(exercise.sets.count)

            for muscle in metadata.primaryMuscles where targetMuscles.contains(muscle) {
                completed[muscle, default: 0] += completedSetCount
                planned[muscle, default: 0] += plannedSetCount
            }

            for muscle in metadata.secondaryMuscles where targetMuscles.contains(muscle) {
                completed[muscle, default: 0] += completedSetCount * TrainingTargets.secondaryMuscleCredit
                planned[muscle, default: 0] += plannedSetCount * TrainingTargets.secondaryMuscleCredit
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

                Text("\(formatSets(completed)) / \(formatSets(target))")
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

                Text("planned \(formatSets(planned))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(planned >= target ? .spaceGlow : .white.opacity(0.6))
            }
        }
    }

    private var completedRatio: Double {
        guard target > 0 else { return 0 }
        return min(max(completed / target, 0), 1)
    }

    private var plannedRatio: Double {
        guard target > 0 else { return 0 }
        return min(max(planned / target, 0), 1)
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
    let onAddSet: (Double, Int) -> Void
    let onToggleSet: (UUID) -> Void
    let onDeleteSet: (UUID) -> Void
    let onReplace: () -> Void
    let onDeleteExercise: () -> Void

    @ObservedObject private var unitStore = UnitSettingsStore.shared
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var showDemo = false
    @State private var swipeOffset: CGFloat = 0
    @State private var dragAxis: SwipeAxis?
    @FocusState private var focusedField: Field?
    private let deleteRevealWidth: CGFloat = 92
    private let exerciseDeleteGap: CGFloat = 10
    private let exerciseSwipeActivationHeight: CGFloat = 86
    private let exerciseHorizontalThresholdRatio: CGFloat = 2.2
    private let exerciseHorizontalMinimum: CGFloat = 24

    enum Field {
        case weight, reps
    }
    private enum SwipeAxis {
        case horizontal
        case vertical
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.94))
                .frame(width: deleteRevealWidth)
                .overlay {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .opacity(deleteRevealProgress)
                .padding(.vertical, Spacing.s)
                .padding(.trailing, 6)
                .onTapGesture {
                    if deleteRevealProgress > 0.98 {
                        HapticFeedback.warning.trigger()
                        onDeleteExercise()
                    }
                }

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

                        if !targetContributions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(targetContributions, id: \.muscle) { contribution in
                                        MuscleBadge(
                                            muscle: contribution.muscle,
                                            valueText: "\(formatSets(contribution.completedCredit))/\(formatSets(contribution.plannedCredit))",
                                            compact: true
                                        )
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        if exerciseMetadata != nil {
                            Button {
                                showDemo = true
                            } label: {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.detail)
                                    .foregroundColor(.spaceGlow)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.m)
                .sheet(isPresented: $showDemo) {
                    if let exerciseMetadata {
                        ExerciseDemoSheet(exercise: exerciseMetadata)
                    }
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
                }
                .padding(.horizontal, Spacing.m)
            }
            .padding(.vertical, Spacing.s)
            .themedCard(cornerRadius: 18)
            .offset(x: swipeOffset)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
            if swipeOffset != 0 {
                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0.12)) {
                    swipeOffset = 0
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    guard value.startLocation.y <= exerciseSwipeActivationHeight else { return }
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    if dragAxis == nil {
                        if horizontal > exerciseHorizontalMinimum,
                           horizontal > vertical * exerciseHorizontalThresholdRatio {
                            dragAxis = .horizontal
                        } else if vertical > 8, vertical > horizontal {
                            dragAxis = .vertical
                        }
                    }
                    guard dragAxis == .horizontal else { return }
                    if value.translation.width < 0 {
                        swipeOffset = max(-(deleteRevealWidth + exerciseDeleteGap), value.translation.width)
                    } else if swipeOffset < 0 {
                        swipeOffset = min(0, -(deleteRevealWidth + exerciseDeleteGap) + value.translation.width)
                    }
                }
                .onEnded { value in
                    defer { dragAxis = nil }
                    guard value.startLocation.y <= exerciseSwipeActivationHeight else { return }
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    guard horizontal > exerciseHorizontalMinimum else { return }
                    guard horizontal > vertical * exerciseHorizontalThresholdRatio else { return }
                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.88, blendDuration: 0.12)) {
                        swipeOffset = value.translation.width < -((deleteRevealWidth + exerciseDeleteGap) * 0.5) ? -(deleteRevealWidth + exerciseDeleteGap) : 0
                    }
                }
        )
        .onAppear {
            if let lastSet = exercise.sets.last {
                weightText = WeightFormatter.format(lastSet.weight, unit: unitStore.unit)
                repsText = "\(lastSet.reps)"
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

    private var deleteRevealProgress: CGFloat {
        min(max((-swipeOffset) / deleteRevealWidth, 0), 1)
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
    @State private var swipeOffset: CGFloat = 0
    @State private var dragAxis: SwipeAxis?
    @ObservedObject private var unitStore = UnitSettingsStore.shared
    private let deleteRevealWidth: CGFloat = 84
    private let setHorizontalThresholdRatio: CGFloat = 2.4
    private let setHorizontalMinimum: CGFloat = 22
    private enum SwipeAxis {
        case horizontal
        case vertical
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.red.opacity(0.94))
                .frame(width: deleteRevealWidth, height: 42)
                .overlay {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .opacity(deleteRevealProgress)
                .onTapGesture {
                    if deleteRevealProgress > 0.98 {
                        HapticFeedback.warning.trigger()
                        onDelete()
                    }
                }

            HStack(spacing: Spacing.s) {
                Button(action: onToggle) {
                    Image(systemName: set.completed ? "checkmark.square.fill" : "square")
                        .font(.title)
                        .foregroundColor(set.completed ? .spaceGlow : .white.opacity(0.45))
                }

                Text("\(index)")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 24)

                Text("\(WeightFormatter.format(set.weight, unit: unitStore.unit))\(unitStore.unit.symbol) × \(set.reps)")
                    .font(.body)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .offset(x: swipeOffset)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if swipeOffset != 0 {
                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0.12)) {
                    swipeOffset = 0
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    if dragAxis == nil {
                        if horizontal > setHorizontalMinimum,
                           horizontal > vertical * setHorizontalThresholdRatio {
                            dragAxis = .horizontal
                        } else if vertical > 8, vertical > horizontal {
                            dragAxis = .vertical
                        }
                    }
                    guard dragAxis == .horizontal else { return }
                    if value.translation.width < 0 {
                        swipeOffset = max(-deleteRevealWidth, value.translation.width)
                    } else if swipeOffset < 0 {
                        swipeOffset = min(0, -deleteRevealWidth + value.translation.width)
                    }
                }
                .onEnded { value in
                    defer { dragAxis = nil }
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    guard horizontal > setHorizontalMinimum else { return }
                    guard horizontal > vertical * setHorizontalThresholdRatio else { return }
                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.88, blendDuration: 0.12)) {
                        swipeOffset = value.translation.width < -(deleteRevealWidth * 0.5) ? -deleteRevealWidth : 0
                    }
                }
        )
    }

    private var deleteRevealProgress: CGFloat {
        min(max((-swipeOffset) / deleteRevealWidth, 0), 1)
    }
}

#Preview {
    WorkoutFlowView(initialSession: nil, repository: FileSystemWorkoutRepository(), preloadedExercises: [])
        .environmentObject(SplitPlanStore())
}
