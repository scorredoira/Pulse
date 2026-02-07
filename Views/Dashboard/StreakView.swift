import SwiftUI

struct StreakView: View {
    let sessions: [WorkSession]

    private var currentStreak: Int {
        calculateStreak(from: .now)
    }

    private var bestStreak: Int {
        calculateBestStreak()
    }

    private var todayCompleted: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return sessions.filter { session in
            session.startDate >= today && session.startDate < tomorrow && session.wasCompleted
        }.count
    }

    var body: some View {
        HStack(spacing: cardSpacing) {
            streakCard(
                title: "Current Streak",
                value: "\(currentStreak)",
                unit: "days",
                icon: "flame.fill",
                color: currentStreak > 0 ? .orange : .secondary
            )

            streakCard(
                title: "Best Streak",
                value: "\(bestStreak)",
                unit: "days",
                icon: "trophy.fill",
                color: .yellow
            )

            streakCard(
                title: "Today",
                value: "\(todayCompleted)",
                unit: "sessions",
                icon: "checkmark.circle.fill",
                color: todayCompleted > 0 ? .green : .secondary
            )
        }
    }

    #if os(iOS)
    private let cardSpacing: CGFloat = Spacing.sm
    #else
    private let cardSpacing: CGFloat = Spacing.xl
    #endif

    private func streakCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color.gradient)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func calculateStreak(from date: Date) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: date)

        while true {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!
            let hasSession = sessions.contains { session in
                session.startDate >= checkDate && session.startDate < nextDay && session.wasCompleted
            }

            if hasSession {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else if calendar.isDateInToday(checkDate) {
                // Today might not have a session yet, check yesterday
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return streak
    }

    private func calculateBestStreak() -> Int {
        let calendar = Calendar.current
        let sortedDates = Set(sessions.filter { $0.wasCompleted }.map { calendar.startOfDay(for: $0.startDate) })
            .sorted()

        guard !sortedDates.isEmpty else { return 0 }

        var best = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i - 1], to: sortedDates[i]).day ?? 0
            if diff == 1 {
                current += 1
                best = max(best, current)
            } else if diff > 1 {
                current = 1
            }
        }

        return best
    }
}
