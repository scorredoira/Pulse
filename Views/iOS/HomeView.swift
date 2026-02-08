import SwiftUI
import SwiftData
import UserNotifications

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query(filter: #Predicate<Routine> { $0.isActive == true }) private var activeRoutines: [Routine]

    var timerService: TimerService
    var exerciseSessionService: ExerciseSessionService
    var audioService: AudioGuidanceService
    var healthKitService: HealthKitService

    @Environment(\.scenePhase) private var scenePhase

    @State private var showExerciseSession = false
    @State private var autoStartCountdown: Int = 5
    @State private var exerciseRoutineId: String?

    private var appSettings: AppSettings? { settings.first }

    private var exerciseRoutine: Routine? {
        guard let routineId = exerciseRoutineId ?? timerService.activeExerciseRoutineId else { return nil }
        return activeRoutines.first { $0.name == routineId }
    }

    var body: some View {
        TabView {
            timerTab
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            SettingsView(healthKitService: healthKitService)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .fullScreenCover(isPresented: $showExerciseSession) {
            ExerciseSessionView(sessionService: exerciseSessionService)
        }
        .onAppear {
            setupTimerCallback()
        }
        .onChange(of: exerciseSessionService.state) {
            if exerciseSessionService.state == .idle || exerciseSessionService.state == .completed {
                showExerciseSession = false
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                timerService.handleEnteredBackground()
                scheduleTimerNotifications()
            } else if newPhase == .active && oldPhase == .background {
                timerService.handleEnteredForeground()
                cancelTimerNotifications()
            }
        }
    }

    // MARK: - Timer Tab

    private var timerTab: some View {
        VStack(spacing: 0) {
            Spacer()

            if timerService.state == .exerciseTime {
                exerciseTimePrompt
            } else {
                timerDisplaySection
                    .padding(.bottom, 32)

                QuickActionsView(
                    timerState: timerService.state,
                    onStart: startTimers,
                    onPause: { timerService.pause() },
                    onResume: { timerService.resume() },
                    onSkip: { timerService.skip() },
                    onReset: { timerService.reset() },
                    onRestart: { timerService.restartAll() }
                )
                .padding(.bottom, 40)

                if exerciseSessionService.state == .running || exerciseSessionService.state == .paused {
                    Button {
                        showExerciseSession = true
                    } label: {
                        Label("Show Exercise Session", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(WidePillButtonStyle(color: .accentColor))
                    .padding(.horizontal)
                } else {
                    VStack(spacing: Spacing.sm) {
                        Button {
                            startExerciseSession(for: activeRoutines.first(where: { $0.isDefault }) ?? activeRoutines.first)
                        } label: {
                            Label("Start Exercises", systemImage: "figure.run")
                        }
                        .buttonStyle(WidePillButtonStyle())
                        .padding(.horizontal)
                        .disabled(activeRoutines.isEmpty)

                        if let routine = activeRoutines.first(where: { $0.isDefault }) ?? activeRoutines.first,
                           !routine.exercises.isEmpty {
                            Text("\(routine.name) — \(TimeFormatting.formatMinutesSeconds(routine.totalDurationSeconds))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
            Spacer()
        }
        .padding()
    }

    // MARK: - Timer display

    @ViewBuilder
    private var timerDisplaySection: some View {
        let runningTimers = timerService.routineTimers.filter { $0.state == .running || $0.state == .paused }

        if runningTimers.count <= 1 {
            TimerDisplayView(
                remainingSeconds: timerService.remainingSeconds,
                totalSeconds: timerService.totalSeconds,
                progress: timerService.progress,
                state: timerService.state
            )
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(timerService.routineTimers.filter { $0.state == .running || $0.state == .paused }) { rt in
                    CompactTimerRow(routineTimer: rt) {
                        timerService.restartRoutine(routineId: rt.id)
                    }
                }
            }
        }
    }

    // MARK: - Exercise time prompt

    private var exerciseTimePrompt: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundStyle(.accent)
                .symbolEffect(.bounce)

            Text("Time to Move!")
                .font(.title2.bold())

            if let routine = exerciseRoutine, !routine.exercises.isEmpty {
                Text("\(routine.name) — \(TimeFormatting.formatMinutesSeconds(routine.totalDurationSeconds))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Starting in \(autoStartCountdown)...")
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.green)
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: autoStartCountdown)

            HStack(spacing: Spacing.sm) {
                postponeButton(minutes: 1)
                postponeButton(minutes: 2)
                postponeButton(minutes: 5)
            }

            Button {
                skipExercises()
            } label: {
                Label("Skip", systemImage: "forward.end.fill")
            }
            .buttonStyle(PillButtonStyle(color: .secondary))
        }
        .task {
            autoStartCountdown = 5
            for i in (0..<5).reversed() {
                try? await Task.sleep(for: .seconds(1))
                autoStartCountdown = i
            }
            startExerciseSession(for: exerciseRoutine)
        }
    }

    private func postponeButton(minutes: Int) -> some View {
        Button {
            snoozeExercises(minutes: minutes)
        } label: {
            Text("+\(minutes) min")
        }
        .buttonStyle(PillButtonStyle(color: .orange))
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
        timerService.onRoutineTimerComplete = { routineId in
            exerciseRoutineId = routineId
            NotificationService.shared.sendExerciseReminder()
            audioService.announceWorkIntervalComplete()
            audioService.playBeep()
        }

        NotificationService.shared.onStartExercise = {
            startExerciseSession(for: exerciseRoutine)
        }

        NotificationService.shared.onSnooze = { minutes in
            snoozeExercises(minutes: minutes)
        }

        NotificationService.shared.onSkip = {
            guard let routineId = timerService.activeExerciseRoutineId else { return }
            timerService.restartAndResumeOthers(routineId: routineId)
        }
    }

    private func skipExercises() {
        guard let routineId = timerService.activeExerciseRoutineId else { return }
        timerService.restartAndResumeOthers(routineId: routineId)
        exerciseRoutineId = nil
    }

    private func snoozeExercises(minutes: Int) {
        timerService.snooze(seconds: minutes * 60)
        exerciseRoutineId = nil
        NotificationService.shared.sendSnoozeConfirmation(minutes: minutes)
    }

    private func startExerciseSession(for routine: Routine?) {
        guard let routine else { return }
        let exercises = routine.sortedExercises
        guard !exercises.isEmpty else { return }

        let routineId = routine.name

        if let settings = appSettings {
            audioService.soundEnabled = settings.soundEnabled
            audioService.voiceGuidanceEnabled = settings.voiceGuidanceEnabled
            audioService.speechRate = settings.speechRate
            audioService.speechVolume = settings.speechVolume
        }

        exerciseSessionService.onSessionComplete = { logs in
            saveSession(logs: logs, routineId: routineId)
            timerService.restartAndResumeOthers(routineId: routineId)
            exerciseRoutineId = nil
        }

        exerciseSessionService.onSessionCancel = {
            timerService.restartAndResumeOthers(routineId: routineId)
            exerciseRoutineId = nil
        }

        exerciseSessionService.startSession(with: exercises, audioService: audioService)
        showExerciseSession = true
    }

    // MARK: - Background timer notifications

    private func scheduleTimerNotifications() {
        let center = UNUserNotificationCenter.current()
        for rt in timerService.routineTimers where rt.state == .running && rt.remainingSeconds > 0 {
            let content = UNMutableNotificationContent()
            content.title = "Time to Move!"
            content.body = "\(rt.routineName) timer completed."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: Double(rt.remainingSeconds),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "timer-\(rt.id)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    private func cancelTimerNotifications() {
        let ids = timerService.routineTimers.map { "timer-\($0.id)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
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

        if appSettings?.healthKitEnabled == true {
            Task {
                for log in logs where !log.skipped {
                    let success = await healthKitService.logWorkout(
                        activityType: 13,
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
