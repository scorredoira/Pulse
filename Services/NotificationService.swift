import UserNotifications

final class NotificationService: NSObject {
    static let shared = NotificationService()

    var onStartExercise: (() -> Void)?
    var onSnooze: ((Int) -> Void)?
    var onSkip: (() -> Void)?

    private override init() {
        super.init()
    }

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                #if DEBUG
                print("Notification permission error: \(error)")
                #endif
            }
        }
        center.delegate = self
        registerCategories()
    }

    func sendExerciseReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Move!"
        content.body = "Your work interval is complete. Let's do some exercises!"
        content.sound = .default
        content.categoryIdentifier = Constants.NotificationAction.categoryID

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendSnoozeConfirmation(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Snoozed"
        content.body = "Exercise reminder snoozed for \(minutes) minutes."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func registerCategories() {
        let startAction = UNNotificationAction(
            identifier: Constants.NotificationAction.startAction,
            title: "Start Exercises",
            options: .foreground
        )

        let snooze1Action = UNNotificationAction(
            identifier: Constants.NotificationAction.snooze1Action,
            title: "+1 min",
            options: []
        )

        let snooze5Action = UNNotificationAction(
            identifier: Constants.NotificationAction.snooze5Action,
            title: "+5 min",
            options: []
        )

        let skipAction = UNNotificationAction(
            identifier: Constants.NotificationAction.skipAction,
            title: "Skip",
            options: .destructive
        )

        let category = UNNotificationCategory(
            identifier: Constants.NotificationAction.categoryID,
            actions: [startAction, snooze1Action, snooze5Action, skipAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            switch response.actionIdentifier {
            case Constants.NotificationAction.startAction,
                 UNNotificationDefaultActionIdentifier:
                onStartExercise?()
            case Constants.NotificationAction.snooze1Action:
                onSnooze?(1)
            case Constants.NotificationAction.snooze5Action:
                onSnooze?(5)
            case Constants.NotificationAction.skipAction:
                onSkip?()
            default:
                break
            }
        }
    }
}
