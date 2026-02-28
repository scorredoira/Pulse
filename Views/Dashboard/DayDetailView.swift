import SwiftUI

struct DayDetailView: View {
    let date: Date
    let sessions: [WorkSession]

    @Environment(\.dismiss) private var dismiss

    private var daySessions: [WorkSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return sessions
            .filter { $0.startDate >= startOfDay && $0.startDate < endOfDay && $0.wasCompleted }
            .sorted { $0.startDate < $1.startDate }
    }

    private var allExerciseLogs: [ExerciseLog] {
        daySessions.flatMap { $0.exerciseLogs }.filter { !$0.skipped }
    }

    private var totalSeconds: Int {
        allExerciseLogs.reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Summary
                    HStack(spacing: Spacing.xl) {
                        summaryItem(
                            value: "\(daySessions.count)",
                            label: daySessions.count == 1 ? "session" : "sessions",
                            icon: "checkmark.circle.fill",
                            color: daySessions.isEmpty ? .secondary : .green
                        )
                        summaryItem(
                            value: "\(allExerciseLogs.count)",
                            label: allExerciseLogs.count == 1 ? "exercise" : "exercises",
                            icon: "figure.run",
                            color: allExerciseLogs.isEmpty ? .secondary : .accent
                        )
                        summaryItem(
                            value: TimeFormatting.formatMinutesSeconds(totalSeconds),
                            label: "total",
                            icon: "clock.fill",
                            color: totalSeconds == 0 ? .secondary : .orange
                        )
                    }

                    if allExerciseLogs.isEmpty {
                        ContentUnavailableView(
                            "No Activity",
                            systemImage: "moon.zzz",
                            description: Text("No exercises completed this day.")
                        )
                        .frame(height: 150)
                    } else {
                        // Exercise list
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            SectionHeader(icon: "list.bullet", title: "Exercises")

                            ForEach(allExerciseLogs, id: \.completedAt) { log in
                                exerciseRow(log)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(date.formatted(date: .complete, time: .omitted))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private func summaryItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color.gradient)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseRow(_ log: ExerciseLog) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(log.exerciseName)
                    .font(.subheadline.weight(.medium))
                Text(log.completedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(TimeFormatting.formatMinutesSeconds(log.durationSeconds))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.accent)
        }
        .padding(Spacing.md)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }
}
