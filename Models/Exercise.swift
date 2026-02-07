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

    @Relationship(inverse: \Routine.exercises)
    var routine: Routine?

    init(
        name: String,
        durationSeconds: Int,
        exerciseDescription: String = "",
        iconName: String = "figure.walk",
        healthKitActivityType: Int? = nil,
        sortOrder: Int = 0,
        sets: Int = 1,
        restSeconds: Int = 15,
        restAfterSeconds: Int = 0
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
    }
}
