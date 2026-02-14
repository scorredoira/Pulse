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
    var sortOrder: Int?
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
    var images: [String]?
    var reps: Int?
    var secondsPerRep: Int?
}

// MARK: - SwiftData → DTO

extension Routine {
    func toDTO() -> RoutineDTO {
        RoutineDTO(
            name: name,
            isDefault: isDefault,
            intervalMinutes: intervalMinutes,
            isActive: isActive,
            sortOrder: sortOrder,
            exercises: sortedExercises.map { $0.toDTO() }
        )
    }
}

extension Exercise {
    func toDTO() -> ExerciseDTO {
        var imageData: [String]?
        if !imageFileNames.isEmpty {
            let imagesDir = Constants.FilePaths.imagesDirectory
            imageData = imageFileNames.compactMap { fileName in
                let url = imagesDir.appendingPathComponent(fileName)
                guard let data = try? Data(contentsOf: url) else { return nil }
                return data.base64EncodedString()
            }
            if imageData?.isEmpty == true { imageData = nil }
        }

        return ExerciseDTO(
            name: name,
            durationSeconds: durationSeconds,
            description: exerciseDescription,
            iconName: iconName,
            healthKitActivityType: healthKitActivityType,
            sortOrder: sortOrder,
            sets: sets,
            restSeconds: restSeconds,
            restAfterSeconds: restAfterSeconds,
            images: imageData,
            reps: reps > 0 ? reps : nil,
            secondsPerRep: reps > 0 ? secondsPerRep : nil
        )
    }
}

// MARK: - DTO → SwiftData

extension RoutineDTO {
    func toModel(fallbackSortOrder: Int = 0) -> Routine {
        let routine = Routine(
            name: name,
            isDefault: isDefault,
            intervalMinutes: intervalMinutes,
            isActive: isActive,
            sortOrder: sortOrder ?? fallbackSortOrder,
            exercises: exercises.map { $0.toModel() }
        )
        return routine
    }
}

extension ExerciseDTO {
    func toModel() -> Exercise {
        var savedFileNames: [String] = []

        if let images, !images.isEmpty {
            let imagesDir = Constants.FilePaths.imagesDirectory
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

            for base64 in images {
                guard let data = Data(base64Encoded: base64) else { continue }
                let fileName = UUID().uuidString + ".png"
                let fileURL = imagesDir.appendingPathComponent(fileName)
                do {
                    try data.write(to: fileURL, options: .atomic)
                    savedFileNames.append(fileName)
                } catch {
                    // Skip failed image writes
                }
            }
        }

        let effectiveReps = reps ?? 0
        let effectiveSecondsPerRep = secondsPerRep ?? 5
        let effectiveDuration: Int
        if effectiveReps > 0 && durationSeconds < 1 {
            effectiveDuration = effectiveReps * effectiveSecondsPerRep
        } else {
            effectiveDuration = durationSeconds
        }

        return Exercise(
            name: name,
            durationSeconds: effectiveDuration,
            exerciseDescription: description,
            iconName: iconName,
            healthKitActivityType: healthKitActivityType,
            sortOrder: sortOrder,
            sets: sets,
            restSeconds: restSeconds,
            restAfterSeconds: restAfterSeconds,
            imageFileNames: savedFileNames,
            reps: effectiveReps,
            secondsPerRep: effectiveSecondsPerRep
        )
    }
}
