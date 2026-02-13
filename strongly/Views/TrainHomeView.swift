import SwiftUI

struct TrainHomeView: View {
    @Binding var tabSelection: Int
    @AppStorage("user_name") private var userName = ""
    @AppStorage("preferred_workout_duration_minutes") private var preferredDuration = 45
    @AppStorage("preferred_workout_duration_user_override") private var durationUserOverride = false
    @State private var isGenerating = false
    @State private var generatedExercises: [ExerciseLog] = []
    @State private var showWorkout = false
    @State private var showAllTargets = false
    @State private var draftName = ""
    @State private var showNameCapture = false
    @EnvironmentObject private var planStore: SplitPlanStore

    var body: some View {
        ZStack {
            StarfieldBackground()

            if isGenerating {
                generatingView
            } else {
                planStartView
            }
        }
        .fullScreenCover(isPresented: $showWorkout) {
            WorkoutFlowView(
                initialSession: nil,
                repository: FileSystemWorkoutRepository(),
                preloadedExercises: generatedExercises
            )
        }
        .sheet(isPresented: $showNameCapture) {
            NameCaptureSheet(
                draftName: $draftName,
                onContinue: { enteredName in
                    let clean = enteredName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    userName = clean
                    showNameCapture = false
                }
            )
        }
        .onAppear {
            let clean = userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty {
                draftName = ""
                showNameCapture = true
            }
            applyRecommendedDurationIfNeeded()
        }
        .onChange(of: planStore.plan.trainingDays) { _, _ in
            applyRecommendedDurationIfNeeded()
        }
        .onChange(of: planStore.plan.splitType) { _, _ in
            applyRecommendedDurationIfNeeded()
        }
    }

