import SwiftUI

struct ExerciseCompleteView: View {
    let logs: [ExerciseLog]
    let onDismiss: () -> Void

    private var completedLogs: [ExerciseLog] {
        logs.filter { !$0.skipped }
    }

    private var skippedLogs: [ExerciseLog] {
        logs.filter { $0.skipped }
    }

    private var totalSeconds: Int {
        completedLogs.reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            // Celebration
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green.gradient)
                .symbolEffect(.bounce)

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            // Stats
            HStack(spacing: 32) {
                statItem(
                    value: "\(completedLogs.count)",
                    label: "Exercises",
                    icon: "figure.run"
                )

                statItem(
                    value: TimeFormatting.formatMinutesSeconds(totalSeconds),
                    label: "Duration",
                    icon: "clock.fill"
                )

                if !skippedLogs.isEmpty {
                    statItem(
                        value: "\(skippedLogs.count)",
                        label: "Skipped",
                        icon: "forward.fill"
                    )
                }
            }
            .cardStyle()

            // Exercise list
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
                    HStack {
                        Image(systemName: log.skipped ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(log.skipped ? .orange : .green)

                        Text(log.exerciseName)
                            .font(.body)

                        Spacer()

                        Text(TimeFormatting.formatMinutesSeconds(log.durationSeconds))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .cardStyle()

            Button {
                onDismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(WidePillButtonStyle(color: .accentColor))
            .controlSize(.large)
        }
        .padding(32)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent.gradient)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ExerciseCompleteView(
        logs: [
            ExerciseLog(exerciseName: "Plank", durationSeconds: 30),
            ExerciseLog(exerciseName: "Walk", durationSeconds: 300),
            ExerciseLog(exerciseName: "Stretch", durationSeconds: 60, skipped: true),
        ],
        onDismiss: {}
    )
    .frame(width: 450, height: 500)
}
