import Foundation

enum Constants {
    static let defaultWorkIntervalMinutes = 45
    static let minimumWorkIntervalMinutes = 1
    static let maximumWorkIntervalMinutes = 120
    static let snoozeMinutes = 5

    static let defaultSpeechRate: Float = 0.5
    static let minimumSpeechRate: Float = 0.3
    static let maximumSpeechRate: Float = 0.7

    enum WindowID {
        static let dashboard = "dashboard"
        static let exerciseSession = "exercise-session"
        static let settings = "settings"
    }

    enum NotificationAction {
        static let categoryID = "EXERCISE_REMINDER"
        static let startAction = "START_EXERCISE"
        static let snooze1Action = "SNOOZE_1"
        static let snooze5Action = "SNOOZE_5"
        static let skipAction = "SKIP"
    }
}
