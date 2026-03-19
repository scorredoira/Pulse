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
    @State private var currentRoutineIndex = 0
    @State private var autoStartCountdown: Int = 5
    @State private var exerciseRoutineId: String?

    // Inline exercise timer
    @State private var inlineExerciseID: PersistentIdentifier?
    @State private var inlineSeconds: Int = 0
    @State private var inlinePaused: Bool = false
    @State private var inlineSet: Int = 1
    @State private var inlineTotalSets: Int = 1
    @State private var inlineSetDuration: Int = 0

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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard inlineExerciseID != nil, !inlinePaused else { return }
            if inlineSeconds > 1 {
                inlineSeconds -= 1
            } else if inlineSet < inlineTotalSets {
                inlineSet += 1
                inlineSeconds = inlineSetDuration
            } else {
                inlineExerciseID = nil
            }
        }
        .onChange(of: exerciseSessionService.state) {
            switch exerciseSessionService.state {
            case .preparing, .running, .paused, .waitingToStart, .completed:
                UIApplication.shared.isIdleTimerDisabled = exerciseSessionService.state != .completed
            case .idle:
                UIApplication.shared.isIdleTimerDisabled = false
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
                VStack(spacing: 0) {
                    // Active exercise session banner
                    if exerciseSessionService.state == .running || exerciseSessionService.state == .paused || exerciseSessionService.state == .waitingToStart {
                        Button {
                            showExerciseSession = true
                        } label: {
                            Label("Resume Exercise Session", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(WidePillButtonStyle(color: .green))
                        .padding()
                    }

                    // Timer section (when timers are running)
                    if timerService.state != .idle {
                        timerSection
                    }

                    // Swipeable routine pages
                    if allRoutines.isEmpty {
                        VStack(spacing: Spacing.md) {
                            Spacer()
                            Image(systemName: "figure.run")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No routines yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Create routines in Settings")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        routinePager
                    }
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

    // MARK: - Routine Pager

    private var routinePager: some View {
        TabView(selection: $currentRoutineIndex) {
            ForEach(Array(allRoutines.enumerated()), id: \.element.id) { index, routine in
                routinePage(routine)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .onChange(of: allRoutines.count) {
            if currentRoutineIndex >= allRoutines.count {
                currentRoutineIndex = max(0, allRoutines.count - 1)
            }
        }
    }

    private func routinePage(_ routine: Routine) -> some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header: routine name + voice toggle
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(routine.name)
                            .font(.largeTitle.bold())
                        HStack(spacing: Spacing.sm) {
                            Text("\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")")
                            if routine.isActive {
                                Text("·")
                                Text("every \(routine.intervalMinutes) min")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    voiceToggle
                }

                // Exercises
                ForEach(routine.sortedExercises) { exercise in
                    exerciseCard(exercise, routine: routine)
                }
            }
            .padding()
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func exerciseCard(_ exercise: Exercise, routine: Routine) -> some View {
        let isRunning = exercise.persistentModelID == inlineExerciseID

        VStack(spacing: Spacing.md) {
            if !exercise.imageFileNames.isEmpty {
                ExerciseImageView(
                    imageFileNames: exercise.imageFileNames,
                    isAnimating: isRunning,
                    maxImageHeight: 200
                )
            } else {
                Image(systemName: exercise.iconName)
                    .font(.system(size: 44))
                    .foregroundStyle(.accent)
                    .frame(width: 80, height: 80)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            }

            Text(exercise.name)
                .font(.title2.bold())

            if isRunning {
                VStack(spacing: Spacing.sm) {
                    Text(TimeFormatting.formatSeconds(inlineSeconds))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(inlineSeconds <= 5 ? .red : inlineSeconds <= 10 ? .orange : .primary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: inlineSeconds)

                    if inlineTotalSets > 1 {
                        Text("Set \(inlineSet) of \(inlineTotalSets)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: Spacing.md) {
                    Button {
                        inlinePaused.toggle()
                    } label: {
                        Label(inlinePaused ? "Resume" : "Pause",
                              systemImage: inlinePaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(PillButtonStyle(color: inlinePaused ? .green : .orange))

                    Button {
                        inlineExerciseID = nil
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(PillButtonStyle(color: .red))
                }
            } else {
                HStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.xs) {
                        if exercise.reps > 0 {
                            Text("\(exercise.reps)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text("reps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(TimeFormatting.formatSeconds(exercise.durationSeconds))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text("duration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: Spacing.xs) {
                        Text("\(exercise.sets)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text(exercise.sets == 1 ? "set" : "sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    inlineExerciseID = exercise.persistentModelID
                    inlineSetDuration = exercise.effectiveDurationSeconds
                    inlineSeconds = exercise.effectiveDurationSeconds
                    inlineSet = 1
                    inlineTotalSets = exercise.sets
                    inlinePaused = false
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(WidePillButtonStyle(color: .green))
                .disabled(inlineExerciseID != nil)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var voiceToggle: some View {
        Button {
            appSettings?.voiceGuidanceEnabled.toggle()
        } label: {
            Image(systemName: appSettings?.voiceGuidanceEnabled == true ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.title2)
                .foregroundStyle(appSettings?.voiceGuidanceEnabled == true ? .accent : .secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
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
            audioService.repCountingEnabled = settings.repCountingEnabled
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

        exerciseSessionService.startSession(with: exercises, audioService: audioService, manualExerciseStart: routine.manualExerciseStart)
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
