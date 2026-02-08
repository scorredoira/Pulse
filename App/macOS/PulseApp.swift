import SwiftUI
import SwiftData

@main
struct PulseApp: App {
    @State private var timerService = TimerService()
    @State private var exerciseSessionService = ExerciseSessionService()
    @State private var audioService = AudioGuidanceService()
    @State private var healthKitService = HealthKitService()
    @State private var screenActivityService: ScreenActivityService?
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar = false
    @Environment(\.openWindow) private var openWindow

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
        MenuBarExtra {
            MenuBarContentView(
                timerService: timerService,
                exerciseSessionService: exerciseSessionService,
                audioService: audioService,
                healthKitService: healthKitService
            )
            .modelContainer(container)
            .onAppear {
                if screenActivityService == nil {
                    let service = ScreenActivityService(
                        timerService: timerService,
                        exerciseSessionService: exerciseSessionService
                    )
                    service.startMonitoring()
                    screenActivityService = service
                }
            }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Window("Dashboard", id: Constants.WindowID.dashboard) {
            DashboardView()
                .modelContainer(container)
                .onAppear { setDockVisible(true) }
                .onDisappear { hideDockIfNoWindows() }
        }
        .defaultSize(width: 600, height: 700)
        .defaultLaunchBehavior(.suppressed)

        Window("Exercise Session", id: Constants.WindowID.exerciseSession) {
            ExerciseSessionView(sessionService: exerciseSessionService)
                .onAppear { setDockVisible(true) }
                .onDisappear { hideDockIfNoWindows() }
        }
        .defaultSize(width: 450, height: 600)
        .defaultLaunchBehavior(.suppressed)

        Window("Settings", id: Constants.WindowID.settings) {
            SettingsView(healthKitService: healthKitService)
                .modelContainer(container)
                .onAppear { setDockVisible(true) }
                .onDisappear { hideDockIfNoWindows() }
        }
        .defaultSize(width: 550, height: 450)
        .defaultLaunchBehavior(.suppressed)
    }

    private func setDockVisible(_ visible: Bool) {
        NSApplication.shared.setActivationPolicy(visible ? .regular : .accessory)
        if visible {
            NSApplication.shared.activate()
        }
    }

    private func hideDockIfNoWindows() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let hasVisibleWindow = NSApplication.shared.windows.contains { window in
                window.isVisible && !window.className.contains("StatusBar") && !window.className.contains("MenuBar")
            }
            if !hasVisibleWindow {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        switch timerService.state {
        case .idle:
            Image(systemName: "figure.run")
        case .running, .paused:
            if showTimerInMenuBar {
                Text(timerService.displayString)
            } else {
                Image(systemName: "figure.run")
            }
        case .exerciseTime:
            Image(systemName: "figure.run")
                .symbolEffect(.pulse)
        }
    }
}
