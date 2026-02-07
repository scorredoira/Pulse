import Foundation
import SwiftData

@Model
final class ExerciseLog {
    var exerciseName: String
    var durationSeconds: Int
    var completedAt: Date
    var skipped: Bool
    var healthKitSynced: Bool

    @Relationship(inverse: \WorkSession.exerciseLogs)
    var workSession: WorkSession?

    init(
        exerciseName: String,
        durationSeconds: Int,
        completedAt: Date = .now,
        skipped: Bool = false,
        healthKitSynced: Bool = false
    ) {
        self.exerciseName = exerciseName
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
        self.skipped = skipped
        self.healthKitSynced = healthKitSynced
    }
}