    private var planStartView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                topHero
                planCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            if !planStore.dayConfig().isRest {
                startWorkoutBar
            }
        }
    }

    private var startWorkoutBar: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await generateWorkout()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Start Workout")
                        .font(.system(size: 18, weight: .semibold))
                }
                .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.spaceNavy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.spaceGlow)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var topHero: some View {
        return VStack(spacing: 10) {
            Image("StronglyIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .shadow(color: .white.opacity(0.35), radius: 18)

            Text(greetingTitle())
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var planCard: some View {
        let day = planStore.dayConfig()
        let targets = planStore.targetsForDate()
        let orderedGroups = orderedTrainingGroups(for: day)
        let visibleGroups = showAllTargets ? orderedGroups : Array(orderedGroups.prefix(8))
        let recommendedDuration = recommendedWorkoutDurationMinutes(for: day)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    DayTypeBadge(dayType: day.dayType)
                    Text(day.isRest ? "Rest Day" : "Today's Workout")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text(day.isRest ? "Recover today and keep your weekly rhythm." : "Focused and ready to train.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.62))
                }

                Spacer()
            }

            if planStore.canUndoRestShift() {
                Button {
                    withAnimation(Motion.quick) {
                        planStore.undoLastRestShift()
                        showAllTargets = false
                    }
                } label: {
                    Text("Undo Skip Rest")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.14))
                        .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if !day.isRest {
                durationCard(recommendedDuration: recommendedDuration)
            }

            if targets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.spaceGlow)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())

                        Text("No workout required today")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.88))
                    }

                    Text("Take a true rest day or shift this rest to your next training day.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.66))

                    HStack(spacing: 8) {
                        recoveryChip(systemName: "moon.stars.fill", label: "Sleep")
                        recoveryChip(systemName: "figure.walk", label: "Walk")
                        recoveryChip(systemName: "drop.fill", label: "Hydrate")
                    }

                    HStack(spacing: 10) {
                        Button {
                            withAnimation(Motion.quick) {
                                _ = planStore.skipRestTodayAndShiftCycle()
                                showAllTargets = false
                            }
                        } label: {
                            Text("Train Today")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.spaceNavy)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.spaceGlow)
                                .cornerRadius(10)
                        }
                        .disabled(!planStore.canSkipRestToday())
                        .opacity(planStore.canSkipRestToday() ? 1 : 0.5)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Today's Focus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 120), spacing: 10),
                            GridItem(.flexible(minimum: 120), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        ForEach(visibleGroups, id: \.self) { group in
                            targetTile(group: group)
                        }
                    }

                    if orderedGroups.count > 6 {
                        Button(showAllTargets ? "Show less" : "Show all \(orderedGroups.count)") {
                            withAnimation(Motion.quick) {
                                showAllTargets.toggle()
                            }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.spaceGlow)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    }
                }
            }

            Button("Edit plan in Plan tab") {
                tabSelection = 1
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white.opacity(0.72))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: day.isRest ? 320 : 420, alignment: .topLeading)
        .themedCard(cornerRadius: 22)
    }

    private func durationCard(recommendedDuration: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Workout Time")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.72))
                Spacer()
                if durationUserOverride, recommendedDuration != preferredDuration {
                    Text("Recommended \(recommendedDuration)m")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.spaceGlow)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 10) {
                Button {
                    durationUserOverride = true
                    preferredDuration = max(15, preferredDuration - 5)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }

                Text("\(preferredDuration) min")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(minWidth: 104, alignment: .center)

                Button {
                    durationUserOverride = true
                    preferredDuration = min(120, preferredDuration + 5)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }

                Spacer()

                Button {
                    withAnimation(Motion.quick) {
                        durationUserOverride = false
                        applyRecommendedDurationIfNeeded()
                    }
                } label: {
                    Text("Auto")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.spaceGlow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.spaceGlow.opacity(0.45), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func targetTile(group: MuscleTrainingGroup) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(groupColor(for: group).opacity(0.24))
                    .frame(width: 26, height: 26)
                if group == .abs {
                    sixPackGlyph
                        .frame(width: 10, height: 13)
                } else {
                    Image(systemName: groupSymbol(for: group))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(groupColor(for: group))
                }
            }

            Text(group.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var generatingView: some View {
        VStack(spacing: 32) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Building your workout...")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func generateWorkout() async {
        isGenerating = true

        let generator = WorkoutGenerator.shared
        let today = Date()
        let muscles = plannedMuscles(for: today)
        let perSessionTargets = plannedTargets(for: today)
        let focus = automaticFocus(for: today)
        let equipment = automaticEquipment(for: today)

        var duration = preferredDuration
        var bestExercises: [ExerciseLog] = []
        var bestCoverage = -1.0
        var bestDuration = duration

        for _ in 0..<8 {
            let request = WorkoutRequest(
                duration: duration,
                targetMuscles: muscles,
                equipment: equipment,
                focus: focus,
                preferredExercises: []
            )
            let workout = await generator.generateIntelligentWorkout(request: request)
            if workout.exercises.isEmpty {
                break
            }

            let maxTotalSets = max(workout.exercises.count, Int(round(Double(duration) / 2.5)))
            let allocation = allocateSetsForTargets(
                exercises: workout.exercises,
                targets: perSessionTargets,
                maxTotalSets: maxTotalSets
            )

            let isBetterCoverage = allocation.coverage > bestCoverage + 0.01
            let isTieAndShorter = abs(allocation.coverage - bestCoverage) <= 0.01 && duration < bestDuration
            if isBetterCoverage || isTieAndShorter {
                bestCoverage = allocation.coverage
                bestExercises = allocation.exercises
                bestDuration = duration
            }

            if allocation.coverage >= 0.98 {
                break
            }

            if duration >= 120 {
                break
            }
            duration = min(120, duration + 10)
        }

        generatedExercises = bestExercises

        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                HapticFeedback.success.trigger()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isGenerating = false
            showWorkout = true
        }
    }

    private func plannedMuscles(for date: Date) -> [MuscleGroup] {
        let day = planStore.dayConfig(for: date)
        let muscles = day.resolvedMuscles()
        if muscles.isEmpty {
            return recoveryMuscles()
        }
        return muscles
    }

    private func plannedTargets(for date: Date) -> [MuscleGroup: Double] {
        planStore.targetsForDate(date)
    }

    private func formatSets(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func recoveryChip(systemName: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }

    private func recoveryMuscles() -> [MuscleGroup] {
        [.abs, .glutes, .hamstrings, .shoulderRear, .backThickness]
    }

    private func greetingTitle() -> String {
        let clean = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return "Today’s Plan"
        }
        let first = clean.split(separator: " ").first.map(String.init) ?? clean
        return "Hi, \(first)"
    }

    private func recommendedWorkoutDurationMinutes(for day: SplitDayConfig) -> Int {
        if day.isRest {
            return 0
        }

        let base: Int
        switch day.dayType {
        case .push, .pull:
            base = 45
        case .legs, .lower:
            base = 50
        case .upper:
            base = 50
        case .full:
            base = 55
        case .rest:
            base = 0
        }

        let dayAdjustment: Int
        switch planStore.plan.trainingDays {
        case 4:
            dayAdjustment = 10
        case 5:
            dayAdjustment = 5
        default:
            dayAdjustment = 0
        }

        let muscleCount = day.resolvedMuscles().count
        let extra = max(0, muscleCount - 4) * 2
        let raw = min(75, max(30, base + dayAdjustment + extra))
        let rounded = Int((Double(raw) / 5.0).rounded() * 5.0)
        return min(75, max(30, rounded))
    }

    private func applyRecommendedDurationIfNeeded() {
        let day = planStore.dayConfig()
        guard !day.isRest else { return }
        guard !durationUserOverride else { return }
        preferredDuration = recommendedWorkoutDurationMinutes(for: day)
    }

    private func orderedTrainingGroups(for day: SplitDayConfig) -> [MuscleTrainingGroup] {
        var ordered: [MuscleTrainingGroup] = []
        for muscle in day.resolvedMuscles() {
            let group = muscle.trainingGroup
            if !ordered.contains(group) {
                ordered.append(group)
            }
        }
        return ordered
    }

    private func groupSymbol(for group: MuscleTrainingGroup) -> String {
        switch group {
        case .chest:
            return "lungs.fill"
        case .back:
            return "figure.rower"
        case .shoulders:
            return "figure.strengthtraining.functional"
        case .quads, .hamstrings, .glutes, .calves:
            return "figure.walk.motion"
        case .biceps, .triceps:
            return "dumbbell.fill"
        case .abs:
            return "square"
        }
    }

    private var sixPackGlyph: some View {
        VStack(spacing: 1.4) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 1.4) {
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(Color.spaceNavy.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 0.8)
                                .stroke(groupColor(for: .abs), lineWidth: 0.8)
                        )
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(Color.spaceNavy.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 0.8)
                                .stroke(groupColor(for: .abs), lineWidth: 0.8)
                        )
                }
            }
        }
    }

    private func groupColor(for group: MuscleTrainingGroup) -> Color {
        switch group {
        case .chest:
            return .chestColor
        case .back:
            return .backColor
        case .shoulders:
            return .shoulderColor
        case .quads, .hamstrings, .glutes, .calves:
            return .legColor
        case .biceps, .triceps:
            return .armColor
        case .abs:
            return .coreColor
        }
    }

    private func automaticFocus(for date: Date) -> WorkoutFocus {
        let day = planStore.dayConfig(for: date)
        if day.isRest {
            return .mobility
        }
        return .balanced
    }

    private func automaticEquipment(for date: Date) -> EquipmentType {
        .both
    }

    private func allocateSetsForTargets(
        exercises: [ExerciseLog],
        targets: [MuscleGroup: Double],
        maxTotalSets: Int
    ) -> (exercises: [ExerciseLog], coverage: Double) {
        guard !exercises.isEmpty else { return ([], 0) }

        var selected = exercises
        var setCounts: [UUID: Int] = [:]
        var achieved: [MuscleGroup: Double] = [:]
        var metadata: [UUID: Exercise] = [:]

        for exercise in selected {
            if let ex = ExerciseDatabase.shared.getExercise(named: exercise.name) {
                metadata[exercise.id] = ex
            }
        }

        var totalSets = 0
        for exercise in selected {
            guard totalSets < maxTotalSets else { break }
            guard metadata[exercise.id] != nil else { continue }
            setCounts[exercise.id] = 1
            totalSets += 1
            applyContribution(
                for: exercise.id,
                into: &achieved,
                using: metadata
            )
        }

        while totalSets < maxTotalSets {
            var bestExerciseId: UUID?
            var bestScore = 0.0

            for exercise in selected {
                guard let ex = metadata[exercise.id] else { continue }
                let current = setCounts[exercise.id] ?? 0
                if current >= maxSetsPerExercise(for: ex) { continue }

                var score = 0.0
                for (muscle, target) in targets {
                    let remaining = max(0, target - (achieved[muscle] ?? 0))
                    if remaining <= 0 { continue }
                    let contribution = contributionOf(exercise: ex, to: muscle)
                    score += remaining * contribution
                }

                if score > bestScore {
                    bestScore = score
                    bestExerciseId = exercise.id
                }
            }

            guard let bestExerciseId, bestScore > 0 else { break }
            setCounts[bestExerciseId, default: 0] += 1
            totalSets += 1
            applyContribution(
                for: bestExerciseId,
                into: &achieved,
                using: metadata
            )
        }

        for i in selected.indices {
            let exerciseId = selected[i].id
            let desired = setCounts[exerciseId] ?? 1
            let seed = selected[i].sets.first ?? ExerciseSet(weight: 0, reps: 10, completed: false)
            let reps: Int
            let weight: Double

            if let ex = metadata[exerciseId] {
                reps = prescribedReps(for: ex, seedReps: seed.reps)
                weight = prescribedWeight(for: ex, seedWeight: seed.weight)
            } else {
                reps = seed.reps
                weight = seed.weight
            }

            selected[i].sets = (0..<desired).map { _ in
                ExerciseSet(weight: weight, reps: reps, completed: false)
            }
        }

        var ratioSum = 0.0
        var ratioCount = 0
        for (muscle, target) in targets {
            guard target > 0 else { continue }
            ratioSum += min((achieved[muscle] ?? 0) / target, 1.0)
            ratioCount += 1
        }
        let coverage = ratioCount > 0 ? ratioSum / Double(ratioCount) : 1.0

        return (selected, coverage)
    }

    private func maxSetsPerExercise(for exercise: Exercise) -> Int {
        if exercise.focus == .mobility {
            return exercise.isCompound ? 4 : 3
        }
        if exercise.isCompound {
            return 5
        }
        if exercise.primaryMuscles.contains(.abs) || exercise.primaryMuscles.contains(.calves) {
            return 5
        }
        return 4
    }

    private func prescribedReps(for exercise: Exercise, seedReps: Int) -> Int {
        let range = prescribedRepRange(for: exercise)
        if range.contains(seedReps) {
            return seedReps
        }
        return (range.lowerBound + range.upperBound) / 2
    }

    private func prescribedWeight(for exercise: Exercise, seedWeight: Double) -> Double {
        if exercise.equipment == .bodyweight || exercise.equipment == .band {
            return 0
        }
        return seedWeight
    }

    private func prescribedRepRange(for exercise: Exercise) -> ClosedRange<Int> {
        if exercise.focus == .mobility {
            return 8...15
        }
        if exercise.isCompound {
            if exercise.equipment == .bodyweight {
                return 8...15
            }
            return 5...10
        }
        if exercise.primaryMuscles.contains(.abs) {
            return 12...20
        }
        return 10...18
    }

    private func applyContribution(
        for exerciseId: UUID,
        into achieved: inout [MuscleGroup: Double],
        using metadata: [UUID: Exercise]
    ) {
        guard let exercise = metadata[exerciseId] else { return }
        for muscle in exercise.primaryMuscles {
            achieved[muscle, default: 0] += 1
        }
        for muscle in exercise.secondaryMuscles {
            achieved[muscle, default: 0] += TrainingTargets.secondaryMuscleCredit
        }
    }

    private func contributionOf(exercise: Exercise, to muscle: MuscleGroup) -> Double {
        if exercise.primaryMuscles.contains(muscle) {
            return 1.0
        }
        if exercise.secondaryMuscles.contains(muscle) {
            return TrainingTargets.secondaryMuscleCredit
        }
        return 0
    }
}

