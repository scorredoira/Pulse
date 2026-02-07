import SwiftUI
import Charts

struct DailyStatsData: Identifiable {
    let id = UUID()
    let date: Date
    let exerciseCount: Int

    var dayLabel: String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
}

struct DailyStatsChart: View {
    let sessions: [WorkSession]

    private var chartData: [DailyStatsData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<14).reversed().compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!

            let count = sessions.filter { session in
                session.startDate >= date && session.startDate < nextDay && session.wasCompleted
            }.reduce(0) { $0 + $1.exerciseLogs.filter { !$0.skipped }.count }

            return DailyStatsData(date: date, exerciseCount: count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(icon: "chart.bar.fill", title: "Exercises per Day")

            Chart(chartData) { data in
                BarMark(
                    x: .value("Day", data.date, unit: .day),
                    y: .value("Exercises", data.exerciseCount)
                )
                .foregroundStyle(.accent.gradient)
                .cornerRadius(CornerRadius.small)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(.primary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(.primary.opacity(0.1))
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            #if os(iOS)
            .frame(height: 160)
            #else
            .frame(height: 200)
            #endif
        }
    }
}
