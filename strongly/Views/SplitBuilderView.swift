import SwiftUI

struct SplitBuilderView: View {
    @EnvironmentObject private var store: SplitPlanStore
    @ObservedObject private var unitStore = UnitSettingsStore.shared
    @State private var customizeTargets = false
    @State private var editingDay: SplitDayConfig?

    var body: some View {
        NavigationView {
            ZStack {
                StarfieldBackground()

                ScrollView {
                    VStack(spacing: Space.l) {
                        planControls
                        targetSection
                        scheduleSection
                    }
                    .padding(Space.l)
                }
            }
            .navigationTitle("Split Builder")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $editingDay) { day in
                DayTargetEditorView(
                    day: day,
                    onSave: { updated in
                        if let index = store.plan.days.firstIndex(where: { $0.id == updated.id }) {
                            store.plan.days[index] = updated
                        }
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var planControls: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Plan Setup")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Set your split once. Training adapts automatically day-to-day.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.65))

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Training Days")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 10) {
                    ForEach([4, 5, 6], id: \.self) { days in
                        Button {
                            store.applyTemplate(trainingDays: days, splitType: store.plan.splitType)
                        } label: {
                            Text("\(days) days")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(store.plan.trainingDays == days ? .spaceNavy : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(store.plan.trainingDays == days ? Color.spaceGlow : Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            store.plan.trainingDays == days ? Color.spaceGlow.opacity(0.9) : Color.white.opacity(0.15),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Split Type")
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
                                        .minimumScaleFactor(0.85)
                                }
                                .foregroundColor(store.plan.splitType == split ? .spaceNavy : .white)

                                Text(splitDescription(for: split))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(store.plan.splitType == split ? .spaceNavy.opacity(0.85) : .white.opacity(0.66))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Text("Best for most beginners")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(store.plan.splitType == split ? .spaceNavy.opacity(0.9) : .spaceGlow)
                                    .opacity(split == recommended ? 1 : 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 90, alignment: .topLeading)
                            .padding(10)
                            .background(store.plan.splitType == split ? Color.spaceGlow : Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        store.plan.splitType == split ? Color.spaceGlow.opacity(0.9) : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
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
        .padding(Space.l)
        .themedCard()
    }

    private func unitOptionButton(label: String, unit: WeightUnit) -> some View {
        Button {
            unitStore.unit = unit
        } label: {
            Text(label.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(unitStore.unit == unit ? .spaceNavy : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(unitStore.unit == unit ? Color.spaceGlow : Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            unitStore.unit == unit ? Color.spaceGlow.opacity(0.9) : Color.white.opacity(0.15),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Text("Weekly Targets")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

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

            Text("Default is \(Int(TrainingTargets.advancedWeeklySets)) sets per muscle group per week.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))

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
        .padding(Space.l)
        .themedCard()
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Weekly Schedule")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: Space.s) {
                ForEach(store.plan.days) { day in
                    Button {
                        if !day.isRest {
                            editingDay = day
                        }
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
                                    .frame(maxWidth: 200, alignment: .trailing)
                            }

                            if !day.isRest {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(Space.m)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Space.l)
        .themedCard()
    }

    private func weekDayLabel(for index: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let mondayFirstIndex = (index + 1) % 7
        return symbols[mondayFirstIndex]
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
                .fill(groupColor(for: group).opacity(0.25))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(groupColor(for: group).opacity(0.55), lineWidth: 1)
                )

            if group == .abs {
                sixPackGlyph
                    .frame(width: 12, height: 16)
            } else {
                Image(systemName: groupSymbol(for: group))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(groupColor(for: group))
            }
        }
    }

    private var sixPackGlyph: some View {
        VStack(spacing: 1.5) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 1.5) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.spaceNavy.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(groupColor(for: .abs), lineWidth: 0.8)
                        )
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.spaceNavy.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(groupColor(for: .abs), lineWidth: 0.8)
                        )
                }
            }
        }
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
            return "Focused muscle distribution"
        case .upperLower:
            return "Simple high-frequency rotation"
        case .fullBody:
            return "Whole-body each training day"
        case .hybrid:
            return "Blend of PPL and upper/lower"
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
