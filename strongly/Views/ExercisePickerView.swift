import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var selectedEquipment: Equipment?
    @State private var recentExercises: [Exercise] = []

    private var filteredExercises: [Exercise] {
        let database = ExerciseDatabase.shared

        let base = searchText.isEmpty
            ? database.exercises
            : database.search(searchText)

        return database.filter(
            muscles: selectedMuscles,
            equipment: selectedEquipment,
            source: base
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                filterSection
                Divider()
                resultsList
            }
            .background(StarfieldBackground())
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .task {
                await loadRecentExercises()
            }
        }
    }

    private func loadRecentExercises() async {

        let repo = FileSystemWorkoutRepository()
        guard let sessions = try? await repo.fetchAll() else { return }

        var seen = Set<String>()
        var recent: [Exercise] = []

        for session in sessions.prefix(10) {
            for exercise in session.exercises {
                if !seen.contains(exercise.name) {
                    if let ex = ExerciseDatabase.shared.getExercise(named: exercise.name) {
                        recent.append(ex)
                        seen.insert(exercise.name)
                        if recent.count >= 5 { break }
                    }
                }
            }
            if recent.count >= 5 { break }
        }

        recentExercises = recent
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))

            TextField("Search exercises", text: $searchText)
                .font(.body)
                .textFieldStyle(.plain)
                .foregroundColor(.white)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(Spacing.m)
        .themedCard(cornerRadius: 12)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                FilterChip(
                    title: "All",
                    symbolName: "line.3.horizontal.decrease.circle",
                    isSelected: selectedMuscles.isEmpty
                ) {
                    selectedMuscles.removeAll()
                }

                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    FilterChip(
                        title: muscle.displayName,
                        symbolName: muscle.symbolName,
                        isSelected: selectedMuscles.contains(muscle)
                    ) {
                        if selectedMuscles.contains(muscle) {
                            selectedMuscles.remove(muscle)
                        } else {
                            selectedMuscles.insert(muscle)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.l)
        }
        .padding(.bottom, Spacing.m)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {

                if !recentExercises.isEmpty && searchText.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("RECENT")
                            .font(.micro)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, Spacing.l)
                            .padding(.top, Spacing.m)

                        ForEach(recentExercises) { exercise in
                            ExerciseRow(exercise: exercise) {
                                onSelect(exercise)
                                dismiss()
                            }

                            if exercise.id != recentExercises.last?.id {
                                Divider()
                                    .padding(.leading, Spacing.l)
                            }
                        }

                        Divider()
                            .padding(.vertical, Spacing.m)

                        Text("ALL EXERCISES")
                            .font(.micro)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, Spacing.l)
                    }
                }

                ForEach(filteredExercises) { exercise in
                    ExerciseRow(exercise: exercise) {
                        onSelect(exercise)
                        dismiss()
                    }

                    if exercise.id != filteredExercises.last?.id {
                        Divider()
                            .padding(.leading, Spacing.l)
                    }
                }
            }
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(exercise.name)
                        .font(.body)
                        .foregroundColor(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(exercise.primaryMuscles.prefix(3)), id: \.self) { muscle in
                                MuscleBadge(muscle: muscle, compact: true)
                            }
                            if exercise.primaryMuscles.count > 3 {
                                Text("+\(exercise.primaryMuscles.count - 3)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.75))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Spacer()

                Text(exercise.equipment.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.white.opacity(0.14))
                    .cornerRadius(6)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .themedCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}

struct FilterChip: View {
    let title: String
    let symbolName: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.callout)
            }
            .foregroundColor(isSelected ? .spaceNavy : .white)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(isSelected ? Color.spaceGlow : Color.white.opacity(0.14))
            .cornerRadius(20)
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
}