private struct NameCaptureSheet: View {
    @Binding var draftName: String
    let onContinue: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    private let accent = Color(hexString: "00C805")
    private let cleanNameLimit = 28

    var body: some View {
        NavigationStack {
            ZStack {
                StarfieldBackground().ignoresSafeArea()
                backgroundGlow

                VStack(alignment: .leading, spacing: 22) {
                    header
                    nameInputCard
                    Spacer(minLength: 0)
                    continueButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 18)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isNameFocused = true
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Circle()
                        .stroke(accent.opacity(0.55), lineWidth: 1)
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome to Strongly")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                    Text("Set Your Name")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Text("What should we call you?")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("We will personalize your Train tab with this name.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var nameInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.65))

            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(accent)
                    .frame(width: 22)

                TextField("Enter your first name", text: $draftName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold))
                    .onSubmit {
                        submit()
                    }
                    .onChange(of: draftName) { _, newValue in
                        if newValue.count > cleanNameLimit {
                            draftName = String(newValue.prefix(cleanNameLimit))
                        }
                    }

                if !cleanName.isEmpty {
                    Button {
                        draftName = ""
                        isNameFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.black.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(cleanName.isEmpty ? Color.white.opacity(0.15) : accent.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 8) {
                Image(systemName: cleanName.isEmpty ? "circle.dashed" : "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(cleanName.isEmpty ? .white.opacity(0.45) : accent)
                Text(cleanName.isEmpty ? "Enter a name to continue" : "Looks good")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.68))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var continueButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.system(size: 18, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.black.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(accent.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.45), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(cleanName.isEmpty)
        .opacity(cleanName.isEmpty ? 0.45 : 1)
    }

    private var backgroundGlow: some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 300
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.black.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var cleanName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        let clean = cleanName
        guard !clean.isEmpty else { return }
        onContinue(clean)
        if !clean.isEmpty {
            dismiss()
        }
    }
}
