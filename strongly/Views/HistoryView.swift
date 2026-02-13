import SwiftUI
import Combine

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                StarfieldBackground()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.spaceGlow)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Space.m) {
                            WeeklyVolumeSection(sessions: viewModel.sessions)

                            if viewModel.sessions.isEmpty {
                                emptyState
                            } else {
                                if let mostRecentSession {
                                    WorkoutCard(session: mostRecentSession)
                                }

                                if viewModel.sessions.count > 1 {
                                    NavigationLink {
                                        AllWorkoutsView(
                                            sessions: viewModel.sessions,
                                            onDeleteSession: { sessionId in
                                                Task {
                                                    await viewModel.delete(sessionId: sessionId)
                                                }
                                            }
                                        )
                                    } label: {
                                        Text("See All Workouts")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.spaceNavy)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(Color.spaceGlow)
                                            .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
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
        .onReceive(NotificationCenter.default.publisher(for: .workoutHistoryDidChange)) { _ in
            Task {
                await viewModel.load()
            }
        }
    }

    private var mostRecentSession: WorkoutSession? {
        viewModel.sessions.first
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

    private let targetSets = TrainingTargets.advancedWeeklySets

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Weekly Volume")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: Space.s) {
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    weeklyRow(for: muscle)
                }
            }
        }
        .padding(Space.l)
        .themedCard()
    }

    private func weeklyRow(for muscle: MuscleGroup) -> some View {
        let sets = normalizedVolumes[muscle]?.sets ?? 0
        let progress = min(sets / targetSets, 1)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                MuscleBadge(muscle: muscle, compact: true)

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
                        .fill(muscle.tint)
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

            if !sessionMuscles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sessionMuscles, id: \.self) { muscle in
                            MuscleBadge(muscle: muscle, compact: true)
                        }
                    }
                }
            }
        }
        .padding(Space.l)
        .themedCard()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes)m"
    }

    private var sessionMuscles: [MuscleGroup] {
        var muscles = Set<MuscleGroup>()
        for exercise in session.exercises {
            if let metadata = ExerciseDatabase.shared.getExercise(named: exercise.name) {
                for muscle in metadata.primaryMuscles {
                    muscles.insert(muscle)
                }
            }
        }
        return muscles.sorted { $0.displayName < $1.displayName }
    }
}

struct AllWorkoutsView: View {
    let onDeleteSession: (UUID) -> Void
    @State private var displayedSessions: [WorkoutSession]

    init(sessions: [WorkoutSession], onDeleteSession: @escaping (UUID) -> Void) {
        self.onDeleteSession = onDeleteSession
        self._displayedSessions = State(initialValue: sessions)
    }

    var body: some View {
        ZStack {
            StarfieldBackground()

            List {
                ForEach(displayedSessions) { session in
                    ZStack {
                        WorkoutCard(session: session)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            HapticFeedback.warning.trigger()
                            delete(session)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle("All Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private func delete(_ session: WorkoutSession) {
        withAnimation(Motion.quick) {
            displayedSessions.removeAll { $0.id == session.id }
        }
        onDeleteSession(session.id)
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

    func delete(sessionId: UUID) async {
        do {
            try await repository.delete(sessionId)
            sessions.removeAll { $0.id == sessionId }
        } catch {
            sessions = (try? await repository.fetchAll()) ?? sessions
            sessions.sort { $0.date > $1.date }
        }
    }
}

#Preview {
    HistoryView()
}
