import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class RestTimerLiveActivityManager {
    static let shared = RestTimerLiveActivityManager()

    private init() {}

#if canImport(ActivityKit)
    private var currentActivity: Activity<RestTimerActivityAttributes>?
#endif

    func startOrUpdate(endDate: Date, totalDuration: Int) async {
#if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = RestTimerActivityAttributes.ContentState(
            endTime: endDate,
            totalDuration: totalDuration
        )
        let content = ActivityContent(state: state, staleDate: endDate)

        if currentActivity == nil {
            currentActivity = Activity<RestTimerActivityAttributes>.activities.first
        }

        if let currentActivity {
            await currentActivity.update(content)
            return
        }

        do {
            let attributes = RestTimerActivityAttributes(startedAt: Date())
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            currentActivity = nil
        }
#else
        _ = endDate
        _ = totalDuration
#endif
    }

    func end() async {
#if canImport(ActivityKit)
        if currentActivity == nil {
            currentActivity = Activity<RestTimerActivityAttributes>.activities.first
        }
        guard let currentActivity else { return }

        let endState = RestTimerActivityAttributes.ContentState(
            endTime: Date(),
            totalDuration: 0
        )
        let content = ActivityContent(state: endState, staleDate: Date())
        await currentActivity.end(content, dismissalPolicy: .immediate)
        self.currentActivity = nil
#endif
    }
}
