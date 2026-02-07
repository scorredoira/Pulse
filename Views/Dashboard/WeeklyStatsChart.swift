import SwiftUI
import Charts

struct WeeklyStatsData: Identifiable {
    let id = UUID()
    let weekStart: Date
    let totalMinutes: Double

    var weekLabel: String {
        weekStart.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct WeeklyStatsChart: View {
    let sessions: [WorkSession]

    private var chartData: [WeeklyStatsData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<8).reversed().compactMap { weeksAgo in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: today) else { return nil }
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!

            let totalSeconds = sessions.filter { session in
                session.startDate >= weekStart && session.startDate < weekEnd && session.wasCompleted
            }.reduce(0) { $0 + $1.totalExerciseSeconds }

            return WeeklyStatsData(
                weekStart: weekStart,
                totalMinutes: Double(totalSeconds) / 60.0
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(icon: "chart.line.uptrend.xyaxis", title: "Minutes per Week")

            Chart(chartData) { data in
                AreaMark(
                    x: .value("Week", data.weekStart, unit: .weekOfYear),
                    y: .value("Minutes", data.totalMinutes)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accent.opacity(0.3), .accent.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Week", data.weekStart, unit: .weekOfYear),
                    y: .value("Minutes", data.totalMinutes)
                )
                .foregroundStyle(.accent)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Week", data.weekStart, unit: .weekOfYear),
                    y: .value("Minutes", data.totalMinutes)
                )
                .foregroundStyle(.accent)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(.primary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
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
