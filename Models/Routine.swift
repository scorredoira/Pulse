import Foundation
import SwiftData

@Model
final class Routine {
    var name: String
    var isDefault: Bool
    var intervalMinutes: Int = 45
    var isActive: Bool = true

    @Relationship(deleteRule: .cascade)
    var exercises: [Exercise]

    var sortedExercises: [Exercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    var totalDurationSeconds: Int {
        exercises.reduce(0) { total, exercise in
            let exerciseTime = exercise.durationSeconds * exercise.sets
            let restBetweenSets = exercise.restSeconds * max(exercise.sets - 1, 0)
            let restAfter = exercise.restAfterSeconds
            return total + exerciseTime + restBetweenSets + restAfter
        }
    }

    init(name: String, isDefault: Bool = false, intervalMinutes: Int = 45, isActive: Bool = true, exercises: [Exercise] = []) {
        self.name = name
        self.isDefault = isDefault
        self.intervalMinutes = intervalMinutes
        self.isActive = isActive
        self.exercises = exercises
    }
}
