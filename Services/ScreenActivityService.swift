import Foundation
import AppKit

@Observable
final class ScreenActivityService {
    private let timerService: TimerService
    private let exerciseSessionService: ExerciseSessionService

    private var timerWasPausedByScreen = false
    private var exerciseWasPausedByScreen = false

    private var observers: [NSObjectProtocol] = []

    init(timerService: TimerService, exerciseSessionService: ExerciseSessionService) {
        self.timerService = timerService
        self.exerciseSessionService = exerciseSessionService
    }

    func startMonitoring() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()

        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleScreenInactive()
            }
        )

        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleScreenActive()
            }
        )

        observers.append(
            distributed.addObserver(
                forName: NSNotification.Name("com.apple.screensaver.didstart"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleScreenInactive()
            }
        )

        observers.append(
            distributed.addObserver(
                forName: NSNotification.Name("com.apple.screensaver.didstop"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleScreenActive()
            }
        )
    }

    func stopMonitoring() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()

        for observer in observers {
            workspace.removeObserver(observer)
            distributed.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func handleScreenInactive() {
        if timerService.state == .running {
            timerService.pause()
            timerWasPausedByScreen = true
        }

        if exerciseSessionService.state == .running {
            exerciseSessionService.pause()
            exerciseWasPausedByScreen = true
        }
    }

    private func handleScreenActive() {
        if timerWasPausedByScreen {
            timerService.resume()
            timerWasPausedByScreen = false
        }

        if exerciseWasPausedByScreen {
            exerciseSessionService.resume()
            exerciseWasPausedByScreen = false
        }
    }

    deinit {
        stopMonitoring()
    }
}
