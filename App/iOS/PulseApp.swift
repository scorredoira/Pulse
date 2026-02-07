import SwiftUI
import SwiftData

@main
struct PulseApp: App {
    @State private var timerService = TimerService()
    @State private var exerciseSessionService = ExerciseSessionService()
    @State private var audioService = AudioGuidanceService()
    @State private var healthKitService = HealthKitService()

    let container: ModelContainer

    init() {
        do {
            container = try PersistenceService.makeContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        PersistenceService.seedDefaultDataIfNeeded(context: container.mainContext)
        NotificationService.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            HomeView(
                timerService: timerService,
                exerciseSessionService: exerciseSessionService,
                audioService: audioService,
                healthKitService: healthKitService
            )
            .modelContainer(container)
        }
    }
}
