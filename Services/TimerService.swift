import Foundation

enum TimerState {
    case idle
    case running
    case paused
    case exerciseTime
}

struct RoutineTimer: Identifiable {
    let id: String
    let routineName: String
    var remainingSeconds: Int
    var totalSeconds: Int
    var state: TimerState

    var displayString: String {
        TimeFormatting.formatSeconds(remainingSeconds)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }
}

@Observable
final class TimerService {
    var routineTimers: [RoutineTimer] = []
    var activeExerciseRoutineId: String?

    var onRoutineTimerComplete: ((String) -> Void)?

    var state: TimerState {
        if routineTimers.contains(where: { $0.state == .exerciseTime }) {
            return .exerciseTime
        }
        if routineTimers.contains(where: { $0.state == .running }) {
            return .running
        }
        if routineTimers.contains(where: { $0.state == .paused }) {
            return .paused
        }
        return .idle
    }

    var nearestTimer: RoutineTimer? {
        routineTimers
            .filter { $0.state == .running }
            .min { $0.remainingSeconds < $1.remainingSeconds }
    }

    var displayString: String {
        nearestTimer?.displayString ?? TimeFormatting.formatSeconds(0)
    }

    var progress: Double {
        nearestTimer?.progress ?? 0
    }

    var remainingSeconds: Int {
        nearestTimer?.remainingSeconds ?? 0
    }

    var totalSeconds: Int {
        nearestTimer?.totalSeconds ?? 0
    }

    var isRunning: Bool { state == .running }

    private var timer: Timer?
    private var backgroundDate: Date?

    // MARK: - Background/Foreground (iOS)

    func handleEnteredBackground() {
        guard routineTimers.contains(where: { $0.state == .running }) else { return }
        backgroundDate = Date()
        stopTimer()
    }

    func handleEnteredForeground() {
        guard let bgDate = backgroundDate else { return }
        backgroundDate = nil

        let elapsed = Int(Date().timeIntervalSince(bgDate))
        guard elapsed > 0 else {
            if routineTimers.contains(where: { $0.state == .running }) {
                startTimer()
            }
            return
        }

        var completedId: String?

        for i in routineTimers.indices where routineTimers[i].state == .running {
            routineTimers[i].remainingSeconds -= elapsed
            if routineTimers[i].remainingSeconds <= 0 {
                routineTimers[i].remainingSeconds = 0
                routineTimers[i].state = .exerciseTime
                completedId = routineTimers[i].id
            }
        }

        if let completedId {
            activeExerciseRoutineId = completedId

            for i in routineTimers.indices where routineTimers[i].state == .running {
                routineTimers[i].state = .paused
            }

            onRoutineTimerComplete?(completedId)
        }

        if routineTimers.contains(where: { $0.state == .running }) {
            startTimer()
        }
    }

    // MARK: - Multi-timer API

    func startAll(routines: [(id: String, name: String, intervalMinutes: Int)]) {
        stopTimer()
        routineTimers = routines.map { routine in
            RoutineTimer(
                id: routine.id,
                routineName: routine.name,
                remainingSeconds: routine.intervalMinutes * 60,
                totalSeconds: routine.intervalMinutes * 60,
                state: .running
            )
        }
        startTimer()
    }

    func pause() {
        for i in routineTimers.indices where routineTimers[i].state == .running {
            routineTimers[i].state = .paused
        }
        if !routineTimers.contains(where: { $0.state == .running }) {
            stopTimer()
        }
    }

    func resume() {
        for i in routineTimers.indices where routineTimers[i].state == .paused {
            routineTimers[i].state = .running
        }
        if routineTimers.contains(where: { $0.state == .running }) {
            startTimer()
        }
    }

    func reset() {
        stopTimer()
        routineTimers = []
        activeExerciseRoutineId = nil
    }

    func restartAll() {
        for i in routineTimers.indices {
            routineTimers[i].remainingSeconds = routineTimers[i].totalSeconds
            routineTimers[i].state = .running
        }
        activeExerciseRoutineId = nil
        startTimer()
    }

    func skip() {
        guard let nearest = nearestTimer,
              let index = routineTimers.firstIndex(where: { $0.id == nearest.id }) else { return }
        routineTimers[index].state = .exerciseTime
        activeExerciseRoutineId = nearest.id

        // Pause all other running timers
        for i in routineTimers.indices where routineTimers[i].state == .running {
            routineTimers[i].state = .paused
        }
        if !routineTimers.contains(where: { $0.state == .running }) {
            stopTimer()
        }

        onRoutineTimerComplete?(nearest.id)
    }

    func snooze(seconds: Int) {
        guard let routineId = activeExerciseRoutineId,
              let index = routineTimers.firstIndex(where: { $0.id == routineId }) else { return }
        routineTimers[index].totalSeconds = seconds
        routineTimers[index].remainingSeconds = seconds
        routineTimers[index].state = .running
        activeExerciseRoutineId = nil

        // Resume all paused timers
        for i in routineTimers.indices where routineTimers[i].state == .paused {
            routineTimers[i].state = .running
        }
        startTimer()
    }

    func restartRoutine(routineId: String) {
        guard let index = routineTimers.firstIndex(where: { $0.id == routineId }) else { return }
        routineTimers[index].remainingSeconds = routineTimers[index].totalSeconds
        routineTimers[index].state = .running
        startTimer()
    }

    func restartAndResumeOthers(routineId: String) {
        guard let index = routineTimers.firstIndex(where: { $0.id == routineId }) else { return }
        routineTimers[index].remainingSeconds = routineTimers[index].totalSeconds
        routineTimers[index].state = .running
        activeExerciseRoutineId = nil

        // Resume all paused timers
        for i in routineTimers.indices where routineTimers[i].state == .paused {
            routineTimers[i].state = .running
        }
        startTimer()
    }

    // MARK: - Internal timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        var completedId: String?

        for i in routineTimers.indices where routineTimers[i].state == .running {
            if routineTimers[i].remainingSeconds > 0 {
                routineTimers[i].remainingSeconds -= 1
            }
            if routineTimers[i].remainingSeconds == 0 {
                routineTimers[i].state = .exerciseTime
                completedId = routineTimers[i].id
            }
        }

        if let completedId {
            activeExerciseRoutineId = completedId

            // Pause all other running timers
            for i in routineTimers.indices where routineTimers[i].state == .running {
                routineTimers[i].state = .paused
            }
            if !routineTimers.contains(where: { $0.state == .running }) {
                stopTimer()
            }

            onRoutineTimerComplete?(completedId)
        }
    }
}
