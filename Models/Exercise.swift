import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var durationSeconds: Int
    var exerciseDescription: String
    var iconName: String
    var healthKitActivityType: Int?
    var sortOrder: Int
    var sets: Int
    var restSeconds: Int
    var restAfterSeconds: Int
    var imageFileNames: [String] = []
    var reps: Int = 0
    var secondsPerRep: Int = 5

    @Relationship(inverse: \Routine.exercises)
    var routine: Routine?

    var effectiveDurationSeconds: Int {
        if reps > 0 { return reps * secondsPerRep }
        return durationSeconds
    }

    init(
        name: String,
        durationSeconds: Int,
        exerciseDescription: String = "",
        iconName: String = "figure.walk",
        healthKitActivityType: Int? = nil,
        sortOrder: Int = 0,
        sets: Int = 1,
        restSeconds: Int = 15,
        restAfterSeconds: Int = 0,
        imageFileNames: [String] = [],
        reps: Int = 0,
        secondsPerRep: Int = 5
    ) {
        self.name = name
        self.durationSeconds = durationSeconds
        self.exerciseDescription = exerciseDescription
        self.iconName = iconName
        self.healthKitActivityType = healthKitActivityType
        self.sortOrder = sortOrder
        self.sets = sets
        self.restSeconds = restSeconds
        self.restAfterSeconds = restAfterSeconds
        self.imageFileNames = imageFileNames
        self.reps = reps
        self.secondsPerRep = secondsPerRep
    }
}
