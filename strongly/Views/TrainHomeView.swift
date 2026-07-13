import SwiftUI

struct TrainHomeView: View {
    @Binding var tabSelection: Int
    @AppStorage("user_name") private var userName = ""
    @AppStorage("strongly_product_onboarding_complete") private var onboardingComplete = false
    @AppStorage("preferred_workout_duration_minutes") private var preferredDuration = 45
    @AppStorage("preferred_workout_duration_user_override") private var durationUserOverride = false
    @State private var isGenerating = false
    @State private var generatedExercises: [ExerciseLog] = []
    @State private var generatedTargets: [MuscleGroup: Double] = [:]
    @State private var generatedSetBudget = 0
    @State private var showWorkout = false
    @State private var draftName = ""
    @State private var showNameCapture = false
    @State private var autoDurationNote: String?
    @State private var generationErrorMessage: String?
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
                targetOverrides: generatedTargets,
                setBudgetOverride: generatedSetBudget
            )
        }
        .sheet(isPresented: $showNameCapture) {
            NameCaptureSheet(
                draftName: $draftName,
                initialTrainingDays: planStore.plan.trainingDays,
                initialUnit: UnitSettingsStore.shared.unit,
                onContinue: { enteredName, trainingDays, unit in
                    let clean = enteredName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    userName = clean
                    UnitSettingsStore.shared.unit = unit
                    planStore.applyTemplate(trainingDays: trainingDays, splitType: defaultSplitType(for: trainingDays))
                    durationUserOverride = false
                    onboardingComplete = true
                    applyRecommendedDurationIfNeeded()
                    showNameCapture = false
                }
            )
        }
        .alert("Unable to Build Workout", isPresented: Binding(
            get: { generationErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    generationErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                generationErrorMessage = nil
            }
        } message: {
            Text(generationErrorMessage ?? "Please try again.")
        }
        .onAppear {
            let clean = userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty || !onboardingComplete {
                draftName = clean
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
            VStack(spacing: PremiumLayout.sectionSpacing) {
                topHero
                planCard
                gymProfileCard
            }
            .padding(.horizontal, Layout.screenHorizontal)
            .padding(.top, 14)
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            if !planStore.dayConfig().isRest {
                startWorkoutBar
            }
        }
    }

    private var startWorkoutBar: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await generateWorkout()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Do Today's Work")
                        .font(.system(size: 18, weight: .semibold))
                }
                .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.spacePanelInner)
                    .cornerRadius(18)
                    .overlay(
                        AnimatedRainbowStroke(cornerRadius: 18, lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.24), radius: 12, y: 7)
            }
            .padding(.horizontal, Layout.screenHorizontal)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.spaceAbyss.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var topHero: some View {
        let day = planStore.dayConfig()
        let rawTargets = plannedTargets(for: Date())
        let duration = durationPlan(for: day, targets: rawTargets).selected
        let workSets = planStore.plannedSetBudget(for: day, targets: rawTargets, durationMinutes: duration)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(greetingTitle())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white.opacity(0.62))

                    Text(day.isRest ? "Recover today." : "Do \(day.dayType.rawValue).")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(day.isRest ? "Come back ready for the next session." : "Finish enough hard sets. Beat last time where you can.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 64, height: 64)
                    Image("StronglyIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                }
            }

            HStack(spacing: 8) {
                DayTypeBadge(dayType: day.dayType)
                commandMetric(title: day.isRest ? "Next" : "Sets", value: day.isRest ? nextTrainingShortCopy() : "\(workSets)")
                commandMetric(title: "Time", value: day.isRest ? "Recover" : "\(duration)m")
            }
        }
        .premiumSectionCard(cornerRadius: 26)
    }

    private var gymProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLead(
                title: "Your gym",
                subtitle: "Free weights, Smith/barbell, cables, machines, pull-ups."
            )

            HStack(spacing: 8) {
                principleChip(icon: "dumbbell.fill", text: "Weights")
                principleChip(icon: "point.3.connected.trianglepath.dotted", text: "Cables")
                principleChip(icon: "figure.strengthtraining.traditional", text: "Machines")
                principleChip(icon: "figure.strengthtraining.traditional", text: "Pull-ups")
            }
        }
        .premiumSectionCard(cornerRadius: 22)
    }

    private func commandMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.56))
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func principleChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundColor(.white.opacity(0.84))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var planCard: some View {
        let day = planStore.dayConfig()
        let rawTargets = plannedTargets(for: Date())
        let orderedGroups = orderedTrainingGroups(for: day)
        let durationPlan = durationPlan(for: day, targets: rawTargets)
        let previewTargets = rawTargets
        let displayGroups = orderedGroups.filter { targetSets(for: $0, in: previewTargets) > 0 }

        return VStack(alignment: .leading, spacing: 18) {
            trainCardHeader(day: day)

            if day.isRest || previewTargets.isEmpty {
                restDayBody()
            } else {
                trainingDayBody(
                    day: day,
                    targets: previewTargets,
                    groups: displayGroups,
                    selectedDuration: durationPlan.selected,
                    recommendedDuration: durationPlan.recommended
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: day.isRest ? 260 : 350, alignment: .topLeading)
        .premiumSectionCard(cornerRadius: 24)
    }

    private func trainCardHeader(day: SplitDayConfig) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Minimum effective work")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.58))
                DayTypeBadge(dayType: day.dayType)
                Text(day.isRest ? "Rest Day" : "Finish this. Repeat next time.")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                changeTodayMenu
            }
        }
    }

    private var changeTodayMenu: some View {
        Menu {
            if planStore.hasAgendaOverrideForToday() {
                Button("Back to Plan") {
                    planStore.resetAgendaForTodayToPlan()
                    applyRecommendedDurationIfNeeded()
                }
            }

            Button("Rest") {
                planStore.setAgendaForToday(.rest)
            }

            Divider()

            Button("Push") {
                planStore.setAgendaForToday(.push)
                applyRecommendedDurationIfNeeded()
            }
            Button("Pull") {
                planStore.setAgendaForToday(.pull)
                applyRecommendedDurationIfNeeded()
            }
            Button("Legs") {
                planStore.setAgendaForToday(.legs)
                applyRecommendedDurationIfNeeded()
            }
            Button("Upper") {
                planStore.setAgendaForToday(.upper)
                applyRecommendedDurationIfNeeded()
            }
            Button("Lower") {
                planStore.setAgendaForToday(.lower)
                applyRecommendedDurationIfNeeded()
            }
            Button("Full Body") {
                planStore.setAgendaForToday(.full)
                applyRecommendedDurationIfNeeded()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .bold))
                Text("Edit")
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
        let requiredWorkSets = planStore.requiredSetBudget(for: day, targets: targets)
        let plannedWorkSets = planStore.plannedSetBudget(
            for: day,
            targets: targets,
            durationMinutes: selectedDuration
        )
        let recommendedPlannedSets = planStore.plannedSetBudget(
            for: day,
            targets: targets,
            durationMinutes: recommendedDuration
        )
        let weeklyProgress = weeklyProgress(for: targets)

        return VStack(alignment: .leading, spacing: 16) {
            sessionPlanMetricsRow(
                requiredSets: requiredWorkSets,
                plannedSets: plannedWorkSets,
                selectedDuration: selectedDuration
            )

            VStack(alignment: .leading, spacing: 9) {
                Text("Muscles to cover")
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
                    Text("Weekly basics")
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
                                .fill(Color.clear)
                                .overlay {
                                    AnimatedRainbowRail(height: 8)
                                }
                                .clipShape(Capsule())
                                .frame(width: max(8, geo.size.width * weeklyProgress.ratio), height: 8)
                        }
                }
                .frame(height: 8)
            }

            durationCard(
                selectedDuration: selectedDuration,
                recommendedDuration: recommendedDuration,
                requiredWorkSets: requiredWorkSets,
                plannedWorkSets: plannedWorkSets,
                recommendedPlannedSets: recommendedPlannedSets
            )
        }
        .padding(.top, 2)
    }

    private func sessionPlanMetricsRow(
        requiredSets: Int,
        plannedSets: Int,
        selectedDuration: Int
    ) -> some View {
        HStack(spacing: 8) {
            sessionMetricChip(title: "Target", value: "\(requiredSets)")
            sessionMetricChip(title: "Sets", value: "\(plannedSets)")
            sessionMetricChip(title: "Time", value: "\(selectedDuration)m")
        }
    }

    private func sessionMetricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.56))
                .tracking(0.8)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func restDayBody() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery Day")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text("Recovery is part of the plan. Let today make the next session better.")
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
                    Text("Keep Recovery")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())

                Button {
                    withAnimation(Motion.quick) {
                        _ = planStore.skipRestTodayAndShiftCycle()
                    }
                } label: {
                    Text("Train Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            AnimatedRainbowStroke(cornerRadius: 999, lineWidth: 1.2)
                        )
                }
                .disabled(!planStore.canSkipRestToday())
                .opacity(planStore.canSkipRestToday() ? 1 : 0.5)
            }
        }
    }

    private func durationCard(
        selectedDuration: Int,
        recommendedDuration: Int,
        requiredWorkSets: Int,
        plannedWorkSets: Int,
        recommendedPlannedSets: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Time Box")
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
                    preferredDuration = max(30, preferredDuration - 5)
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
                        .fixedSize(horizontal: true, vertical: false)
                        .overlay(
                            Capsule()
                                .stroke(Color.spaceGlow.opacity(0.45), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if let note = durationRecommendationText(
                selectedDuration: selectedDuration,
                recommendedDuration: recommendedDuration,
                requiredWorkSets: requiredWorkSets,
                plannedWorkSets: plannedWorkSets,
                recommendedPlannedSets: recommendedPlannedSets
            ) {
                Text(note)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.68))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.56))
                .tracking(0.8)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    private func focusTargetTile(group: MuscleTrainingGroup, targetSets: Double) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.spaceGlow.opacity(0.2))
                    .frame(width: 26, height: 26)
                TrainingGroupIcon(group: group, compact: true)
                    .frame(width: 12, height: 12)
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

    private func nextTrainingShortCopy() -> String {
        let calendar = Calendar.current
        let today = Date()

        for offset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let day = planStore.dayConfig(for: date)
            guard !day.isRest else { continue }
            return offset == 1 ? "\(day.dayType.rawValue) tomorrow" : "\(day.dayType.rawValue) in \(offset)d"
        }

        return "Open"
    }

    private func enforceQuotaCoverage(
        exercises: [ExerciseLog],
        targets: [MuscleGroup: Double],
        equipment: EquipmentType,
        maxTotalSets: Int
    ) -> [ExerciseLog] {
        guard !targets.isEmpty else { return exercises }
        guard maxTotalSets > 0 else { return exercises }
        var adjusted = exercises
        var safety = 0

        while safety < 160 {
            let totalSets = totalPlannedSets(in: adjusted)
            if totalSets >= maxTotalSets {
                break
            }
            let achieved = MuscleTracker.setCredits(for: adjusted, completedOnly: false)
            let deficits = MuscleTracker.deficits(required: targets, achieved: achieved)
            guard let mostUnderTarget = deficits.max(by: { $0.value < $1.value }) else { break }
            let muscle = mostUnderTarget.key

            if let index = adjusted.firstIndex(where: { log in
                guard let metadata = ExerciseDatabase.shared.getExercise(named: log.name) else { return false }
                return metadata.primaryMuscles.contains(muscle) || metadata.secondaryMuscles.contains(muscle)
            }) {
                if let metadata = ExerciseDatabase.shared.getExercise(named: adjusted[index].name),
                   adjusted[index].sets.count >= maxSetsPerExercise(for: metadata),
                   let fallback = fallbackExercise(for: muscle, equipment: equipment, allowedEquipment: userGymEquipment) {
                    let reps = prescribedReps(for: fallback, seedReps: 10)
                    let weight = prescribedWeight(for: fallback, seedWeight: 0)
                    adjusted.append(
                        ExerciseLog(
                            name: fallback.name,
                            sets: [ExerciseSet(weight: weight, reps: reps, completed: false)],
                            notes: ""
                        )
                    )
                    safety += 1
                    continue
                }
                let seed = adjusted[index].sets.last ?? ExerciseSet(weight: 0, reps: 10, completed: false)
                adjusted[index].sets.append(
                    ExerciseSet(weight: seed.weight, reps: seed.reps, completed: false)
                )
            } else if let fallback = fallbackExercise(for: muscle, equipment: equipment, allowedEquipment: userGymEquipment),
                      totalSets < maxTotalSets {
                let reps = prescribedReps(for: fallback, seedReps: 10)
                let weight = prescribedWeight(for: fallback, seedWeight: 0)
                adjusted.append(
                    ExerciseLog(
                        name: fallback.name,
                        sets: [ExerciseSet(weight: weight, reps: reps, completed: false)],
                        notes: ""
                    )
                )
            } else {
                break
            }

            safety += 1
        }

        return adjusted
    }

    private func totalPlannedSets(in exercises: [ExerciseLog]) -> Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func fallbackExercise(
        for muscle: MuscleGroup,
        equipment: EquipmentType,
        allowedEquipment: Set<Equipment>
    ) -> Exercise? {
        ExerciseDatabase.shared.exercises.first { exercise in
            guard exercise.isProgressiveHypertrophyCandidate else { return false }
            guard allowedEquipment.contains(exercise.equipment) else { return false }
            let equipmentMatch: Bool = {
                switch equipment {
                case .both:
                    return true
                case .bodyweight:
                    return exercise.equipment == .bodyweight || exercise.equipment == .band
                case .gym:
                    return exercise.equipment != .bodyweight && exercise.equipment != .band
                }
            }()
            guard equipmentMatch else { return false }
            return exercise.primaryMuscles.contains(muscle) || exercise.secondaryMuscles.contains(muscle)
        }
    }

    private var generatingView: some View {
        VStack(spacing: 32) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Setting up today's work...")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func generateWorkout() async {
        isGenerating = true
        generationErrorMessage = nil

        let generator = WorkoutGenerator.shared
        let today = Date()
        let todayDay = planStore.dayConfig(for: today)
        let rawTargets = plannedTargets(for: today)
        let muscles = rawTargets.filter { $0.value > 0 }.map(\.key)
        let focus = automaticFocus(for: today)
        let equipment = automaticEquipment(for: today)

        let sessionTargets = rawTargets
        let durationPlan = durationPlan(for: todayDay, targets: sessionTargets)
        let selectedDuration = durationPlan.selected
        if !durationUserOverride {
            preferredDuration = selectedDuration
        }

        let requiredWorkSets = planStore.requiredSetBudget(for: todayDay, targets: sessionTargets)
        let plannedWorkSets = planStore.plannedSetBudget(
            for: todayDay,
            targets: sessionTargets,
            durationMinutes: selectedDuration
        )
        let request = WorkoutRequest(
            duration: selectedDuration,
            targetMuscles: muscles,
            equipment: equipment,
            allowedEquipment: userGymEquipment,
            focus: focus,
            preferredExercises: []
        )
        let workout = await generator.generateIntelligentWorkout(request: request)

        if workout.exercises.isEmpty {
            generatedExercises = []
            generatedTargets = sessionTargets
            generatedSetBudget = plannedWorkSets
            generationErrorMessage = "Today’s work needs an exercise match. Add exercises or keep the plan simple."
            isGenerating = false
            return
        }

        let allocation = allocateSetsForTargets(
            exercises: workout.exercises,
            targets: sessionTargets,
            minTotalSets: requiredWorkSets,
            maxTotalSets: plannedWorkSets
        )

        var candidateExercises = enforceQuotaCoverage(
            exercises: allocation.exercises,
            targets: sessionTargets,
            equipment: equipment,
            maxTotalSets: plannedWorkSets
        )
        candidateExercises = rebalanceToExactSetBudget(
            exercises: candidateExercises,
            targets: sessionTargets,
            equipment: equipment,
            desiredTotalSets: plannedWorkSets
        )

        let contract = validateGeneratorContract(
            exercises: candidateExercises,
            requiredTargets: sessionTargets,
            expectedSetBudget: plannedWorkSets
        )
        guard !candidateExercises.isEmpty else {
            generatedExercises = []
            generatedTargets = sessionTargets
            generatedSetBudget = 0
            generationErrorMessage = "Today’s work needs an exercise match. Add exercises or keep the plan simple."
            isGenerating = false
            return
        }

        generatedExercises = candidateExercises
        planStore.recordGeneratedQuotaResult(
            required: sessionTargets,
            planned: contract.plannedCredits,
            context: "train_generate_workout"
        )
        generatedTargets = sessionTargets
        generatedSetBudget = contract.valid ? plannedWorkSets : totalPlannedSets(in: candidateExercises)
        autoDurationNote = buildAutoDurationNote(
            rawTargets: rawTargets,
            sessionTargets: sessionTargets,
            duration: selectedDuration
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

    private func applyRecommendedDurationIfNeeded() {
        let day = planStore.dayConfig()
        guard !day.isRest else { return }
        guard !durationUserOverride else { return }
        preferredDuration = durationPlan(for: day, targets: plannedTargets(for: Date())).recommended
    }

    private func durationPlan(
        for day: SplitDayConfig,
        targets: [MuscleGroup: Double]
    ) -> (recommended: Int, selected: Int) {
        let recommended = planStore.recommendedWorkoutDurationMinutes(for: day, targets: targets)
        let selected = durationUserOverride
            ? preferredDuration
            : recommended
        return (recommended, selected)
    }

    private func buildAutoDurationNote(
        rawTargets: [MuscleGroup: Double],
        sessionTargets: [MuscleGroup: Double],
        duration: Int
    ) -> String {
        let rawTotal = rawTargets.values.reduce(0, +)
        let sessionTotal = sessionTargets.values.reduce(0, +)
        if sessionTotal + 0.5 < rawTotal {
            return "Auto kept today to \(formatSets(sessionTotal)) focused sets in \(duration)m."
        }
        return "Today has enough work in \(duration)m."
    }

    private func durationRecommendationText(
        selectedDuration: Int,
        recommendedDuration: Int,
        requiredWorkSets: Int,
        plannedWorkSets: Int,
        recommendedPlannedSets: Int
    ) -> String? {
        if durationUserOverride {
            let delta = plannedWorkSets - recommendedPlannedSets
            if delta != 0 {
                let prefix = delta > 0 ? "+" : ""
                return "Time override \(selectedDuration)m: \(prefix)\(delta) work sets vs auto."
            }
            return "Time override keeps today at \(max(requiredWorkSets, plannedWorkSets)) sets."
        }
        if selectedDuration != recommendedDuration {
            return "Auto set \(selectedDuration)m for today’s work."
        }
        return autoDurationNote
    }

    private func rebalanceToExactSetBudget(
        exercises: [ExerciseLog],
        targets: [MuscleGroup: Double],
        equipment: EquipmentType,
        desiredTotalSets: Int
    ) -> [ExerciseLog] {
        guard desiredTotalSets > 0 else { return [] }
        var adjusted = exercises
        var safety = 0

        while totalPlannedSets(in: adjusted) < desiredTotalSets, safety < 220 {
            let achieved = MuscleTracker.setCredits(for: adjusted, completedOnly: false)
            let deficits = MuscleTracker.deficits(required: targets, achieved: achieved)
            let targetMuscle = deficits.max(by: { $0.value < $1.value })?.key
                ?? targets.max(by: { $0.value < $1.value })?.key
            guard let targetMuscle else { break }

            if let index = adjusted.firstIndex(where: { log in
                guard let metadata = ExerciseDatabase.shared.getExercise(named: log.name) else { return false }
                return metadata.primaryMuscles.contains(targetMuscle) || metadata.secondaryMuscles.contains(targetMuscle)
            }) {
                let seed = adjusted[index].sets.last ?? ExerciseSet(weight: 0, reps: 10, completed: false)
                adjusted[index].sets.append(ExerciseSet(weight: seed.weight, reps: seed.reps, completed: false))
            } else if let fallback = fallbackExercise(for: targetMuscle, equipment: equipment, allowedEquipment: userGymEquipment) {
                adjusted.append(
                    ExerciseLog(
                        name: fallback.name,
                        sets: [ExerciseSet(
                            weight: prescribedWeight(for: fallback, seedWeight: 0),
                            reps: prescribedReps(for: fallback, seedReps: 10),
                            completed: false
                        )],
                        notes: ""
                    )
                )
            } else {
                break
            }
            safety += 1
        }

        while totalPlannedSets(in: adjusted) > desiredTotalSets, safety < 420 {
            let achieved = MuscleTracker.setCredits(for: adjusted, completedOnly: false)
            let removable = adjusted.indices
                .filter { !adjusted[$0].sets.isEmpty }
                .max { lhs, rhs in
                    let lhsScore = removableSafetyScore(exercise: adjusted[lhs], achieved: achieved, required: targets)
                    let rhsScore = removableSafetyScore(exercise: adjusted[rhs], achieved: achieved, required: targets)
                    return lhsScore < rhsScore
                }
            guard let index = removable else { break }

            adjusted[index].sets.removeLast()
            if adjusted[index].sets.isEmpty {
                adjusted.remove(at: index)
            }
            safety += 1
        }

        return adjusted
    }

    private func removableSafetyScore(
        exercise: ExerciseLog,
        achieved: [MuscleGroup: Double],
        required: [MuscleGroup: Double]
    ) -> Double {
        guard let metadata = ExerciseDatabase.shared.getExercise(named: exercise.name) else {
            return 0
        }
        var score = 0.0
        for muscle in metadata.primaryMuscles {
            score += max(0, (achieved[muscle] ?? 0) - (required[muscle] ?? 0))
        }
        for muscle in metadata.secondaryMuscles {
            score += max(0, (achieved[muscle] ?? 0) - (required[muscle] ?? 0)) * TrainingTargets.secondaryMuscleCredit
        }
        return score
    }

    private func validateGeneratorContract(
        exercises: [ExerciseLog],
        requiredTargets: [MuscleGroup: Double],
        expectedSetBudget: Int
    ) -> (valid: Bool, plannedCredits: [MuscleGroup: Double]) {
        let plannedCredits = MuscleTracker.setCredits(for: exercises, completedOnly: false)
        let deficits = MuscleTracker.deficits(required: requiredTargets, achieved: plannedCredits)
        let setBudgetMatches = totalPlannedSets(in: exercises) == expectedSetBudget
        return (deficits.isEmpty && setBudgetMatches, plannedCredits)
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

    private func automaticFocus(for date: Date) -> WorkoutFocus {
        .strength
    }

    private func automaticEquipment(for date: Date) -> EquipmentType {
        .both
    }

    private var userGymEquipment: Set<Equipment> {
        [.barbell, .dumbbell, .cable, .machine, .bodyweight]
    }

    private func defaultSplitType(for trainingDays: Int) -> SplitType {
        switch trainingDays {
        case 6:
            return .pushPullLegs
        case 5:
            return .hybrid
        default:
            return .upperLower
        }
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
    let initialTrainingDays: Int
    let initialUnit: WeightUnit
    let onContinue: (String, Int, WeightUnit) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var trainingDays: Int
    @State private var unit: WeightUnit
    private let accent = Color.spaceGlow
    private let cleanNameLimit = 28

    init(
        draftName: Binding<String>,
        initialTrainingDays: Int,
        initialUnit: WeightUnit,
        onContinue: @escaping (String, Int, WeightUnit) -> Void
    ) {
        self._draftName = draftName
        self.initialTrainingDays = initialTrainingDays
        self.initialUnit = initialUnit
        self.onContinue = onContinue
        self._trainingDays = State(initialValue: initialTrainingDays)
        self._unit = State(initialValue: initialUnit)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StarfieldBackground().ignoresSafeArea()
                backgroundGlow

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        contractCard
                        nameInputCard
                        setupCard
                        continueButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 26)
                    .padding(.bottom, 22)
                }
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
                    Text("Train steady")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Text("Set the plan once.")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Strongly gives you today's work, the target to beat, and the recovery rhythm. Keep it for 8 weeks.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var contractCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            contractRow(icon: "checkmark.circle.fill", title: "Show up", subtitle: "Today tells you the work.")
            contractRow(icon: "arrow.up.right.circle.fill", title: "Beat last time", subtitle: "Add reps or weight when ready.")
            contractRow(icon: "moon.stars.fill", title: "Recover", subtitle: "Rest is part of the system.")
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func contractRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.64))
            }
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

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Repeatable week")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.65))

                HStack(spacing: 8) {
                    ForEach([4, 5, 6], id: \.self) { days in
                        setupOption(
                            label: "\(days)",
                            caption: "days",
                            selected: trainingDays == days
                        ) {
                            trainingDays = days
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Units")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.65))

                HStack(spacing: 8) {
                    setupOption(label: "LB", caption: "pounds", selected: unit == .lb) {
                        unit = .lb
                    }
                    setupOption(label: "KG", caption: "kilos", selected: unit == .kg) {
                        unit = .kg
                    }
                }
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

    private func setupOption(
        label: String,
        caption: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 16, weight: .bold))
                Text(caption)
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.72)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(selected ? Color.black.opacity(0.48) : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(selected ? 0.26 : 0.13), lineWidth: 1)
                    if selected {
                        AnimatedRainbowStroke(cornerRadius: 13, lineWidth: 1.3)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private var continueButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                Text("Start 8 Weeks")
                    .font(.system(size: 18, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                AnimatedRainbowStroke(cornerRadius: 15, lineWidth: 1.4)
            )
            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
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
        onContinue(clean, trainingDays, unit)
        if !clean.isEmpty {
            dismiss()
        }
    }
}
