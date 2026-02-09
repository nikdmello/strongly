




import SwiftUI
import Combine

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var trainingDays = 5
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: Space.m) {
                            WeeklyVolumeSection(sessions: viewModel.sessions, trainingDays: $trainingDays)
                            
                            if viewModel.sessions.isEmpty {
                                emptyState
                            } else {
                            ForEach(viewModel.sessions) { session in
                                WorkoutCard(session: session)
                            }
                            }
                        }
                        .padding(Space.l)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.load()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: Space.l) {
            Text("💪")
                .font(.system(size: 64))
            
            Text("No workouts yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Start your first workout to see it here")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
    }
}

struct WeeklyVolumeSection: View {
    let sessions: [WorkoutSession]
    @Binding var trainingDays: Int
    
    private let targetSets = TrainingTargets.advancedWeeklySets
    
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly Volume")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Target \(formatSets(targetSets)) sets")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Picker("Training Days", selection: $trainingDays) {
                Text("5 days").tag(5)
                Text("6 days").tag(6)
            }
            .pickerStyle(.segmented)
            .tint(.white)
            .background(Color.white.opacity(0.15))
            .cornerRadius(8)
            
            Text(perWorkoutSummary)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: Space.s) {
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    weeklyRow(for: muscle)
                }
            }
        }
        .padding(Space.l)
        .background(Color.gray900)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }
    
    private var perWorkoutSummary: String {
        let perWorkout = targetSets / Double(trainingDays)
        return "Spread \(formatSets(targetSets)) sets across \(trainingDays) days ≈ \(formatSets(perWorkout)) sets per muscle per session."
    }
    
    private func weeklyRow(for muscle: MuscleGroup) -> some View {
        let sets = normalizedVolumes[muscle]?.sets ?? 0
        let progress = min(sets / targetSets, 1)
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(muscle.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(formatSets(sets)) / \(formatSets(targetSets)) sets")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(6, CGFloat(progress) * geo.size.width), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var normalizedVolumes: [MuscleGroup: MuscleVolume] {
        var volumes = MuscleTracker.calculateWeeklyVolume(sessions: sessions)
        for muscle in MuscleGroup.allCases {
            if volumes[muscle] == nil {
                volumes[muscle] = MuscleVolume(muscle: muscle, sets: 0, totalVolume: 0)
            }
        }
        return volumes
    }
    
    private func formatSets(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

struct WorkoutCard: View {
    let session: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Text(session.date, style: .date)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(formatDuration(session.duration))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            ForEach(session.exercises) { exercise in
                HStack {
                    Text(exercise.name)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(exercise.sets.filter { $0.completed }.count) sets")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(Space.l)
        .background(Color.gray900)
        .cornerRadius(16)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes)m"
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var sessions: [WorkoutSession] = []
    
    private let repository = FileSystemWorkoutRepository()
    
    func load() async {
        isLoading = true
        sessions = (try? await repository.fetchAll()) ?? []
        sessions.sort { $0.date > $1.date }
        isLoading = false
    }
}

#Preview {
    HistoryView()
}
