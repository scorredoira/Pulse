import SwiftUI
import SwiftData

@main
struct PulseApp: App {
    @State private var timerService = TimerService()
    @State private var exerciseSessionService = ExerciseSessionService()
    @State private var audioService = AudioGuidanceService()
    @State private var healthKitService = HealthKitService()
    @State private var routineFileService = RoutineFileService()
    @State private var screenActivityService: ScreenActivityService?
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar = false
    @AppStorage("autoStartTimers") private var autoStartTimers = true
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
                    let service = ScreenActivityService(timerService: timerService)
                    service.startMonitoring()
                    screenActivityService = service
                }
            }
            .onChange(of: exerciseSessionService.state) {
                switch exerciseSessionService.state {
                case .preparing, .running, .paused, .waitingToStart:
                    screenActivityService?.preventSleep()
                case .idle, .completed:
                    screenActivityService?.allowSleep()
                }
            }
        } label: {
            menuBarLabel
                .task {
                    setupTimerCallback()
                    autoStartIfNeeded()
                }
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
            SettingsView(healthKitService: healthKitService, routineFileService: routineFileService)
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

    // MARK: - Auto-start & timer callback

    private func autoStartIfNeeded() {
        guard autoStartTimers, timerService.state == .idle else { return }
        let descriptor = FetchDescriptor<Routine>(predicate: #Predicate<Routine> { $0.isActive == true })
        guard let routines = try? container.mainContext.fetch(descriptor) else { return }
        let timers = routines.filter { !$0.exercises.isEmpty }.map { r in
            (id: r.name, name: r.name, intervalMinutes: r.intervalMinutes)
        }
        guard !timers.isEmpty else { return }
        timerService.startAll(routines: timers)
    }

    private func setupTimerCallback() {
        timerService.onRoutineTimerComplete = { [self] routineId in
            // Load audio settings before playing alerts
            let settingsDescriptor = FetchDescriptor<AppSettings>()
            if let settings = try? container.mainContext.fetch(settingsDescriptor).first {
                audioService.soundEnabled = settings.soundEnabled
                audioService.voiceGuidanceEnabled = settings.voiceGuidanceEnabled
                audioService.repCountingEnabled = settings.repCountingEnabled
                audioService.speechRate = settings.speechRate
                audioService.speechVolume = settings.speechVolume
            }

            audioService.announceWorkIntervalComplete()
            audioService.playBeep()
            startExerciseFromApp(routineId: routineId)
        }
    }

    private func startExerciseFromApp(routineId: String) {
        let descriptor = FetchDescriptor<Routine>(predicate: #Predicate<Routine> { $0.isActive == true })
        guard let routines = try? container.mainContext.fetch(descriptor),
              let routine = routines.first(where: { $0.name == routineId }),
              !routine.sortedExercises.isEmpty else { return }

        let exercises = routine.sortedExercises

        exerciseSessionService.onSessionComplete = { logs in
            let session = WorkSession(
                startDate: Date().addingTimeInterval(-Double(logs.reduce(0) { $0 + $1.durationSeconds })),
                endDate: .now,
                workIntervalMinutes: routine.intervalMinutes,
                wasCompleted: true,
                exerciseLogs: logs
            )
            container.mainContext.insert(session)
            timerService.restartAndResumeOthers(routineId: routineId, newIntervalMinutes: routine.intervalMinutes)
        }

        exerciseSessionService.onSessionCancel = {
            timerService.restartAndResumeOthers(routineId: routineId, newIntervalMinutes: routine.intervalMinutes)
        }

        exerciseSessionService.onPostpone = { minutes in
            timerService.snooze(seconds: minutes * 60)
        }

        exerciseSessionService.startSession(with: exercises, audioService: audioService)

        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.regular)
            openWindow(id: Constants.WindowID.exerciseSession)
            NSApplication.shared.activate()
        }

        // Ensure the window is fully in front after it renders
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            bringExerciseWindowToFront()
        }
    }

    private func bringExerciseWindowToFront() {
        for window in NSApplication.shared.windows {
            if window.title == "Exercise Session" {
                window.level = .statusBar
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
        NSApplication.shared.activate()
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
