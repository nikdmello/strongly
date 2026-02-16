import SwiftUI

struct TrainHomeView: View {
    @Binding var tabSelection: Int
    @AppStorage("user_name") private var userName = ""
    @AppStorage("preferred_workout_duration_minutes") private var preferredDuration = 45
    @AppStorage("preferred_workout_duration_user_override") private var durationUserOverride = false
    @State private var isGenerating = false
    @State private var generatedExercises: [ExerciseLog] = []
    @State private var generatedTargets: [MuscleGroup: Double] = [:]
    @State private var showWorkout = false
    @State private var draftName = ""
    @State private var showNameCapture = false
    @State private var autoDurationNote: String?
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
                preloadedExercises: generatedExercises,
                targetOverrides: generatedTargets
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
        let rawTargets = planStore.targetsForDate()
        let orderedGroups = orderedTrainingGroups(for: day)
        let recommendedDuration = recommendedWorkoutDurationMinutes(for: day, targets: rawTargets)
        let previewTargets = previewSessionTargets(
            for: day,
            rawTargets: rawTargets,
            durationMinutes: preferredDuration
        )
        let displayGroups = orderedGroups.filter { targetSets(for: $0, in: previewTargets) > 0 }

        return VStack(alignment: .leading, spacing: 16) {
            trainCardHeader(day: day)

            if day.isRest || previewTargets.isEmpty {
                restDayBody()
            } else {
                trainingDayBody(
                    day: day,
                    targets: previewTargets,
                    groups: displayGroups,
                    selectedDuration: preferredDuration,
                    recommendedDuration: recommendedDuration
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: day.isRest ? 280 : 360, alignment: .topLeading)
        .themedCard(cornerRadius: 22)
    }

    private func trainCardHeader(day: SplitDayConfig) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                DayTypeBadge(dayType: day.dayType)
                Text(day.isRest ? "Rest Day" : "\(day.dayType.rawValue) Day")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            changeTodayMenu
        }
    }

    private var changeTodayMenu: some View {
        Menu {
            if planStore.hasAgendaOverrideForToday() {
                Button("Back to Plan") {
                    withAnimation(Motion.quick) {
                        planStore.resetAgendaForTodayToPlan()
                        applyRecommendedDurationIfNeeded()
                    }
                }
            }

            Button("Rest") {
                withAnimation(Motion.quick) {
                    planStore.setAgendaForToday(.rest)
                }
            }

            Divider()

            Button("Push") {
                withAnimation(Motion.quick) {
                    planStore.setAgendaForToday(.push)
                    applyRecommendedDurationIfNeeded()
                }
            }
            Button("Pull") {
                withAnimation(Motion.quick) {
                    planStore.setAgendaForToday(.pull)
                    applyRecommendedDurationIfNeeded()
                }
            }
            Button("Legs") {
                withAnimation(Motion.quick) {
                    planStore.setAgendaForToday(.legs)
                    applyRecommendedDurationIfNeeded()
                }
            }
            Button("Upper") {
                withAnimation(Motion.quick) {
                    planStore.setAgendaForToday(.upper)
                    applyRecommendedDurationIfNeeded()
                }
            }
            Button("Lower") {
                withAnimation(Motion.quick) {
                    planStore.setAgendaForToday(.lower)
                    applyRecommendedDurationIfNeeded()
                }
            }
            Button("Full Body") {
                withAnimation(Motion.quick) {
                    planStore.setAgendaForToday(.full)
                    applyRecommendedDurationIfNeeded()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .bold))
                Text("Change Today")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func trainingDayBody(
        day: SplitDayConfig,
        targets: [MuscleGroup: Double],
        groups: [MuscleTrainingGroup],
        selectedDuration: Int,
        recommendedDuration: Int
    ) -> some View {
        let plannedWorkSets = estimatedWorkoutSetCount(
            for: day,
            durationMinutes: selectedDuration
        )
        let weeklyProgress = weeklyProgress(for: targets)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("\(selectedDuration)m today")
                Text("•")
                Text("\(plannedWorkSets) work sets")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.78))

            VStack(alignment: .leading, spacing: 9) {
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
                    ForEach(groups, id: \.self) { group in
                        focusTargetTile(
                            group: group,
                            targetSets: targetSets(for: group, in: targets)
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weekly Pace")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(formatSets(weeklyProgress.completed)) / \(formatSets(weeklyProgress.target))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }

                GeometryReader { geo in
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.spaceGlow)
                                .frame(width: max(8, geo.size.width * weeklyProgress.ratio), height: 8)
                        }
                }
                .frame(height: 8)
            }

            durationCard(recommendedDuration: recommendedDuration)
        }
    }

    private func restDayBody() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recover today and come back stronger.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))

            Text(nextTrainingCopy())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.spaceGlow)

            HStack(spacing: 8) {
                recoveryChip(systemName: "moon.stars.fill", label: "Sleep")
                recoveryChip(systemName: "figure.walk", label: "Walk")
                recoveryChip(systemName: "figure.flexibility", label: "Mobility")
                recoveryChip(systemName: "drop.fill", label: "Hydrate")
            }

            HStack(spacing: 10) {
                Text("Keep Rest")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(10)

                Button {
                    withAnimation(Motion.quick) {
                        _ = planStore.skipRestTodayAndShiftCycle()
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
                    autoDurationNote = nil
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
                    autoDurationNote = nil
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
                        autoDurationNote = nil
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

            if let note = durationRecommendationText(recommendedDuration: recommendedDuration) {
                Text(note)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.68))
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

    private func focusTargetTile(group: MuscleTrainingGroup, targetSets: Double) -> some View {
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
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(formatSets(targetSets))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.spaceGlow)
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

    private func targetSets(for group: MuscleTrainingGroup, in targets: [MuscleGroup: Double]) -> Double {
        targets.reduce(0) { partial, entry in
            partial + (entry.key.trainingGroup == group ? entry.value : 0)
        }
    }

    private func weeklyProgress(for targets: [MuscleGroup: Double]) -> (completed: Double, target: Double, ratio: CGFloat) {
        let targetTotal = targets.keys.reduce(0.0) { partial, muscle in
            partial + (planStore.plan.weeklyTargets[muscle] ?? TrainingTargets.advancedWeeklySets)
        }
        let completedTotal = targets.keys.reduce(0.0) { partial, muscle in
            partial + (planStore.weeklyCompletedSets[muscle] ?? 0)
        }
        let ratio: CGFloat
        if targetTotal > 0 {
            ratio = CGFloat(min(max(completedTotal / targetTotal, 0), 1))
        } else {
            ratio = 0
        }
        return (completedTotal, targetTotal, ratio)
    }

    private func nextTrainingCopy() -> String {
        let calendar = Calendar.current
        let today = Date()

        for offset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let day = planStore.dayConfig(for: date)
            guard !day.isRest else { continue }

            if offset == 1 {
                return "Next: \(day.dayType.rawValue) tomorrow."
            }
            return "Next: \(day.dayType.rawValue) in \(offset) days."
        }

        return "Next training day is open."
    }

    private func estimatedWorkoutSetCount(
        for day: SplitDayConfig,
        durationMinutes: Int
    ) -> Int {
        guard !day.isRest else { return 0 }

        let warmup = day.dayType == .legs || day.dayType == .lower ? 8.0 : 6.0
        let activeMinutes = max(0, Double(durationMinutes) - warmup)
        let minutesPerSet = max(estimatedMinutesPerSet(for: day.dayType), 1.8)
        let capacityByTime = Int(floor(activeMinutes / minutesPerSet))
        let minimumUsefulSets = max(day.resolvedMuscles().count, 6)
        return max(minimumUsefulSets, capacityByTime)
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
        let todayDay = planStore.dayConfig(for: today)
        let rawTargets = plannedTargets(for: today)
        let muscles = rawTargets.filter { $0.value > 0 }.map(\.key)
        let focus = automaticFocus(for: today)
        let equipment = automaticEquipment(for: today)

        let duration = max(15, preferredDuration)
        let sessionTargets = previewSessionTargets(
            for: todayDay,
            rawTargets: rawTargets,
            durationMinutes: duration
        )
        let plannedWorkSets = estimatedWorkoutSetCount(
            for: todayDay,
            durationMinutes: duration
        )
        let request = WorkoutRequest(
            duration: duration,
            targetMuscles: muscles,
            equipment: equipment,
            focus: focus,
            preferredExercises: []
        )
        let workout = await generator.generateIntelligentWorkout(request: request)

        if workout.exercises.isEmpty {
            generatedExercises = []
            generatedTargets = sessionTargets
            isGenerating = false
            return
        }

        let allocation = allocateSetsForTargets(
            exercises: workout.exercises,
            targets: sessionTargets,
            minTotalSets: plannedWorkSets,
            maxTotalSets: plannedWorkSets
        )

        generatedExercises = allocation.exercises
        generatedTargets = sessionTargets
        autoDurationNote = buildAutoDurationNote(
            rawTargets: rawTargets,
            sessionTargets: sessionTargets,
            duration: duration
        )

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

    private func greetingTitle() -> String {
        let clean = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return "Today’s Plan"
        }
        let first = clean.split(separator: " ").first.map(String.init) ?? clean
        return "Hi, \(first)"
    }

    private func recommendedWorkoutDurationMinutes(
        for day: SplitDayConfig,
        targets: [MuscleGroup: Double]
    ) -> Int {
        if day.isRest {
            return 0
        }

        let targetCredit = targets.values.reduce(0, +)
        let creditPerSet = estimatedCreditPerSet(for: day.dayType)
        let setsNeeded = max(Double(day.resolvedMuscles().count), targetCredit / max(creditPerSet, 0.75))
        let warmup = day.dayType == .legs || day.dayType == .lower ? 8.0 : 6.0
        let minutesPerSet = estimatedMinutesPerSet(for: day.dayType)
        let rawMinutes = Int((warmup + (setsNeeded * minutesPerSet)).rounded())
        let clamped = min(60, max(45, rawMinutes))
        let rounded = Int((Double(clamped) / 5.0).rounded() * 5.0)
        return min(60, max(45, rounded))
    }

    private func applyRecommendedDurationIfNeeded() {
        let day = planStore.dayConfig()
        guard !day.isRest else { return }
        guard !durationUserOverride else { return }
        preferredDuration = recommendedWorkoutDurationMinutes(
            for: day,
            targets: plannedTargets(for: Date())
        )
    }

    private func previewSessionTargets(
        for day: SplitDayConfig,
        rawTargets: [MuscleGroup: Double],
        durationMinutes: Int
    ) -> [MuscleGroup: Double] {
        guard !day.isRest else { return [:] }
        guard !rawTargets.isEmpty else { return [:] }

        let warmup = day.dayType == .legs || day.dayType == .lower ? 8.0 : 6.0
        let activeMinutes = max(0, Double(durationMinutes) - warmup)
        let minutesPerSet = max(estimatedMinutesPerSet(for: day.dayType), 1.8)
        let capacityByTime = Int(floor(activeMinutes / minutesPerSet))
        let minimumUsefulSets = max(day.resolvedMuscles().count, 6)
        let setCapacity = max(minimumUsefulSets, capacityByTime)

        let targetCredit = rawTargets.values.reduce(0, +)
        guard targetCredit > 0 else { return rawTargets }

        let creditPerSet = estimatedCreditPerSet(for: day.dayType)
        let achievableCredit = Double(setCapacity) * max(creditPerSet, 0.8)
        guard achievableCredit + 0.01 < targetCredit else {
            return rawTargets.filter { $0.value > 0 }
        }

        let scale = max(0.35, achievableCredit / targetCredit)
        return scaledTargets(rawTargets, scale: scale)
    }

    private func scaledTargets(
        _ rawTargets: [MuscleGroup: Double],
        scale: Double
    ) -> [MuscleGroup: Double] {
        guard scale < 0.999 else {
            return rawTargets.filter { $0.value > 0 }
        }

        var scaled: [MuscleGroup: Double] = [:]
        for (muscle, target) in rawTargets where target > 0 {
            let rawValue = target * scale
            let roundedHalfStep = (rawValue * 2).rounded() / 2
            let minimum: Double = (target >= 2 && scale >= 0.4) ? 0.5 : 0
            let value = max(minimum, roundedHalfStep)
            if value > 0 {
                scaled[muscle] = value
            }
        }
        return scaled
    }

    private func buildAutoDurationNote(
        rawTargets: [MuscleGroup: Double],
        sessionTargets: [MuscleGroup: Double],
        duration: Int
    ) -> String {
        let rawTotal = rawTargets.values.reduce(0, +)
        let sessionTotal = sessionTargets.values.reduce(0, +)
        if sessionTotal + 0.5 < rawTotal {
            return "Auto balanced today to \(formatSets(sessionTotal)) focus sets in \(duration)m."
        }
        return "Today fits your weekly pace in \(duration)m."
    }

    private func durationRecommendationText(recommendedDuration: Int) -> String? {
        if durationUserOverride, recommendedDuration != preferredDuration {
            return "Auto suggests \(recommendedDuration)m to stay on weekly pace."
        }
        return autoDurationNote
    }

    private func estimatedMinutesPerSet(for dayType: DayType) -> Double {
        switch dayType {
        case .legs, .lower:
            return 2.9
        case .full:
            return 2.8
        case .push, .pull, .upper:
            return 2.7
        case .rest:
            return 0
        }
    }

    private func estimatedCreditPerSet(for dayType: DayType) -> Double {
        switch dayType {
        case .legs, .lower:
            return 1.1
        case .full:
            return 1.4
        case .push, .pull, .upper:
            return 1.3
        case .rest:
            return 1.0
        }
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
        minTotalSets: Int,
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
            if totalSets >= minTotalSets {
                let currentCoverage = coverageScore(achieved: achieved, targets: targets)
                if currentCoverage >= 0.98 {
                    break
                }
            }

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

            if let bestExerciseId, bestScore > 0 {
                setCounts[bestExerciseId, default: 0] += 1
                totalSets += 1
                applyContribution(
                    for: bestExerciseId,
                    into: &achieved,
                    using: metadata
                )
                continue
            }

            guard totalSets < minTotalSets else { break }

            guard let fallbackExerciseId = fallbackExerciseId(
                selected: selected,
                metadata: metadata,
                setCounts: setCounts,
                targets: targets
            ) else {
                break
            }

            setCounts[fallbackExerciseId, default: 0] += 1
            totalSets += 1
            applyContribution(
                for: fallbackExerciseId,
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

        let coverage = coverageScore(achieved: achieved, targets: targets)

        return (selected, coverage)
    }

    private func recommendedSetBudget(
        exercises: [ExerciseLog],
        targets: [MuscleGroup: Double],
        durationMinutes: Int
    ) -> (min: Int, max: Int) {
        let exerciseCount = max(1, exercises.count)
        let durationMaxSets = max(exerciseCount, Int(floor(Double(durationMinutes) / 3.0)))
        let durationMinSets = max(exerciseCount, Int(floor(Double(durationMinutes) / 5.0)))

        let totalTargetCredit = targets.values.reduce(0, +)
        let averageTargetCreditPerSet = averageTargetCreditPerSet(
            exercises: exercises,
            targets: targets
        )
        let targetDrivenSets = Int(ceil(totalTargetCredit / max(averageTargetCreditPerSet, 0.6)))

        let adaptiveMin = min(durationMaxSets, max(exerciseCount, min(durationMinSets, targetDrivenSets)))
        let adaptiveMax = min(durationMaxSets, max(adaptiveMin, targetDrivenSets + 3))

        return (adaptiveMin, adaptiveMax)
    }

    private func averageTargetCreditPerSet(
        exercises: [ExerciseLog],
        targets: [MuscleGroup: Double]
    ) -> Double {
        guard !exercises.isEmpty else { return 1.0 }
        guard !targets.isEmpty else { return 1.0 }

        let targetMuscles = Set(targets.keys)
        var totalCredit = 0.0
        var count = 0

        for log in exercises {
            guard let exercise = ExerciseDatabase.shared.getExercise(named: log.name) else { continue }
            var credit = 0.0
            for muscle in exercise.primaryMuscles where targetMuscles.contains(muscle) {
                credit += 1.0
            }
            for muscle in exercise.secondaryMuscles where targetMuscles.contains(muscle) {
                credit += TrainingTargets.secondaryMuscleCredit
            }
            if credit > 0 {
                totalCredit += credit
                count += 1
            }
        }

        guard count > 0 else { return 1.0 }
        return totalCredit / Double(count)
    }

    private func fallbackExerciseId(
        selected: [ExerciseLog],
        metadata: [UUID: Exercise],
        setCounts: [UUID: Int],
        targets: [MuscleGroup: Double]
    ) -> UUID? {
        let targetMuscles = Set(targets.keys)
        let candidates = selected.compactMap { log -> (UUID, Double)? in
            guard let exercise = metadata[log.id] else { return nil }
            let currentSets = setCounts[log.id] ?? 0
            guard currentSets < maxSetsPerExercise(for: exercise) else { return nil }

            let primaryHits = exercise.primaryMuscles.filter { targetMuscles.contains($0) }.count
            let secondaryHits = exercise.secondaryMuscles.filter { targetMuscles.contains($0) }.count
            let relevance = Double(primaryHits) + (Double(secondaryHits) * TrainingTargets.secondaryMuscleCredit)
            guard relevance > 0 else { return nil }

            let compoundBonus = exercise.isCompound ? 0.4 : 0
            let fatiguePenalty = Double(currentSets) * 0.25
            let score = relevance + compoundBonus - fatiguePenalty
            return (log.id, score)
        }

        return candidates.max(by: { $0.1 < $1.1 })?.0
    }

    private func coverageScore(
        achieved: [MuscleGroup: Double],
        targets: [MuscleGroup: Double]
    ) -> Double {
        var ratioSum = 0.0
        var ratioCount = 0
        for (muscle, target) in targets {
            guard target > 0 else { continue }
            ratioSum += min((achieved[muscle] ?? 0) / target, 1.0)
            ratioCount += 1
        }
        return ratioCount > 0 ? ratioSum / Double(ratioCount) : 1.0
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
