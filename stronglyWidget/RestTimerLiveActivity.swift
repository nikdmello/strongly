import SwiftUI
import WidgetKit
import ActivityKit

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerActivityAttributes.self) { context in
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
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                    )
            )
            .activityBackgroundTint(.black.opacity(0.98))
            .activitySystemActionForegroundColor(.cyan)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }

                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }

                DynamicIslandExpandedRegion(.bottom) {
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }

            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.cyan)
            } compactTrailing: {
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
            } minimal: {
                statusIcon(resting: true, size: 12)
                    .foregroundColor(.cyan)
            }
            .keylineTint(.cyan)
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
        .foregroundStyle(resting ? .cyan : .green)
    }

    private func countdownRange(for endTime: Date) -> ClosedRange<Date> {
        Date()...endTime
    }
}
