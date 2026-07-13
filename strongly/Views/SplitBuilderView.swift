import SwiftUI

struct SplitBuilderView: View {
    @EnvironmentObject private var store: SplitPlanStore
    @ObservedObject private var unitStore = UnitSettingsStore.shared
    @State private var customizeTargets = false
    @State private var editingDay: SplitDayConfig?

    var body: some View {
        NavigationStack {
            ZStack {
                StarfieldBackground()

                ScrollView {
                    VStack(spacing: PremiumLayout.sectionSpacing) {
                        settingsPrincipleCard
                        planOverview
                        planControls
                        targetSection
                        scheduleSection
                    }
                    .padding(.horizontal, Layout.screenHorizontal)
                    .padding(.vertical, Space.l)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $editingDay) { day in
                DayTargetEditorView(
                    day: day,
                    onSave: { updated in
                        store.updateDayFromBuilder(updated)
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var planOverview: some View {
        HStack(spacing: 10) {
            overviewChip(
                title: "Days",
                value: "\(store.plan.trainingDays)"
            )
            overviewChip(
                title: "Split",
                value: store.plan.splitType.shortLabel
            )
            overviewChip(
                title: "Units",
                value: unitStore.unit == .lb ? "LB" : "KG"
            )
        }
        .premiumSectionCard(cornerRadius: 22)
    }

    private var settingsPrincipleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLead(
                title: "Set it. Repeat it.",
                subtitle: "This is where constraints live. Your day-to-day work stays on Today."
            )

            Text("Change the plan when your schedule, equipment, or recovery changes.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .premiumSectionCard(cornerRadius: 22)
    }

    private func overviewChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.58))
                .tracking(0.8)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var planControls: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLead(
                title: "Training Constraints",
                subtitle: "Pick the week you can actually repeat."
            )

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Training Rhythm")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 10) {
                    ForEach([4, 5, 6], id: \.self) { days in
                        Button {
                            store.applyTemplate(trainingDays: days, splitType: store.plan.splitType)
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(days)")
                                    .font(.system(size: 18, weight: .bold))
                                Text("days")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(store.plan.trainingDays == days ? Color.black.opacity(0.48) : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(store.plan.trainingDays == days ? 0.28 : 0.16), lineWidth: 1)
                                    if store.plan.trainingDays == days {
                                        AnimatedRainbowStroke(cornerRadius: 14, lineWidth: 1.4)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Simple Split")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                let recommended = recommendedSplitType(for: store.plan.trainingDays)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(SplitType.allCases, id: \.self) { split in
                        Button {
                            store.applyTemplate(trainingDays: store.plan.trainingDays, splitType: split)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: splitIcon(for: split))
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(split.shortLabel)
                                        .font(.system(size: 13, weight: .bold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                }
                                .foregroundColor(.white)

                                Text(splitDescription(for: split))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(store.plan.splitType == split ? .white.opacity(0.86) : .white.opacity(0.66))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Text("Recommended")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(split == recommended ? .white : .white.opacity(0.58))
                                    .opacity(split == recommended ? 1 : 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 106, alignment: .topLeading)
                            .padding(12)
                            .background(store.plan.splitType == split ? Color.black.opacity(0.48) : Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(store.plan.splitType == split ? 0.26 : 0.14), lineWidth: 1)
                                    if store.plan.splitType == split {
                                        AnimatedRainbowStroke(cornerRadius: 14, lineWidth: 1.4)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Units")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 10) {
                    unitOptionButton(label: "lb", unit: .lb)
                    unitOptionButton(label: "kg", unit: .kg)
                }
            }
        }
        .premiumSectionCard()
    }

    private func unitOptionButton(label: String, unit: WeightUnit) -> some View {
        Button {
            unitStore.unit = unit
        } label: {
            Text(label.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(unitStore.unit == unit ? Color.black.opacity(0.48) : Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(unitStore.unit == unit ? 0.26 : 0.15), lineWidth: 1)
                        if unitStore.unit == unit {
                            AnimatedRainbowStroke(cornerRadius: 12, lineWidth: 1.4)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLead(
                title: "Enough Weekly Work",
                subtitle: "Default targets work for the plan. Adjust them when your recovery or schedule calls for it."
            )

            HStack {
                Spacer()

                Button(customizeTargets ? "Done" : "Customize") {
                    withAnimation(Motion.quick) {
                        customizeTargets.toggle()
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

                if customizeTargets {
                    Button("Reset") {
                        store.resetTargets()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                }
            }

            Text("Default: \(Int(TrainingTargets.advancedWeeklySets)) hard sets per muscle / week")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.58))

            if customizeTargets {
                VStack(spacing: Space.s) {
                    ForEach(MuscleTrainingGroup.allCases, id: \.self) { group in
                        HStack {
                            Text(group.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))

                            Spacer()

                            Stepper(
                                value: Binding(
                                    get: { Int(weeklyTarget(for: group)) },
                                    set: { newValue in
                                        setWeeklyTarget(for: group, value: Double(newValue))
                                    }
                                ),
                                in: 10...30
                            ) {
                                Text("\(Int(weeklyTarget(for: group)))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: 120)
                        }
                    }
                }
            }
        }
        .premiumSectionCard()
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLead(
                title: "Weekly Repeat",
                subtitle: "Keep the week stable unless life gets in the way."
            )

            VStack(spacing: Space.s) {
                ForEach(Array(store.plan.days.enumerated()), id: \.element.id) { index, _ in
                    let date = dateForCurrentWeek(dayIndex: index)
                    let day = store.dayConfig(for: date)
                    Button {
                        editingDay = day
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(weekDayLabel(for: day.dayIndex))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)

                                DayTypeBadge(dayType: day.dayType)
                            }

                            Spacer()

                            if day.isRest {
                                Text("Rest")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            } else {
                                dayGroupIcons(for: day)
                                    .frame(maxWidth: 220, alignment: .trailing)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(Space.m)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .premiumSectionCard()
    }

    private func weekDayLabel(for index: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let mondayFirstIndex = (index + 1) % 7
        return symbols[mondayFirstIndex]
    }

    private func dateForCurrentWeek(dayIndex: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
        return calendar.date(byAdding: .day, value: dayIndex, to: monday) ?? startOfDay
    }

    private func recommendedSplitType(for _: Int) -> SplitType {
        .upperLower
    }

    private func weeklyTarget(for group: MuscleTrainingGroup) -> Double {
        let values = group.muscles.compactMap { store.plan.weeklyTargets[$0] }
        guard !values.isEmpty else { return TrainingTargets.advancedWeeklySets }
        return values.reduce(0, +) / Double(values.count)
    }

    private func setWeeklyTarget(for group: MuscleTrainingGroup, value: Double) {
        for muscle in group.muscles {
            store.plan.weeklyTargets[muscle] = value
        }
    }

    private func dayGroupIcons(for day: SplitDayConfig) -> some View {
        let dayGroups = Set(day.resolvedMuscles().map { $0.trainingGroup })
        let ordered = MuscleTrainingGroup.allCases.filter { dayGroups.contains($0) }
        var visible = Array(ordered.prefix(5))
        if ordered.contains(.abs), !visible.contains(.abs), !visible.isEmpty {
            visible[visible.count - 1] = .abs
        }
        let overflow = max(0, ordered.count - visible.count)

        return HStack(spacing: 8) {
            ForEach(visible, id: \.self) { group in
                groupIcon(for: group)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    private func groupIcon(for group: MuscleTrainingGroup) -> some View {
        ZStack {
            Circle()
                .fill(Color.spaceGlow.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.spaceGlow.opacity(0.45), lineWidth: 1)
                )

            TrainingGroupIcon(group: group)
                .frame(width: 14, height: 14)
        }
    }

    private func splitIcon(for split: SplitType) -> String {
        switch split {
        case .pushPullLegs:
            return "figure.strengthtraining.traditional"
        case .upperLower:
            return "figure.walk.motion"
        case .fullBody:
            return "figure.mixed.cardio"
        case .hybrid:
            return "arrow.triangle.branch"
        }
    }

    private func splitDescription(for split: SplitType) -> String {
        switch split {
        case .pushPullLegs:
            return "Clear push, pull, legs rhythm"
        case .upperLower:
            return "Simple, repeatable rotation"
        case .fullBody:
            return "Whole body, fewer decisions"
        case .hybrid:
            return "Useful for uneven weeks"
        }
    }

}

private extension SplitType {
    var shortLabel: String {
        switch self {
        case .pushPullLegs:
            return "PPL"
        case .upperLower:
            return "U/L"
        case .fullBody:
            return "Full Body"
        case .hybrid:
            return "Hybrid"
        }
    }
}

struct DayTargetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workingDay: SplitDayConfig

    let onSave: (SplitDayConfig) -> Void

    init(day: SplitDayConfig, onSave: @escaping (SplitDayConfig) -> Void) {
        self._workingDay = State(initialValue: day)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            List {
                Section("Day Type") {
                    Picker("Day Type", selection: $workingDay.dayType) {
                        ForEach(DayType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                            }
                        }
                        .onChange(of: workingDay.dayType) {
                            workingDay.customMuscles = nil
                        }
                    }

                if workingDay.dayType != .rest {
                    Button("Use default muscles for this day type") {
                        workingDay.customMuscles = nil
                    }
                    .foregroundColor(.textSecondary)

                    Section("Target Muscles") {
                        ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                            Toggle(isOn: Binding(
                                get: { workingDay.resolvedMuscles().contains(muscle) },
                                set: { isOn in
                                    var current = Set(workingDay.resolvedMuscles())
                                    if isOn {
                                        current.insert(muscle)
                                    } else {
                                        current.remove(muscle)
                                    }
                                    workingDay.customMuscles = Array(current).sorted { $0.displayName < $1.displayName }
                                }
                            )) {
                                MuscleBadge(muscle: muscle, compact: true)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Day")
            .scrollContentBackground(.hidden)
            .background(StarfieldBackground())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(workingDay)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SplitBuilderView()
        .environmentObject(SplitPlanStore())
}
