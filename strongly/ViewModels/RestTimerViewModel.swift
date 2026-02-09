import Foundation
import Combine

@MainActor
final class RestTimerViewModel: ObservableObject {
    @Published var remainingTime: Int = 0
    @Published var isActive = false

    private var timerTask: Task<Void, Never>?

    func startTimer(duration: Int? = nil) {
        timerTask?.cancel()

        let actualDuration = duration ?? 90
        remainingTime = actualDuration
        isActive = true

        timerTask = Task { [weak self] in
            while let self = self, self.remainingTime > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    self.remainingTime -= 1
                }
            }

            if let self = self, !Task.isCancelled {
                self.isActive = false
                HapticFeedback.success.trigger()
            }
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        isActive = false
        remainingTime = 0
    }

    func resume() {

    }

    deinit {
        timerTask?.cancel()
    }
}
