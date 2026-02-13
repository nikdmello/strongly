import Foundation
import UserNotifications

final class RestTimerNotificationManager {
    static let shared = RestTimerNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let notificationID = "rest_timer_finished_notification"

    private init() {}

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self?.center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    func scheduleTimerFinishedNotification(in seconds: Int) {
        cancelTimerFinishedNotification()

        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Time for your next set."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        center.add(request) { _ in }
    }

    func cancelTimerFinishedNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }
}
