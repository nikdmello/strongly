import SwiftUI

struct OnboardingView: View {
    @Binding var tabSelection: Int
    @Environment(\.dismiss) private var dismiss
    @State private var style: WorkoutStyle = .heavy
    @State private var isGenerating = false
    @State private var generatedExercises: [ExerciseLog] = []
    @State private var showWorkout = false
    @StateObject private var planStore = SplitPlanStore()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
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
                preloadedExercises: generatedExercises
            )
        }
    }
    
    private var planStartView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Today's Plan")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            planCard
            
            Button {
                Task {
                    await generateWorkout()
                }
            } label: {
                Text("Start Workout")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            
            Button("Customize workout") {
                tabSelection = 1
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.7))
            
            Text("Edit your plan in the Plan tab")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
        }
    }
    
    private var planCard: some View {
        let dayIndex = planStore.currentTrainingDayIndex()
        let day = planStore.plan.days[dayIndex]
        let targets = VolumeEngine.targetsForDay(plan: planStore.plan, dayIndex: dayIndex)
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.dayType.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.text)
                    
                    Text("Sets per muscle based on your plan")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Menu {
                    ForEach(WorkoutStyle.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            style = option
                        }
                    }
                } label: {
                    Text(style.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.surface)
                        .cornerRadius(10)
                }
            }
            
            if targets.isEmpty {
                Text("Rest day. You can still train, but volume won't be optimized.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(targets.keys.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { muscle in
                        HStack {
                            Text(muscle.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.text)
                            
                            Spacer()
                            
                            Text("\(formatSets(targets[muscle] ?? 0)) sets")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .padding(.horizontal, 32)
    }
    
    
    
    private var generatingView: some View {
        VStack(spacing: 32) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Building your workout...")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private func generateWorkout() async {
        isGenerating = true
        
        let generator = WorkoutGenerator.shared
        let muscles = plannedMuscles(for: Date())
        
        let request = WorkoutRequest(
            duration: style.duration,
            targetMuscles: muscles,
            equipment: .gym,
            preferredExercises: []
        )
        
        let workout = await generator.generateIntelligentWorkout(request: request)
        
        let perSessionTargets = plannedTargets(for: Date())
        let muscleCounts = primaryMuscleExerciseCounts(in: workout.exercises)
        let adjusted = workout.exercises.map { ex in
            var modified = ex
            let baseSets = style.setCount()
            let desired = suggestedSetCount(
                for: ex,
                baseSets: baseSets,
                perSessionTargets: perSessionTargets,
                muscleExerciseCounts: muscleCounts
            )
            modified.sets = Array(ex.sets.prefix(desired))
            return modified
        }
        
        generatedExercises = adjusted
        
        
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
    
    private func selectMuscles() -> [MuscleGroup] {
        let upper = [
            MuscleGroup.chestUpper,
            .chestLower,
            .backWidth,
            .backThickness,
            .shoulderFront,
            .shoulderSide,
            .shoulderRear,
            .biceps,
            .triceps
        ]
        
        let lower = [
            MuscleGroup.quads,
            .hamstrings,
            .glutes,
            .calves
        ]
        
        let core = [MuscleGroup.abs]
        return (upper + lower + core).shuffled().prefix(5).map { $0 }
    }
    
    private func plannedMuscles(for date: Date) -> [MuscleGroup] {
        let plan = planStore.plan
        let dayIndex = planStore.currentTrainingDayIndex()
        let day = plan.days[dayIndex]
        let muscles = day.resolvedMuscles()
        if muscles.isEmpty {
            return selectMuscles()
        }
        return muscles
    }
    
    private func plannedTargets(for date: Date) -> [MuscleGroup: Double] {
        let plan = planStore.plan
        let dayIndex = planStore.currentTrainingDayIndex()
        return VolumeEngine.targetsForDay(plan: plan, dayIndex: dayIndex)
    }
    
    private func primaryMuscleExerciseCounts(in exercises: [ExerciseLog]) -> [MuscleGroup: Int] {
        var counts: [MuscleGroup: Int] = [:]
        for exercise in exercises {
            if let ex = ExerciseDatabase.shared.getExercise(named: exercise.name) {
                for muscle in ex.primaryMuscles {
                    counts[muscle, default: 0] += 1
                }
            }
        }
        return counts
    }
    
    private func suggestedSetCount(
        for exercise: ExerciseLog,
        baseSets: Int,
        perSessionTargets: [MuscleGroup: Double],
        muscleExerciseCounts: [MuscleGroup: Int]
    ) -> Int {
        guard let ex = ExerciseDatabase.shared.getExercise(named: exercise.name) else {
            return baseSets
        }
        
        let suggestions = ex.primaryMuscles.compactMap { muscle -> Double? in
            guard let target = perSessionTargets[muscle] else { return nil }
            let count = Double(max(1, muscleExerciseCounts[muscle] ?? 1))
            return target / count
        }
        
        guard !suggestions.isEmpty else { return baseSets }
        
        let avg = suggestions.reduce(0, +) / Double(suggestions.count)
        let desired = Int(round(avg))
        let clamped = max(1, min(6, desired))
        return min(6, max(baseSets, clamped))
    }
    
    private func formatSets(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}


enum WorkoutStyle: String, CaseIterable {
    case quick = "Just 5 Minutes"
    case bodyweight = "Bodyweight"
    case heavy = "Heavy Lifting"
    case endurance = "Endurance"
    
    var emoji: String {
        switch self {
        case .quick: return "⚡"
        case .bodyweight: return "🤸"
        case .heavy: return "🏋️"
        case .endurance: return "🏃"
        }
    }
    
    var description: String {
        switch self {
        case .quick: return "One set counts"
        case .bodyweight: return "No equipment needed"
        case .heavy: return "Strength focus"
        case .endurance: return "High reps, cardio"
        }
    }
    
    var duration: Int {
        switch self {
        case .quick: return 5
        case .bodyweight: return 30
        case .heavy: return 45
        case .endurance: return 40
        }
    }
    
    func setCount() -> Int {
        switch self {
        case .quick: return 1
        case .bodyweight, .endurance: return 3
        case .heavy: return 4
        }
    }
}
