import SwiftUI
import SwiftData
import UserNotifications

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query(filter: #Predicate<Routine> { $0.isActive == true }) private var activeRoutines: [Routine]
    @Query(sort: \Routine.sortOrder) private var allRoutines: [Routine]

    var timerService: TimerService
    var exerciseSessionService: ExerciseSessionService
    var audioService: AudioGuidanceService
    var healthKitService: HealthKitService
    var routineFileService: RoutineFileService

    @Environment(\.scenePhase) private var scenePhase

    @State private var showExerciseSession = false
    @State private var showImportAlert = false
    @State private var autoStartCountdown: Int = 5
    @State private var exerciseRoutineId: String?

    private var appSettings: AppSettings? { settings.first }

    private var exerciseRoutine: Routine? {
        guard let routineId = exerciseRoutineId ?? timerService.activeExerciseRoutineId else { return nil }
        return allRoutines.first { $0.name == routineId }
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

            SettingsView(healthKitService: healthKitService, routineFileService: routineFileService)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .fullScreenCover(isPresented: $showExerciseSession) {
            ExerciseSessionView(sessionService: exerciseSessionService)
        }
        .onOpenURL { url in
            routineFileService.importRoutines(from: url, into: modelContext)
            showImportAlert = true
        }
        .alert(
            routineFileService.lastError != nil ? "Import Failed" : "Routines Imported",
            isPresented: $showImportAlert
        ) {
            Button("OK") {}
        } message: {
            Text(routineFileService.lastError ?? routineFileService.lastSuccess ?? "")
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
        Group {
            if timerService.state == .exerciseTime {
                exerciseTimePrompt
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Active exercise session banner
                        if exerciseSessionService.state == .running || exerciseSessionService.state == .paused {
                            Button {
                                showExerciseSession = true
                            } label: {
                                Label("Resume Exercise Session", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(WidePillButtonStyle(color: .green))
                            .padding(.horizontal)
                        }

                        // Timer section (when timers are running)
                        if timerService.state != .idle {
                            timerSection
                        }

                        // Routines list
                        routineListSection
                    }
                    .padding(.vertical)
                }
            }
        }
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: Spacing.md) {
            timerDisplaySection

            QuickActionsView(
                timerState: timerService.state,
                onStart: startTimers,
                onPause: { timerService.pause() },
                onResume: { timerService.resume() },
                onSkip: { timerService.skip() },
                onReset: { timerService.reset() },
                onRestart: startTimers
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Routine List

    private var routineListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Routines")
                    .font(.title2.bold())
                Spacer()
                if timerService.state == .idle && !activeRoutines.filter({ !$0.exercises.isEmpty }).isEmpty {
                    Button {
                        startTimers()
                    } label: {
                        Label("Start Timers", systemImage: "timer")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(PillButtonStyle(color: .green))
                }
            }
            .padding(.horizontal)

            if allRoutines.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No routines yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Create routines in Settings")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(allRoutines) { routine in
                        routineRow(routine)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack(spacing: Spacing.md) {
            // Icon
            Image(systemName: routine.exercises.first?.iconName ?? "figure.walk")
                .font(.title2)
                .foregroundStyle(.accent)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(routine.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    if routine.isActive {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text(routineSubtitle(routine))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Running timer indicator
            if let rt = timerService.routineTimers.first(where: { $0.id == routine.name }),
               rt.state == .running || rt.state == .paused {
                Text(rt.displayString)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(rt.state == .paused ? .orange : .accentColor)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: rt.remainingSeconds)
            }

            // Play button
            Button {
                startExerciseSession(for: routine)
            } label: {
                Image(systemName: "play.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.accent, in: Circle())
            }
            .disabled(routine.exercises.isEmpty)
            .opacity(routine.exercises.isEmpty ? 0.4 : 1)
        }
        .padding(Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func routineSubtitle(_ routine: Routine) -> String {
        let count = routine.exercises.count
        if count == 0 { return "No exercises" }
        let duration = TimeFormatting.formatMinutesSeconds(routine.totalDurationSeconds)
        var parts = ["\(count) exercise\(count == 1 ? "" : "s")", duration]
        if routine.isActive {
            parts.append("every \(routine.intervalMinutes)m")
        }
        return parts.joined(separator: " · ")
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
            let interval = activeRoutines.first(where: { $0.name == routineId })?.intervalMinutes
            timerService.restartAndResumeOthers(routineId: routineId, newIntervalMinutes: interval)
            exerciseRoutineId = nil
        }

        exerciseSessionService.onSessionCancel = {
            let interval = activeRoutines.first(where: { $0.name == routineId })?.intervalMinutes
            timerService.restartAndResumeOthers(routineId: routineId, newIntervalMinutes: interval)
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
        let routine = allRoutines.first { $0.name == routineId }
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
