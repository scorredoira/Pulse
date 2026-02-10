import Foundation
import SwiftData

// MARK: - Codable DTOs for JSON import/export

struct RoutineFile: Codable {
    var routines: [RoutineDTO]
}

struct RoutineDTO: Codable {
    var name: String
    var isDefault: Bool
    var intervalMinutes: Int
    var isActive: Bool
    var exercises: [ExerciseDTO]
}

struct ExerciseDTO: Codable {
    var name: String
    var durationSeconds: Int
    var description: String
    var iconName: String
    var healthKitActivityType: Int?
    var sortOrder: Int
    var sets: Int
    var restSeconds: Int
    var restAfterSeconds: Int
}

// MARK: - SwiftData → DTO

extension Routine {
    func toDTO() -> RoutineDTO {
        RoutineDTO(
            name: name,
            isDefault: isDefault,
            intervalMinutes: intervalMinutes,
            isActive: isActive,
            exercises: sortedExercises.map { $0.toDTO() }
        )
    }
}

extension Exercise {
    func toDTO() -> ExerciseDTO {
        ExerciseDTO(
            name: name,
            durationSeconds: durationSeconds,
            description: exerciseDescription,
            iconName: iconName,
            healthKitActivityType: healthKitActivityType,
            sortOrder: sortOrder,
            sets: sets,
            restSeconds: restSeconds,
            restAfterSeconds: restAfterSeconds
        )
    }
}

// MARK: - DTO → SwiftData

extension RoutineDTO {
    func toModel() -> Routine {
        let routine = Routine(
            name: name,
            isDefault: isDefault,
            intervalMinutes: intervalMinutes,
            isActive: isActive,
            exercises: exercises.map { $0.toModel() }
        )
        return routine
    }
}

extension ExerciseDTO {
    func toModel() -> Exercise {
        Exercise(
            name: name,
            durationSeconds: durationSeconds,
            exerciseDescription: description,
            iconName: iconName,
            healthKitActivityType: healthKitActivityType,
            sortOrder: sortOrder,
            sets: sets,
            restSeconds: restSeconds,
            restAfterSeconds: restAfterSeconds
        )
    }
}
