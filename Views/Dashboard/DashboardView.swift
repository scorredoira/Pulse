import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \WorkSession.startDate, order: .reverse) private var sessions: [WorkSession]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                // Streak cards
                StreakView(sessions: sessions)

                // Daily chart
                DailyStatsChart(sessions: sessions)
                    .cardStyle()

                // Weekly chart
                WeeklyStatsChart(sessions: sessions)
                    .cardStyle()

                // History
                ExerciseHistoryList(sessions: sessions)
            }
            .padding()
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
        #endif
        .navigationTitle("Dashboard")
    }
}

#Preview {
    DashboardView()
}
