





import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Exercise) -> Void
    
    @State private var searchText = ""
    @State private var selectedMuscle: MuscleGroup?
    @State private var selectedEquipment: Equipment?
    @State private var recentExercises: [Exercise] = []
    
    private var filteredExercises: [Exercise] {
        let database = ExerciseDatabase.shared
        
        if !searchText.isEmpty {
            return database.search(searchText)
        }
        
        return database.filter(
            muscle: selectedMuscle,
            equipment: selectedEquipment
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
            .background(Color.background)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.body)
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
                .foregroundColor(.textSecondary)
            
            TextField("Search exercises", text: $searchText)
                .font(.body)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.surface)
        .cornerRadius(10)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    FilterChip(
                        title: muscle.displayName,
                        isSelected: selectedMuscle == muscle
                    ) {
                        selectedMuscle = selectedMuscle == muscle ? nil : muscle
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
                            .foregroundColor(.ash)
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
                            .foregroundColor(.ash)
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
                        .foregroundColor(.text)
                    
                    Text(muscleText)
                        .font(.footnote)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Text(exercise.equipment.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.surface)
                    .cornerRadius(6)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        .buttonStyle(.plain)
    }
    
    private var muscleText: String {
        exercise.primaryMuscles.map { $0.displayName }.joined(separator: ", ")
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.callout)
                .foregroundColor(isSelected ? .white : .text)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .background(isSelected ? Color.primary : Color.surface)
                .cornerRadius(20)
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
}
