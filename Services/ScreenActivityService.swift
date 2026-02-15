import Foundation
import AppKit
import IOKit
import IOKit.pwr_mgt

@Observable
final class ScreenActivityService {
    private let timerService: TimerService

    private var timerWasPausedByScreen = false

    private var observers: [NSObjectProtocol] = []

    private var sleepAssertionID: IOPMAssertionID = 0
    private(set) var isSleepPrevented: Bool = false

    init(timerService: TimerService) {
        self.timerService = timerService
    }

    // MARK: - Sleep prevention

    func preventSleep() {
        guard !isSleepPrevented else { return }
        let reason = "Pulse exercise session in progress" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &sleepAssertionID
        )
        if result == kIOReturnSuccess {
            isSleepPrevented = true
        }
    }

    func allowSleep() {
        guard isSleepPrevented else { return }
        IOPMAssertionRelease(sleepAssertionID)
        isSleepPrevented = false
    }

    // MARK: - Screen monitoring

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
        allowSleep()
    }

    private func handleScreenInactive() {
        if timerService.state == .running {
            timerService.pause()
            timerWasPausedByScreen = true
        }
    }

    private func handleScreenActive() {
        if timerWasPausedByScreen {
            timerService.resume()
            timerWasPausedByScreen = false
        }
    }

    deinit {
        stopMonitoring()
    }
}
