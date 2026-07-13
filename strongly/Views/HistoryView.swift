import SwiftUI
import Combine

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                StarfieldBackground()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.spaceGlow)
                } else {
                    ScrollView {
                        LazyVStack(spacing: PremiumLayout.sectionSpacing) {
                            historyHero
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
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, Layout.screenHorizontal)
                        .padding(.vertical, Space.l)
                    }
                }
            }
            .navigationTitle("Progress")
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

    private var historyHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLead(
                title: "Proof of the work",
                subtitle: "Show up, finish hard sets, and repeat long enough for the trend to matter."
            )

            HStack(spacing: 10) {
                historyStatPill(
                    icon: "calendar.badge.clock",
                    title: "This Week",
                    value: "\(weekWorkoutCount)"
                )
                historyStatPill(
                    icon: "flame.fill",
                    title: "Streak",
                    value: "\(workoutStreak)d"
                )
                historyStatPill(
                    icon: "checkmark.circle.fill",
                    title: "Sets",
                    value: "\(allTimeCompletedSets)"
                )
            }
        }
        .premiumSectionCard()
    }

    private func historyStatPill(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.spaceGlow)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.62))
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

    private var weekWorkoutCount: Int {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        return viewModel.sessions.filter { $0.date >= cutoff }.count
    }

    private var allTimeCompletedSets: Int {
        viewModel.sessions.reduce(0) { partial, session in
            partial + session.exercises.reduce(0) { exercisePartial, exercise in
                exercisePartial + exercise.sets.filter { $0.completed }.count
            }
        }
    }

    private var workoutStreak: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(viewModel.sessions.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        while uniqueDays.contains(cursor) {
            streak += 1
            guard let prior = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prior
        }
        return streak
    }

    private var emptyState: some View {
        VStack(spacing: Space.l) {
            ZStack {
                Circle()
                    .fill(Color.spaceGlow.opacity(0.14))
                    .frame(width: 74, height: 74)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.spaceGlow)
            }

            Text("Your log starts here")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Your completed workouts will appear here.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .premiumSectionCard(padding: Space.xl, cornerRadius: 20)
    }
}

struct WeeklyVolumeSection: View {
    let sessions: [WorkoutSession]
    @EnvironmentObject private var planStore: SplitPlanStore
    @State private var showAllMuscles = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top) {
                SectionLead(
                    title: "Enough Weekly Work",
                    subtitle: "A simple check that the week is moving."
                )

                Spacer()
            }

            VStack(spacing: Space.s) {
                ForEach(displayedMuscles, id: \.self) { muscle in
                    weeklyRow(for: muscle)
                }
            }

            if MuscleGroup.allCases.count > displayedMuscles.count {
                Button {
                    withAnimation(Motion.quick) {
                        showAllMuscles.toggle()
                    }
                } label: {
                    Text(showAllMuscles ? "Show less" : "Show full breakdown")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.spaceGlow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .premiumSectionCard()
    }

    private var displayedMuscles: [MuscleGroup] {
        if showAllMuscles {
            return MuscleGroup.allCases
        }
        return MuscleGroup.allCases
            .sorted { lhs, rhs in
                let lhsSets = normalizedVolumes[lhs]?.sets ?? 0
                let rhsSets = normalizedVolumes[rhs]?.sets ?? 0
                return lhsSets > rhsSets
            }
            .prefix(6)
            .map { $0 }
    }

    private func weeklyRow(for muscle: MuscleGroup) -> some View {
        let sets = normalizedVolumes[muscle]?.sets ?? 0
        let targetSets = planStore.plan.weeklyTargets[muscle] ?? TrainingTargets.advancedWeeklySets
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
        var volumes = MuscleTracker.calculateWeeklyVolume(
            sessions: sessions,
            fromDate: planStore.weeklyVolumeWindowStart()
        )
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
        .premiumSectionCard()
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
                    .listRowInsets(EdgeInsets(top: 0, leading: Layout.screenHorizontal, bottom: 12, trailing: Layout.screenHorizontal))
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
        .navigationTitle("Workout Log")
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
        .environmentObject(SplitPlanStore())
}
