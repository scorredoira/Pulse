import SwiftUI

struct ExerciseHistoryList: View {
    let sessions: [WorkSession]

    private var sortedSessions: [WorkSession] {
        sessions
            .filter { $0.wasCompleted }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(icon: "clock.arrow.circlepath", title: "History")

            if sortedSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "clock",
                    description: Text("Complete an exercise session to see it here.")
                )
                .frame(height: 150)
            } else {
                #if os(iOS)
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(sortedSessions.prefix(20), id: \.startDate) { session in
                        sessionRow(session)
                    }
                }
                #else
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(sortedSessions, id: \.startDate) { session in
                            sessionRow(session)
                        }
                    }
                }
                .frame(maxHeight: 300)
                #endif
            }
        }
    }

    private func sessionRow(_ session: WorkSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)

                let completedCount = session.exerciseLogs.filter { !$0.skipped }.count
                let totalCount = session.exerciseLogs.count
                Text("\(completedCount)/\(totalCount) exercises completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(TimeFormatting.formatMinutesSeconds(session.totalExerciseSeconds))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.accent)

                Text("\(session.workIntervalMinutes)min interval")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
}
