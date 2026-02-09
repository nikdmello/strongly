




import SwiftUI

struct SplitBuilderView: View {
    @StateObject private var store = SplitPlanStore()
    @ObservedObject private var unitStore = UnitSettingsStore.shared
    @State private var customizeTargets = false
    @State private var editingDay: SplitDayConfig?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Space.l) {
                    planControls
                    targetSection
                    scheduleSection
                    todayTargetsSection
                }
                .padding(Space.l)
            }
            .background(Color.black)
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
            Text("Plan")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Training Days")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                Picker("Training Days", selection: Binding(
                    get: { store.plan.trainingDays },
                    set: { newValue in
                        store.applyTemplate(trainingDays: newValue, splitType: store.plan.splitType)
                    })
                ) {
                    Text("4").tag(4)
                    Text("5").tag(5)
                    Text("6").tag(6)
                }
                .pickerStyle(.segmented)
                .tint(.white)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Split Type")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                Picker("Split Type", selection: Binding(
                    get: { store.plan.splitType },
                    set: { newValue in
                        store.applyTemplate(trainingDays: store.plan.trainingDays, splitType: newValue)
                    })
                ) {
                    ForEach(SplitType.allCases, id: \.self) { split in
                        Text(split.rawValue).tag(split)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
            
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Units")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                Picker("Units", selection: $unitStore.unit) {
                    Text("lb").tag(WeightUnit.lb)
                    Text("kg").tag(WeightUnit.kg)
                }
                .pickerStyle(.segmented)
                .tint(.white)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding(Space.l)
        .background(Color.gray900)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray700, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
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
            
            Text("Default is \(Int(TrainingTargets.advancedWeeklySets)) sets per muscle per week.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
            
            if customizeTargets {
                VStack(spacing: Space.s) {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        HStack {
                            Text(muscle.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Stepper(
                                value: Binding(
                                    get: { Int(store.plan.weeklyTargets[muscle] ?? TrainingTargets.advancedWeeklySets) },
                                    set: { store.plan.weeklyTargets[muscle] = Double($0) }
                                ),
                                in: 10...30
                            ) {
                                Text("\(Int(store.plan.weeklyTargets[muscle] ?? TrainingTargets.advancedWeeklySets))")
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
        .background(Color.gray900)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray700, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
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
                                
                                Text(day.dayType.rawValue)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            if day.isRest {
                                Text("Rest")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            } else {
                                Text("\(day.resolvedMuscles().count) muscles")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(Space.m)
                        .background(Color.gray700.opacity(0.35))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray700, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Space.l)
        .background(Color.gray900)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray700, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }
    
    private var todayTargetsSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Today’s Targets")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            let dayIndex = store.currentTrainingDayIndex()
            let todayTargets = VolumeEngine.targetsForDay(plan: store.plan, dayIndex: dayIndex)
            
            if todayTargets.isEmpty {
                Text("Rest day. Focus on recovery.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                VStack(spacing: Space.s) {
                    ForEach(todayTargets.keys.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { muscle in
                        HStack {
                            Text(muscle.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(formatSets(todayTargets[muscle] ?? 0)) sets")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding(Space.l)
        .background(Color.gray900)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray700, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }
    
    private func weekDayLabel(for index: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let mondayFirstIndex = (index + 1) % 7
        return symbols[mondayFirstIndex]
    }
    
    private func formatSets(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
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
                            Toggle(muscle.displayName, isOn: Binding(
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
                            ))
                        }
                    }
                }
            }
            .navigationTitle("Edit Day")
            .scrollContentBackground(.hidden)
            .background(Color.black)
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
}
