import SwiftUI
import SwiftData

struct MenuBarContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query private var settings: [AppSettings]
    @Query(filter: #Predicate<Routine> { $0.isActive == true }) private var activeRoutines: [Routine]
    @Query(sort: \Routine.sortOrder) private var allRoutines: [Routine]

    var timerService: TimerService
    var exerciseSessionService: ExerciseSessionService
    var audioService: AudioGuidanceService
    var healthKitService: HealthKitService

    @State private var exerciseRoutineId: String?

    private var appSettings: AppSettings? { settings.first }

    private var exerciseRoutine: Routine? {
        guard let routineId = exerciseRoutineId ?? timerService.activeExerciseRoutineId else { return nil }
        return activeRoutines.first { $0.name == routineId }
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            if timerService.state == .exerciseTime {
                exerciseTimePrompt
            } else {
                // Timer display
                timerDisplaySection

                // Quick actions
                QuickActionsView(
                    timerState: timerService.state,
                    onStart: startTimers,
                    onPause: { timerService.pause() },
                    onResume: { timerService.resume() },
                    onSkip: { timerService.skip() },
                    onReset: { timerService.reset() },
                    onRestart: startTimers
                )

                // Start exercises / Show exercise window
                if exerciseSessionService.state == .running || exerciseSessionService.state == .paused {
                    Button {
                        NSApplication.shared.activate()
                        openWindow(id: Constants.WindowID.exerciseSession)
                    } label: {
                        Label("Show Exercise Window", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(WidePillButtonStyle(color: .accentColor))
                } else {
                    VStack(spacing: Spacing.xs) {
                        let availableRoutines = allRoutines.filter { !$0.exercises.isEmpty }
                        let defaultRoutine = activeRoutines.first(where: { $0.isDefault })
                            ?? activeRoutines.first
                            ?? availableRoutines.first

                        Menu {
                            ForEach(availableRoutines, id: \.name) { routine in
                                Button {
                                    startExerciseSession(for: routine)
                                } label: {
                                    Text(routine.name)
                                }
                            }
                        } label: {
                            Label("Start Exercises", systemImage: "figure.run")
                        } primaryAction: {
                            startExerciseSession(for: defaultRoutine)
                        }
                        .buttonStyle(WidePillButtonStyle())
                        .disabled(availableRoutines.isEmpty)

                        if let routine = defaultRoutine {
                            Text("\(routine.name) — \(TimeFormatting.formatMinutesSeconds(routine.totalDurationSeconds))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Bottom buttons
            HStack {
                Button {
                    NSApplication.shared.activate()
                    openWindow(id: Constants.WindowID.dashboard)
                } label: {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .buttonStyle(IconButtonStyle())

                Spacer()

                Button {
                    NSApplication.shared.activate()
                    openWindow(id: Constants.WindowID.settings)
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(IconButtonStyle())

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .foregroundStyle(.red)
                }
                .buttonStyle(IconButtonStyle())
            }
        }
        .padding(Spacing.lg)
        .frame(width: 350)
        .background(.ultraThinMaterial)
        .onAppear {
            setupTimerCallback()
        }
    }

    // MARK: - Timer display

    @ViewBuilder
    private var timerDisplaySection: some View {
        let runningTimers = timerService.routineTimers.filter { $0.state == .running || $0.state == .paused }

        if runningTimers.count <= 1 {
            // Single timer: use the circular display
            TimerDisplayView(
                remainingSeconds: timerService.remainingSeconds,
                totalSeconds: timerService.totalSeconds,
                progress: timerService.progress,
                state: timerService.state
            )
        } else {
            // Multiple timers: compact rows
            VStack(spacing: Spacing.sm) {
                ForEach(timerService.routineTimers.filter { $0.state == .running || $0.state == .paused }) { rt in
                    CompactTimerRow(routineTimer: rt) {
                        let interval = activeRoutines.first(where: { $0.name == rt.id })?.intervalMinutes
                        timerService.restartRoutine(routineId: rt.id, newIntervalMinutes: interval)
                    }
                }
            }
        }
    }

    // MARK: - Exercise time prompt

    private var exerciseTimePrompt: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "figure.run")
                .font(.system(size: 32))
                .foregroundStyle(.accent)
                .symbolEffect(.bounce)

            Text("Exercise Time!")
                .font(.headline)

            if exerciseSessionService.state != .idle {
                Button {
                    NSApplication.shared.activate()
                    openWindow(id: Constants.WindowID.exerciseSession)
                } label: {
                    Label("Show Exercise Window", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(WidePillButtonStyle(color: .accentColor))
            }

            Button {
                skipExercises()
            } label: {
                Label("Skip", systemImage: "forward.end.fill")
            }
            .buttonStyle(PillButtonStyle(color: .secondary))
        }
    }

    // MARK: - Actions

    private func startTimers() {
        let routines = activeRoutines.filter { !$0.exercises.isEmpty }.map { routine in
            (id: routine.name, name: routine.name, intervalMinutes: routine.intervalMinutes)
        }
        guard !routines.isEmpty else { return }
        timerService.startAll(routines: routines)
    }

    private func setupTimerCallback() {
        timerService.onRoutineTimerComplete = { [self] routineId in
            exerciseRoutineId = routineId
            audioService.announceWorkIntervalComplete()
            audioService.playBeep()
            // Start exercise session immediately — no countdown, no notification
            let routine = activeRoutines.first { $0.name == routineId }
            startExerciseSession(for: routine)
        }

        NotificationService.shared.onStartExercise = { [self] in
            startExerciseSession(for: exerciseRoutine)
        }

        NotificationService.shared.onSnooze = { [self] minutes in
            snoozeExercises(minutes: minutes)
        }

        NotificationService.shared.onSkip = { [self] in
            guard let routineId = timerService.activeExerciseRoutineId else { return }
            let interval = activeRoutines.first(where: { $0.name == routineId })?.intervalMinutes
            timerService.restartAndResumeOthers(routineId: routineId, newIntervalMinutes: interval)
        }
    }

    private func skipExercises() {
        guard let routineId = timerService.activeExerciseRoutineId else { return }
        let interval = activeRoutines.first(where: { $0.name == routineId })?.intervalMinutes
        timerService.restartAndResumeOthers(routineId: routineId, newIntervalMinutes: interval)
        exerciseRoutineId = nil
    }

    private func snoozeExercises(minutes: Int) {
        timerService.snooze(seconds: minutes * 60)
        exerciseRoutineId = nil
        NotificationService.shared.sendSnoozeConfirmation(minutes: minutes)
    }

    private func startExerciseSession(for routine: Routine?) {
        guard let routine else {
            print("[Pulse] No routine found for exercise session")
            return
        }
        let exercises = routine.sortedExercises
        guard !exercises.isEmpty else {
            print("[Pulse] Routine '\(routine.name)' has no exercises")
            return
        }

        let routineId = routine.name
        print("[Pulse] Starting session with \(exercises.count) exercises from '\(routine.name)'")

        // Configure audio from settings
        if let settings = appSettings {
            audioService.soundEnabled = settings.soundEnabled
            audioService.voiceGuidanceEnabled = settings.voiceGuidanceEnabled
            audioService.speechRate = settings.speechRate
            audioService.speechVolume = settings.speechVolume
        }

        exerciseSessionService.onSessionComplete = { logs in
            saveSession(logs: logs, routineId: routineId)
            let interval = activeRoutines.first(where: { $0.name == routineId })?.intervalMinutes
            timerService.restartAndResumeOthers(routineId: routineId, newIntervalMinutes: interval)
            exerciseRoutineId = nil
        }

        exerciseSessionService.onSessionCancel = {
            let interval = activeRoutines.first(where: { $0.name == routineId })?.intervalMinutes
            timerService.restartAndResumeOthers(routineId: routineId, newIntervalMinutes: interval)
            exerciseRoutineId = nil
        }

        exerciseSessionService.onPostpone = { [self] minutes in
            snoozeExercises(minutes: minutes)
        }

        exerciseSessionService.startSession(with: exercises, audioService: audioService)

        DispatchQueue.main.async {
            NSApplication.shared.activate()
            openWindow(id: Constants.WindowID.exerciseSession)
        }
    }

    private func saveSession(logs: [ExerciseLog], routineId: String) {
        let routine = activeRoutines.first { $0.name == routineId }
        let session = WorkSession(
            startDate: Date().addingTimeInterval(-Double(logs.reduce(0) { $0 + $1.durationSeconds })),
            endDate: .now,
            workIntervalMinutes: routine?.intervalMinutes ?? Constants.defaultWorkIntervalMinutes,
            wasCompleted: true,
            exerciseLogs: logs
        )
        modelContext.insert(session)

        // Log to HealthKit if enabled
        if appSettings?.healthKitEnabled == true {
            Task {
                for log in logs where !log.skipped {
                    let success = await healthKitService.logWorkout(
                        activityType: 13, // functionalStrengthTraining default
                        duration: Double(log.durationSeconds),
                        startDate: log.completedAt.addingTimeInterval(-Double(log.durationSeconds))
                    )
                    if success {
                        log.healthKitSynced = true
                    }
                }
            }
        }
    }
}
