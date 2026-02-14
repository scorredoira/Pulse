import Foundation
import SwiftData

struct PersistenceService {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            Routine.self,
            WorkSession.self,
            ExerciseLog.self,
            AppSettings.self,
        ])

        let config = ModelConfiguration(
            "Pulse",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    static func seedDefaultDataIfNeeded(context: ModelContext) {
        // Seed AppSettings if none exist
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let existingSettings = (try? context.fetch(settingsDescriptor)) ?? []
        if existingSettings.isEmpty {
            context.insert(AppSettings())
        }

        // Seed default routine if none exist
        let routineDescriptor = FetchDescriptor<Routine>(sortBy: [SortDescriptor(\Routine.name)])
        let existingRoutines = (try? context.fetch(routineDescriptor)) ?? []
        if existingRoutines.isEmpty {
            seedDefaultRoutine(context: context)
        } else if existingRoutines.count > 1 && existingRoutines.allSatisfy({ $0.sortOrder == 0 }) {
            // Migrate: assign sortOrder to existing routines upgraded from before sortOrder existed
            for (index, routine) in existingRoutines.enumerated() {
                routine.sortOrder = index
            }
        }
    }

    @MainActor
    private static func seedDefaultRoutine(context: ModelContext) {
        // MARK: - Micro Pausa (every 30 min, ~1 min)
        // Quick reset: neck, shoulders, eyes. Doesn't break flow.

        let neckStretch = Exercise(
            name: "Neck Stretch",
            durationSeconds: 20,
            exerciseDescription: "Tilt your head slowly side to side, then forward and back. Hold each position for a few seconds.",
            iconName: "figure.flexibility",
            sortOrder: 0,
            restAfterSeconds: 5
        )

        let shoulderRolls = Exercise(
            name: "Shoulder Rolls",
            durationSeconds: 15,
            exerciseDescription: "Roll your shoulders forward 5 times, then backward 5 times. Relax and let them drop.",
            iconName: "figure.cooldown",
            sortOrder: 1,
            restAfterSeconds: 5
        )

        let eyeRest = Exercise(
            name: "Eye Rest",
            durationSeconds: 20,
            exerciseDescription: "Look away from the screen. Focus on something 6 meters away. Blink slowly a few times.",
            iconName: "eye",
            sortOrder: 2,
            restAfterSeconds: 0
        )

        let microPausa = Routine(
            name: "Micro Pausa",
            isDefault: false,
            intervalMinutes: 30,
            isActive: true,
            sortOrder: 0,
            exercises: [neckStretch, shoulderRolls, eyeRest]
        )

        context.insert(microPausa)

        // MARK: - Pausa Activa (every 90 min, ~5 min)
        // Full body reset: walk, stretch, strength.

        let walk = Exercise(
            name: "Walk",
            durationSeconds: 120,
            exerciseDescription: "Walk around the house or office. Get some water. Move freely.",
            iconName: "figure.walk",
            healthKitActivityType: 37,
            sortOrder: 0,
            restAfterSeconds: 10
        )

        let fullStretch = Exercise(
            name: "Full Stretch",
            durationSeconds: 60,
            exerciseDescription: "Stretch your back, hamstrings, and hip flexors. Hold each stretch for 15 seconds.",
            iconName: "figure.flexibility",
            healthKitActivityType: 52,
            sortOrder: 1,
            restAfterSeconds: 10
        )

        let plank = Exercise(
            name: "Plank",
            durationSeconds: 30,
            exerciseDescription: "Hold a plank position. Keep your core tight and body in a straight line.",
            iconName: "figure.core.training",
            healthKitActivityType: 20,
            sortOrder: 2,
            restAfterSeconds: 10
        )

        let squats = Exercise(
            name: "Squats",
            durationSeconds: 30,
            exerciseDescription: "Do bodyweight squats at a comfortable pace. Keep your back straight.",
            iconName: "figure.strengthtraining.functional",
            healthKitActivityType: 13,
            sortOrder: 3,
            restAfterSeconds: 0
        )

        let pausaActiva = Routine(
            name: "Pausa Activa",
            isDefault: true,
            intervalMinutes: 90,
            isActive: true,
            sortOrder: 1,
            exercises: [walk, fullStretch, plank, squats]
        )

        context.insert(pausaActiva)
    }
}
