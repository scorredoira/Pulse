import Foundation
import SwiftData

@Model
final class WorkSession {
    var startDate: Date
    var endDate: Date?
    var workIntervalMinutes: Int
    var wasCompleted: Bool

    @Relationship(deleteRule: .cascade)
    var exerciseLogs: [ExerciseLog]

    var totalExerciseSeconds: Int {
        exerciseLogs
            .filter { !$0.skipped }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    init(
        startDate: Date = .now,
        endDate: Date? = nil,
        workIntervalMinutes: Int = 45,
        wasCompleted: Bool = false,
        exerciseLogs: [ExerciseLog] = []
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.workIntervalMinutes = workIntervalMinutes
        self.wasCompleted = wasCompleted
        self.exerciseLogs = exerciseLogs
    }
}
