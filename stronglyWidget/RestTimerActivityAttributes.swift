import Foundation
import ActivityKit

struct RestTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endTime: Date
        var totalDuration: Int
        var nextStepLabel: String?
        var nextExerciseName: String?
        var nextSetNumber: Int?
        var nextSetTotal: Int?
    }

    var startedAt: Date
}
