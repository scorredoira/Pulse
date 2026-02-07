import SwiftUI

struct ExerciseStepView: View {
    let exercise: Exercise
    let remainingSeconds: Int
    let progress: Double
    let exerciseNumber: Int
    let totalExercises: Int
    let currentSet: Int
    let phase: ExercisePhase

    private var isResting: Bool { phase != .exercise }

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            // Exercise counter
            Text("EXERCISE \(exerciseNumber) OF \(totalExercises)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            // Icon with circular background
            Image(systemName: isResting ? "pause.circle.fill" : exercise.iconName)
                .font(.system(size: 40))
                .foregroundStyle(isResting ? .orange : .accent)
                .frame(width: 72, height: 72)
                .background(
                    (isResting ? Color.orange : Color.accentColor)
                        .opacity(0.1)
                )
                .clipShape(Circle())
                .symbolEffect(.pulse, isActive: remainingSeconds > 0)

            // Name
            Text(isResting ? "Rest" : exercise.name)
                .font(.title)
                .fontWeight(.bold)

            // Set info or rest context
            if isResting && phase == .restBetweenSets && exercise.sets > 1 {
                Text("Next: Set \(currentSet + 1) of \(exercise.sets)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else if isResting && phase == .restAfterExercise {
                Text("Next exercise coming up...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else if !isResting && exercise.sets > 1 {
                Text("Set \(currentSet) of \(exercise.sets)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Description (only during exercise, not rest)
            if !isResting && !exercise.exerciseDescription.isEmpty {
                Text(exercise.exerciseDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Countdown ring
            ZStack {
                CircularProgressView(
                    progress: progress,
                    lineWidth: 12,
                    size: 150,
                    progressColor: countdownColor
                )

                VStack(spacing: Spacing.xs) {
                    Text(TimeFormatting.formatSeconds(remainingSeconds))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: remainingSeconds)

                    Text(isResting ? "REST" : "REMAINING")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }
            }
        }
    }

    private var countdownColor: Color {
        if isResting {
            return remainingSeconds <= 3 ? .red : .orange
        }
        if remainingSeconds <= 5 {
            return .red
        } else if remainingSeconds <= 10 {
            return .orange
        }
        return .accentColor
    }
}
