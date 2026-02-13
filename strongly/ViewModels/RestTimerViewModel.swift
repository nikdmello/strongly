import Foundation
import Combine

@MainActor
final class RestTimerViewModel: ObservableObject {
    @Published var remainingTime: Int = 0
    @Published var isActive = false
    @Published private(set) var preferredDuration: Int

    private var timerTask: Task<Void, Never>?
    private var endDate: Date?
    private let notificationManager = RestTimerNotificationManager.shared
    private let liveActivityManager = RestTimerLiveActivityManager.shared

    private static let defaultDuration = 90
    private static let minDuration = 15
    private static let maxDuration = 600
    private static let preferredDurationKey = "rest_timer_preferred_duration_seconds"
    private static let activeEndDateKey = "rest_timer_active_end_date"

    init() {
        let savedDefault = UserDefaults.standard.integer(forKey: Self.preferredDurationKey)
        let resolvedDefault = Self.normalizeDuration(savedDefault == 0 ? Self.defaultDuration : savedDefault)
        self.preferredDuration = resolvedDefault

        let savedEndDate = UserDefaults.standard.object(forKey: Self.activeEndDateKey) as? Date
        if let savedEndDate, savedEndDate.timeIntervalSinceNow > 0 {
            endDate = savedEndDate
            isActive = true
            remainingTime = max(1, Int(ceil(savedEndDate.timeIntervalSinceNow)))
            scheduleTick()
            Task {
                await liveActivityManager.startOrUpdate(endDate: savedEndDate, totalDuration: preferredDuration)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: Self.activeEndDateKey)
        }
    }

    func startTimer(duration: Int? = nil, persistAsDefault: Bool = false) {
        timerTask?.cancel()

        let actualDuration = Self.normalizeDuration(duration ?? preferredDuration)
        if persistAsDefault {
            setPreferredDuration(actualDuration)
        }

        let timerEndDate = Date().addingTimeInterval(Double(actualDuration))
        endDate = timerEndDate
        remainingTime = actualDuration
        isActive = true

        UserDefaults.standard.set(timerEndDate, forKey: Self.activeEndDateKey)
        notificationManager.requestAuthorizationIfNeeded()
        notificationManager.scheduleTimerFinishedNotification(in: actualDuration)

        Task {
            await liveActivityManager.startOrUpdate(endDate: timerEndDate, totalDuration: actualDuration)
        }
        scheduleTick()
    }

    func adjustActiveTimer(by seconds: Int) {
        guard isActive else { return }
        let adjusted = remainingTime + seconds
        if adjusted <= 0 {
            stopTimer()
            return
        }
        startTimer(duration: adjusted, persistAsDefault: true)
    }

    func setPreferredDuration(_ seconds: Int) {
        let normalized = Self.normalizeDuration(seconds)
        preferredDuration = normalized
        UserDefaults.standard.set(normalized, forKey: Self.preferredDurationKey)
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        isActive = false
        remainingTime = 0
        endDate = nil
        UserDefaults.standard.removeObject(forKey: Self.activeEndDateKey)
        notificationManager.cancelTimerFinishedNotification()

        Task {
            await liveActivityManager.end()
        }
    }

    func resume() {
        guard isActive else { return }
        syncRemainingTime()
        if isActive && timerTask == nil {
            scheduleTick()
        }
    }

    deinit {
        timerTask?.cancel()
    }

    private func scheduleTick() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.syncRemainingTime()
                if !self.isActive {
                    break
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func syncRemainingTime() {
        guard let endDate else {
            stopTimer()
            return
        }
        let secondsLeft = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if remainingTime != secondsLeft {
            remainingTime = secondsLeft
        }
        if secondsLeft <= 0 {
            finishTimer()
        }
    }

    private func finishTimer() {
        timerTask?.cancel()
        timerTask = nil
        isActive = false
        remainingTime = 0
        endDate = nil
        UserDefaults.standard.removeObject(forKey: Self.activeEndDateKey)
        notificationManager.cancelTimerFinishedNotification()
        HapticFeedback.success.trigger()
        Task {
            await liveActivityManager.end()
        }
    }

    private static func normalizeDuration(_ seconds: Int) -> Int {
        max(minDuration, min(maxDuration, seconds))
    }
}
