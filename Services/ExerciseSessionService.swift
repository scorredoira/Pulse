import Foundation
import SwiftData

enum ExerciseSessionState {
    case idle
    case running
    case paused
    case completed
}

enum ExercisePhase {
    case exercise
    case restBetweenSets
    case restAfterExercise
}

@Observable
final class ExerciseSessionService {
    var state: ExerciseSessionState = .idle
    var phase: ExercisePhase = .exercise
    var currentExerciseIndex: Int = 0
    var currentSet: Int = 1
    var remainingSeconds: Int = 0
    var exercises: [Exercise] = []
    var completedLogs: [ExerciseLog] = []

    var currentExercise: Exercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var currentPhaseDuration: Int {
        guard let exercise = currentExercise else { return 0 }
        switch phase {
        case .exercise: return exercise.durationSeconds
        case .restBetweenSets: return exercise.restSeconds
        case .restAfterExercise: return exercise.restAfterSeconds
        }
    }

    var phaseProgress: Double {
        let total = currentPhaseDuration
        guard total > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(total))
    }

    var totalExercises: Int { exercises.count }

    var audioService: AudioGuidanceService?
    var onSessionComplete: (([ExerciseLog]) -> Void)?
    var onSessionCancel: (() -> Void)?

    private var timer: Timer?

    func startSession(with exercises: [Exercise], audioService: AudioGuidanceService) {
        self.exercises = exercises
        self.audioService = audioService
        self.completedLogs = []
        self.currentExerciseIndex = 0
        self.currentSet = 1
        self.phase = .exercise
        self.state = .running

        announceAndStartExercise()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        stopTimer()
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        startTimer()
    }

    func skipCurrentExercise() {
        stopTimer()
        guard let exercise = currentExercise else { return }

        let log = ExerciseLog(
            exerciseName: exercise.name,
            durationSeconds: exercise.durationSeconds - remainingSeconds,
            skipped: true
        )
        completedLogs.append(log)

        currentSet = 1
        moveToNextExercise()
    }

    func cancelSession() {
        stopTimer()
        state = .idle
        exercises = []
        completedLogs = []
        currentSet = 1
        phase = .exercise
        audioService?.stop()
        onSessionCancel?()
    }

    // MARK: - Flow

    private func announceAndStartExercise() {
        guard let exercise = currentExercise else {
            finishSession()
            return
        }

        phase = .exercise
        remainingSeconds = exercise.durationSeconds

        if exercise.sets > 1 {
            audioService?.announceExerciseWithSets(
                name: exercise.name,
                duration: exercise.durationSeconds,
                set: currentSet,
                totalSets: exercise.sets
            )
        } else {
            audioService?.announceExercise(name: exercise.name, duration: exercise.durationSeconds)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.audioService?.playTransitionBeep()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startTimer()
            }
        }
    }

    private func startRestBetweenSets() {
        guard let exercise = currentExercise else { return }

        phase = .restBetweenSets
        remainingSeconds = exercise.restSeconds

        audioService?.announceRest(duration: exercise.restSeconds)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.startTimer()
        }
    }

    private func startRestAfterExercise() {
        guard let exercise = currentExercise else { return }
        guard exercise.restAfterSeconds > 0 else {
            moveToNextExercise()
            return
        }

        phase = .restAfterExercise
        remainingSeconds = exercise.restAfterSeconds

        audioService?.announceRest(duration: exercise.restAfterSeconds)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.startTimer()
        }
    }

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
        guard state == .running else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1

            let r = remainingSeconds
            if r == 10 {
                audioService?.announceCountdown(r)
            } else if r <= 5 && r > 0 {
                audioService?.announceCountdown(r)
            }

            if r == 0 {
                stopTimer()
                handlePhaseComplete()
            }
        }
    }

    private func handlePhaseComplete() {
        guard let exercise = currentExercise else { return }

        switch phase {
        case .exercise:
            audioService?.playTransitionBeep()

            let log = ExerciseLog(
                exerciseName: exercise.name,
                durationSeconds: exercise.durationSeconds
            )
            completedLogs.append(log)

            if currentSet < exercise.sets {
                startRestBetweenSets()
            } else {
                audioService?.announceExerciseComplete()
                currentSet = 1

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.startRestAfterExercise()
                }
            }

        case .restBetweenSets:
            currentSet += 1
            audioService?.playTransitionBeep()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.announceAndStartExercise()
            }

        case .restAfterExercise:
            audioService?.playTransitionBeep()
            moveToNextExercise()
        }
    }

    private func moveToNextExercise() {
        currentExerciseIndex += 1
        currentSet = 1
        if currentExerciseIndex >= exercises.count {
            finishSession()
        } else {
            announceAndStartExercise()
        }
    }

    private func finishSession() {
        stopTimer()
        state = .completed

        let totalMinutes = completedLogs
            .filter { !$0.skipped }
            .reduce(0) { $0 + $1.durationSeconds } / 60
        let exerciseCount = completedLogs.filter { !$0.skipped }.count

        audioService?.announceSessionComplete(totalExercises: exerciseCount, totalMinutes: max(1, totalMinutes))
        onSessionComplete?(completedLogs)
    }
}
