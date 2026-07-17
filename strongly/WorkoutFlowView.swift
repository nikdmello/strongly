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

struct ExerciseTrainingCue: Hashable {
    let lastWeightLb: Double?
    let lastReps: Int?
    let targetWeightLb: Double
    let targetReps: Int
    let repRange: RepRange
    let isProgression: Bool
}

struct WorkoutFlowView: View {
    let initialSession: WorkoutSession?
    let repository: WorkoutRepository
    let preloadedExercises: [ExerciseLog]
    let targetOverrides: [MuscleGroup: Double]
    let setBudgetOverride: Int?

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
    @State private var completedSession: WorkoutSession?
    @State private var showDeferLeftoversAlert = false
    @State private var pendingDeficits: [MuscleGroup: Double] = [:]
    @State private var workoutHistory: [WorkoutSession] = []

    init(
        initialSession: WorkoutSession?,
        repository: WorkoutRepository,
        preloadedExercises: [ExerciseLog] = [],
        targetOverrides: [MuscleGroup: Double] = [:],
        setBudgetOverride: Int? = nil
    ) {
        self.initialSession = initialSession
        self.repository = repository
        self.preloadedExercises = preloadedExercises
        self.targetOverrides = targetOverrides
        self.setBudgetOverride = setBudgetOverride
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
            workoutContent(sessionViewModel.currentSession ?? WorkoutSession(exercises: []))
        }
        .overlay(alignment: .bottomTrailing) {
            addExerciseButton
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
                .background(Color.black.opacity(0.82))
                .cornerRadius(24)
                .overlay(
                    AnimatedRainbowStroke(cornerRadius: 24, lineWidth: 1.4)
                )
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
            Task {
                workoutHistory = (try? await repository.fetchAll()) ?? []
            }
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
        .alert("End Workout?", isPresented: $showCancelAlert) {
            Button("Keep Training", role: .cancel) {}
            Button("Discard", role: .destructive) {
                sessionViewModel.cancelWorkout()
                dismiss()
            }
        } message: {
            Text("This workout has unsaved work.")
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
        .alert("Finish Today?", isPresented: $showDeferLeftoversAlert) {
            Button("Keep Training", role: .cancel) {}
            Button("Finish") {
                let deficits = pendingDeficits
                pendingDeficits = [:]
                planStore.deferLeftovers(deficits)
                Task {
                    await finalizeWorkout()
                }
            }
        } message: {
            Text(deferLeftoversMessage)
        }
        .confirmationDialog("Replace Exercise", isPresented: .constant(false), titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
        }
    }

    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Add")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.82))
            .clipShape(Capsule())
            .overlay(
                AnimatedRainbowStroke(cornerRadius: 999, lineWidth: 1.3)
            )
            .shadow(color: .black.opacity(0.24), radius: 11, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.trailing, Spacing.m)
        .padding(.bottom, Spacing.m)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    if let session = sessionViewModel.currentSession, !session.exercises.isEmpty {
                        showCancelAlert = true
                    } else {
                        sessionViewModel.cancelWorkout()
                        dismiss()
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.74))
                }
                .buttonStyle(.plain)
                .frame(width: headerSideWidth, alignment: .leading)

                centerHeaderContent
                    .frame(maxWidth: .infinity)

                Button {
                    Task {
                        await completeWorkoutWithSummary()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Finish")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(canComplete ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(canComplete ? Color.black.opacity(0.62) : Color.clear)
                    .overlay(
                        ZStack {
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(canComplete ? 0 : 0.2), lineWidth: 1)
                            if canComplete {
                                AnimatedRainbowStroke(cornerRadius: 999, lineWidth: 1)
                            }
                        }
                    )
                    .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canComplete || sessionViewModel.isSaving || sessionViewModel.isCompleting)
                .frame(width: headerSideWidth, alignment: .trailing)
            }

            if let session = sessionViewModel.currentSession {
                contractStrip(session: session)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: PremiumLayout.sectionRadius - 4, style: .continuous)
                .fill(Color.themedCard.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: PremiumLayout.sectionRadius - 4, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PremiumLayout.sectionRadius - 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PremiumLayout.sectionRadius - 4, style: .continuous))
                )
                .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
        )
        .padding(.horizontal, Layout.screenHorizontal)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func contractStrip(session: WorkoutSession) -> some View {
        let completed = completedSets(session)
        let planned = plannedSetGoal(for: session)
        let left = max(planned - completed, 0)
        let warning = contractWarning(session: session)

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                contractPill(
                    title: "Today",
                    value: "\(planned)",
                    tint: .white.opacity(0.82)
                )
                contractPill(
                    title: "Done",
                    value: "\(completed)",
                    tint: completed >= planned ? .spaceGlow : .white.opacity(0.82)
                )
                contractPill(
                    title: "Left",
                    value: "\(left)",
                    tint: warning ? .orange : .spaceGlow
                )
            }

            if warning {
                Button {
                    fixPlanForContract(session: session)
                } label: {
                    Text("Fill Today")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.9))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: completed)
        .animation(.easeInOut(duration: 0.2), value: warning)
    }

    private func contractPill(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.58))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var centerHeaderContent: some View {
        if restTimer.isActive {
            HStack(spacing: 6) {
                timerAdjustButton(symbol: "minus") {
                    restTimer.adjustActiveTimer(by: -15)
                }

                Text(restTimeDisplay)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()

                timerAdjustButton(symbol: "plus") {
                    restTimer.adjustActiveTimer(by: 15)
                }

                Button {
                    restTimer.stopTimer()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color.spaceGlow.opacity(0.2), Color.spacePanelInner.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.spaceGlow.opacity(0.38), lineWidth: 1)
            )
        } else {
            Text(compactProgressText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    private func timerAdjustButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var restTimeDisplay: String {
        let minutes = restTimer.remainingTime / 60
        let seconds = restTimer.remainingTime % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var compactProgressText: String {
        guard let session = sessionViewModel.currentSession else { return "0/0 sets" }
        let remaining = setsLeftToPace(session)
        return "\(remaining) sets left"
    }

    private var headerSideWidth: CGFloat {
        86
    }

    private func workoutContent(_ session: WorkoutSession) -> some View {
        let todayTargets = todayTargetSets.filter { $0.value > 0 }
        let focusTargetMuscles = Set(todayTargets.keys)
        let focusProgress = focusProgress(for: session, targetMuscles: focusTargetMuscles)
        let effectiveTargets = todayTargets.isEmpty
            ? focusProgress.planned.filter { $0.value > 0 }
            : todayTargets
        let orderedFocusMuscles = effectiveTargets.keys.sorted { $0.displayName < $1.displayName }
        let completedWorkSets = completedSets(session)
        let quotaGoal = plannedSetGoal(for: session)

        return List {
            if !orderedFocusMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Text("Today")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Text("\(completedWorkSets)/\(quotaGoal)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                    }

                    GeometryReader { geo in
                        let completion = quotaGoal > 0
                            ? min(Double(completedWorkSets) / Double(quotaGoal), 1.0)
                            : 0
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 8)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .overlay {
                                        AnimatedRainbowRail(height: 8)
                                    }
                                    .clipShape(Capsule())
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
                .themedCard(cornerRadius: 22)
                .listRowInsets(EdgeInsets(top: Spacing.m, leading: Layout.screenHorizontal + 2, bottom: Spacing.s, trailing: Layout.screenHorizontal + 2))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if session.exercises.isEmpty {
                VStack(spacing: Spacing.m) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.55))

                    VStack(spacing: Spacing.xs) {
                        Text("Ready when you are")
                            .font(.title)
                            .foregroundColor(.white)

                        Text("Add the first movement and start logging")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                    }

                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
                .themedCard(cornerRadius: 22)
                .listRowInsets(EdgeInsets(top: 0, leading: Layout.screenHorizontal + 2, bottom: Spacing.m, trailing: Layout.screenHorizontal + 2))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(session.exercises) { exercise in
                    MinimalExerciseCard(
                        exercise: exercise,
                        trainingCue: trainingCue(for: exercise.name),
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
                    .listRowInsets(EdgeInsets(top: 0, leading: Layout.screenHorizontal + 2, bottom: Spacing.xs, trailing: Layout.screenHorizontal + 2))
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
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 84)
        }
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

    private func trainingCue(for exerciseName: String) -> ExerciseTrainingCue? {
        guard let exercise = ExerciseDatabase.shared.getExercise(named: exerciseName) else { return nil }

        let repRange = ProgressionEngine.repRange(for: exercise)
        let suggestedTarget = ProgressionEngine.suggestedSetTarget(
            for: exerciseName,
            exercise: exercise,
            history: workoutHistory
        )
        let lastSet = lastCompletedSet(for: exerciseName)

        return ExerciseTrainingCue(
            lastWeightLb: lastSet?.weight,
            lastReps: lastSet?.reps,
            targetWeightLb: suggestedTarget.weightLb,
            targetReps: suggestedTarget.reps,
            repRange: repRange,
            isProgression: suggestedTarget.progressed
        )
    }

    private func lastCompletedSet(for exerciseName: String) -> ExerciseSet? {
        for session in workoutHistory.sorted(by: { $0.date > $1.date }) {
            guard let exercise = session.exercises.first(where: { $0.name.lowercased() == exerciseName.lowercased() }) else {
                continue
            }
            if let set = exercise.sets.last(where: { $0.completed }) {
                return set
            }
        }
        return nil
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

    private var requiredSetGoal: Int {
        let targets = requiredTargetsForContract
        guard !targets.isEmpty else { return 0 }
        return planStore.requiredSetBudget(for: planStore.dayConfig(), targets: targets)
    }

    private func plannedSetGoal(for session: WorkoutSession) -> Int {
        if let setBudgetOverride {
            return max(setBudgetOverride, 0)
        }
        return requiredSetGoal
    }

    private func contractWarning(session: WorkoutSession) -> Bool {
        totalSets(session) < plannedSetGoal(for: session)
    }

    private func setsLeftToPace(_ session: WorkoutSession) -> Int {
        max(plannedSetGoal(for: session) - completedSets(session), 0)
    }

    private var requiredTargetsForContract: [MuscleGroup: Double] {
        todayTargetSets.filter { $0.value > 0 }
    }

    private func plannedContractDeficits(for session: WorkoutSession) -> [MuscleGroup: Double] {
        let targets = requiredTargetsForContract
        guard !targets.isEmpty else { return [:] }
        let plannedCredits = MuscleTracker.setCredits(for: session.exercises, completedOnly: false)
        return MuscleTracker.deficits(required: targets, achieved: plannedCredits)
    }

    private func fixPlanForContract(session: WorkoutSession) {
        guard !requiredTargetsForContract.isEmpty else { return }
        var liveSession = session
        let plannedGoal = plannedSetGoal(for: session)
        guard totalSets(liveSession) < plannedGoal else { return }
        var deficits = plannedContractDeficits(for: liveSession)

        var safety = 0
        while totalSets(liveSession) < plannedGoal && safety < 48 {
            guard let exerciseId = bestExerciseForDeficit(deficits: deficits, exercises: liveSession.exercises)
                    ?? liveSession.exercises.first?.id else {
                break
            }
            let rawSeed = liveSession.exercises.first(where: { $0.id == exerciseId })?.sets.last
                ?? ExerciseSet(weight: 0, reps: 10, completed: false)
            let seedWeight = min(max(rawSeed.weight, 0), 1000)
            let seedReps = min(max(rawSeed.reps, 1), 100)
            sessionViewModel.addSet(to: exerciseId, weight: seedWeight, reps: seedReps)

            guard let updated = sessionViewModel.currentSession else { break }
            liveSession = updated
            deficits = plannedContractDeficits(for: updated)
            safety += 1
        }

        if totalSets(liveSession) >= plannedGoal {
            HapticFeedback.success.trigger()
        } else {
            HapticFeedback.warning.trigger()
        }
    }

    private func bestExerciseForDeficit(
        deficits: [MuscleGroup: Double],
        exercises: [ExerciseLog]
    ) -> UUID? {
        guard !exercises.isEmpty else { return nil }
        return exercises
            .compactMap { exercise -> (UUID, Double)? in
                guard let metadata = ExerciseDatabase.shared.getExercise(named: exercise.name) else { return nil }
                var score = 0.0
                for muscle in metadata.primaryMuscles {
                    score += deficits[muscle] ?? 0
                }
                for muscle in metadata.secondaryMuscles {
                    score += (deficits[muscle] ?? 0) * TrainingTargets.secondaryMuscleCredit
                }
                guard score > 0 else { return nil }
                return (exercise.id, score)
            }
            .max(by: { $0.1 < $1.1 })?
            .0
    }

    private func showSetCelebration() {
        celebrationMessage = ["Set logged", "Good set", "Work counted", "Keep going"].randomElement() ?? "Set logged"
        showCelebration = true
        HapticFeedback.light.trigger()

        DispatchQueue.main.asyncAfter(deadline: .now() + WorkoutConstants.celebrationDuration) {
            showCelebration = false
        }
    }

    private func showCompletionCelebration() {
        celebrationMessage = "Workout complete"
        showCelebration = true
        HapticFeedback.success.trigger()
    }

    private func completeWorkoutWithSummary() async {
        guard let session = sessionViewModel.currentSession else { return }
        let deficits = planStore.completionDeficits(for: session)
        if deficits.isEmpty {
            await finalizeWorkout()
            return
        }
        pendingDeficits = deficits
        showDeferLeftoversAlert = true
    }

    private func finalizeWorkout() async {
        guard let sessionBeforeSave = sessionViewModel.currentSession else { return }
        completedSession = sessionBeforeSave
        restTimer.stopTimer()
        await sessionViewModel.completeWorkout()
        planStore.advanceAfterWorkout(session: sessionBeforeSave)

        if sessionViewModel.error == nil {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isCompleted = true
            }
            HapticFeedback.success.trigger()
        }
    }

    private var deferLeftoversMessage: String {
        guard !pendingDeficits.isEmpty else { return "Finish now and move the remaining work to your next matching session?" }
        let items = pendingDeficits
            .sorted { $0.key.displayName < $1.key.displayName }
            .prefix(3)
            .map { "\($0.key.displayName): \(formatSets($0.value))" }
            .joined(separator: "\n")
        return "Strongly will move this to the next matching session.\n\(items)"
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

        return .workoutComplete
    }

    private var completionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PremiumLayout.sectionSpacing) {
                completionHero

                if let session = completedSession {
                    completionStats(session)
                    progressionSummary(session)
                    nextSessionCard
                }

                Button {
                    dismiss()
                } label: {
                    Text("Back to Today")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, Layout.screenHorizontal)
            .padding(.top, 28)
            .padding(.bottom, 28)
        }
    }

    private var completionHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Work complete.")
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)
            Text("Logged, saved, and folded into your next targets.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .premiumSectionCard(cornerRadius: 24)
    }

    private func completionStats(_ session: WorkoutSession) -> some View {
        HStack(spacing: 8) {
            completionStat(title: "Sets", value: "\(completedSets(session))")
            completionStat(title: "Moves", value: "\(session.exercises.count)")
            completionStat(title: "Volume", value: "\(Int(displayVolume(totalVolume(session))))")
        }
        .premiumSectionCard(cornerRadius: 22)
    }

    private func completionStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func progressionSummary(_ session: WorkoutSession) -> some View {
        let progressed = progressedExercises(in: session)
        return VStack(alignment: .leading, spacing: 12) {
            SectionLead(
                title: progressed.isEmpty ? "Progress banked" : "Moved forward",
                subtitle: progressed.isEmpty
                    ? "This session still counted. Repeat the work and the targets will move when you earn them."
                    : "These movements beat your previous completed set."
            )

            if progressed.isEmpty {
                Text("This session counted. Your next targets now reflect the work you finished.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))
            } else {
                VStack(spacing: 8) {
                    ForEach(progressed.prefix(4), id: \.self) { name in
                        HStack {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .foregroundColor(.spaceGlow)
                            Text(name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("beat last time")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.58))
                        }
                    }
                }
            }
        }
        .premiumSectionCard(cornerRadius: 22)
    }

    private var nextSessionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLead(
                title: "Next",
                subtitle: "Return to Today. Strongly will handle the next target."
            )
            Text("Recover tonight. Return to Today for the next target.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
        }
        .premiumSectionCard(cornerRadius: 22)
    }

    private func progressedExercises(in session: WorkoutSession) -> [String] {
        session.exercises.compactMap { exercise in
            guard let bestCurrent = exercise.sets.filter({ $0.completed }).max(by: setPerformanceLessThan) else {
                return nil
            }
            guard let previous = bestHistoricalSet(for: exercise.name, before: session.date) else {
                return nil
            }
            return setPerformanceLessThan(previous, bestCurrent) ? exercise.name : nil
        }
    }

    private func bestHistoricalSet(for exerciseName: String, before date: Date) -> ExerciseSet? {
        workoutHistory
            .filter { $0.date < date }
            .flatMap { session in
                session.exercises
                    .filter { $0.name.lowercased() == exerciseName.lowercased() }
                    .flatMap { $0.sets.filter(\.completed) }
            }
            .max(by: setPerformanceLessThan)
    }

    private func setPerformanceLessThan(_ lhs: ExerciseSet, _ rhs: ExerciseSet) -> Bool {
        let lhsScore = lhs.weight * Double(lhs.reps)
        let rhsScore = rhs.weight * Double(rhs.reps)
        if lhsScore == rhsScore {
            return lhs.reps < rhs.reps
        }
        return lhsScore < rhsScore
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
                                    .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: plannedRatio)
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
                                    .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: completedRatio)
                            }
                        }

                Text("planned \(formatSets(scheduled))")
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
    let trainingCue: ExerciseTrainingCue?
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

            if let trainingCue {
                trainingCueRow(trainingCue)
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
                        .foregroundColor(canAddSet ? .white : .white.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .background(canAddSet ? Color.black.opacity(0.62) : Color.white.opacity(0.18))
                        .clipShape(Circle())
                        .overlay(
                            Group {
                                if canAddSet {
                                    AnimatedRainbowCircleStroke(lineWidth: 1.1)
                                }
                            }
                        )
                }
                .disabled(!canAddSet)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.m)
        }
        .padding(.vertical, Spacing.s)
        .themedCard(cornerRadius: 20)
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

    private func trainingCueRow(_ cue: ExerciseTrainingCue) -> some View {
        HStack(spacing: 8) {
            cueBlock(
                title: "Last",
                value: lastTimeText(for: cue),
                tint: .white.opacity(0.78)
            )
            cueBlock(
                title: "Today",
                value: targetText(for: cue),
                tint: .spaceGlow
            )
        }
    }

    private func cueBlock(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    private func lastTimeText(for cue: ExerciseTrainingCue) -> String {
        guard let weight = cue.lastWeightLb, let reps = cue.lastReps else {
            return "First run"
        }
        return "\(WeightFormatter.format(weight, unit: unitStore.unit))\(unitStore.unit.symbol) x \(reps)"
    }

    private func targetText(for cue: ExerciseTrainingCue) -> String {
        if cue.lastWeightLb == nil && cue.targetWeightLb == 0 {
            return "Pick load x \(cue.targetReps)"
        }
        return "\(WeightFormatter.format(cue.targetWeightLb, unit: unitStore.unit))\(unitStore.unit.symbol) x \(cue.targetReps)"
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
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                                .overlay(
                                    AnimatedRainbowStroke(cornerRadius: 999, lineWidth: 1)
                                )

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
