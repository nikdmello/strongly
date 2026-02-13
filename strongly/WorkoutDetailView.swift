import SwiftUI

struct WorkoutDetailView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showRepeatSheet = false
    @ObservedObject private var unitStore = UnitSettingsStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                StarfieldBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        dateTimeSection
                        muscleBreakdownSection
                        exercisesSection

                        Button {
                            dismiss()
                        } label: {
                            Text("Close")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.spaceNavy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.m)
                                .background(Color.spaceGlow)
                                .cornerRadius(12)
                        }
                        .padding(.top, Spacing.l)
                    }
                    .padding(Spacing.m)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    closeButton
                }
            }
        }
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(session.date.formatted(date: .complete, time: .omitted))
                .font(.mega)
                .foregroundColor(.white)

            Text(session.date.formatted(date: .omitted, time: .shortened))
                .font(.title)
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(Spacing.m)
        .themedCard(cornerRadius: 18)
    }

    private var muscleBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("MUSCLE BREAKDOWN")
                .font(.micro)
                .foregroundColor(.ash)

            VStack(spacing: Spacing.xs) {
                ForEach(Array(muscleVolume.sorted(by: { $0.value > $1.value })), id: \.key) { muscle, sets in
                    HStack {
                        Text(muscle.displayName)
                            .font(.body)
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(formatSets(sets)) sets")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(Spacing.s)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
            }
        }
        .padding(Spacing.m)
        .themedCard(cornerRadius: 18)
    }

    private var muscleVolume: [MuscleGroup: Double] {
        var volume: [MuscleGroup: Double] = [:]

        for exercise in session.exercises {
            guard let ex = ExerciseDatabase.shared.getExercise(named: exercise.name) else { continue }
            let completedSets = exercise.sets.filter { $0.completed }
            let setCount = Double(completedSets.count)

            for muscle in ex.primaryMuscles {
                volume[muscle, default: 0] += setCount
            }

            for muscle in ex.secondaryMuscles {
                volume[muscle, default: 0] += setCount * TrainingTargets.secondaryMuscleCredit
            }
        }

        return volume
    }

    private func formatSets(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("EXERCISES")
                .font(.micro)
                .foregroundColor(.ash)

            VStack(spacing: Spacing.m) {
                ForEach(session.exercises) { exercise in
                    exerciseCard(exercise)
                }
            }
        }
        .padding(Spacing.m)
        .themedCard(cornerRadius: 18)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(session.exercises) { exercise in
                    exerciseCard(exercise)
                }
            }
            .padding(20)
        }
    }

    private func exerciseCard(_ exercise: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(exercise.name.uppercased())
                .font(.label)
                .foregroundColor(.white)

            VStack(spacing: 0) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    setRow(index: index, set: set)
                }
            }
        }
    }

    private func setRow(index: Int, set: ExerciseSet) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "checkmark.square.fill")
                .font(.title)
                .foregroundColor(.primary)

            Text("\(index + 1)")
                .font(.body)
                .foregroundColor(.ash)
                .frame(width: 24)

            Text("\(WeightFormatter.format(set.weight, unit: unitStore.unit))\(unitStore.unit.symbol) × \(set.reps)")
                .font(.body)
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Close")
                .font(.body)
                .foregroundColor(.white.opacity(0.75))
        }
    }
}
