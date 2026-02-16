import SwiftUI
import WidgetKit
import ActivityKit

struct RestTimerLiveActivity: Widget {
    private let stronglyTeal = Color(red: 134.0 / 255.0, green: 243.0 / 255.0, blue: 203.0 / 255.0)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerActivityAttributes.self) { context in
            let expired = isExpired(context.state.endTime)
            Group {
                if expired {
                    EmptyView()
                } else {
                    HStack(spacing: 10) {
                        statusIcon(resting: true, size: 26)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("REST TIMER")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.65))
                            Text(
                                timerInterval: countdownRange(for: context.state.endTime),
                                countsDown: true
                            )
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.white)
                            if let nextStep = nextStepText(for: context.state) {
                                Text(nextStep)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.72))
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, expired ? 0 : 14)
            .padding(.vertical, expired ? 0 : 10)
            .background {
                if !expired {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(stronglyTeal.opacity(0.35), lineWidth: 1)
                        )
                }
            }
            .activityBackgroundTint(.black.opacity(expired ? 0.0 : 0.98))
            .activitySystemActionForegroundColor(stronglyTeal)
        } dynamicIsland: { context in
            let expired = isExpired(context.state.endTime)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }

                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if !expired {
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                statusIcon(resting: true, size: 18)
                                Text(
                                    timerInterval: countdownRange(for: context.state.endTime),
                                    countsDown: true
                                )
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                                Text("Rest")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.82))
                            }
                            if let nextStep = nextStepText(for: context.state) {
                                Text(nextStep)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.72))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    }
                }

            } compactLeading: {
                if !expired {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(stronglyTeal)
                }
            } compactTrailing: {
                if !expired {
                    Text(
                        timerInterval: countdownRange(for: context.state.endTime),
                        countsDown: true
                    )
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 38, alignment: .trailing)
                        .foregroundColor(.white)
                }
            } minimal: {
                if !expired {
                    statusIcon(resting: true, size: 12)
                        .foregroundColor(stronglyTeal)
                }
            }
            .keylineTint(stronglyTeal)
        }
    }

    @ViewBuilder
    private func statusIcon(resting: Bool, size: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: size, weight: .semibold))

            Image(systemName: resting ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: max(8, size * 0.5), weight: .bold))
                .background(Color.black.opacity(0.35))
                .clipShape(Circle())
                .offset(x: 2, y: 2)
        }
        .foregroundStyle(resting ? stronglyTeal : .green)
    }

    private func countdownRange(for endTime: Date) -> ClosedRange<Date> {
        let now = Date()
        let clampedEnd = endTime > now ? endTime : now
        return now...clampedEnd
    }

    private func nextStepText(for state: RestTimerActivityAttributes.ContentState) -> String? {
        if let label = state.nextStepLabel, !label.isEmpty {
            return label
        }
        guard let exerciseName = state.nextExerciseName else { return nil }
        if let setNumber = state.nextSetNumber, let setTotal = state.nextSetTotal {
            return "Next: \(exerciseName) \(setNumber)/\(max(setTotal, 1))"
        }
        return "Next: \(exerciseName)"
    }

    private func isExpired(_ endTime: Date) -> Bool {
        endTime <= Date()
    }
}
