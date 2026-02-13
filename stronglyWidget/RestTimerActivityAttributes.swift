import Foundation
import ActivityKit

struct RestTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endTime: Date
        var totalDuration: Int
    }

    var startedAt: Date
}
