import SwiftUI

struct ActivityCalendarView: View {
    let sessions: [WorkSession]

    @State private var displayedMonth = Calendar.current.dateComponents([.year, .month], from: .now)
    @State private var selectedDay: Date?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthDate: Date {
        calendar.date(from: displayedMonth) ?? .now
    }

    private var monthTitle: String {
        monthDate.formatted(.dateTime.month(.wide).year())
    }

    private var canGoForward: Bool {
        let now = calendar.dateComponents([.year, .month], from: .now)
        return displayedMonth.year! < now.year! ||
            (displayedMonth.year! == now.year! && displayedMonth.month! < now.month!)
    }

    private var daysInMonth: [DayItem] {
        let range = calendar.range(of: .day, in: .month, for: monthDate)!
        let firstDay = calendar.date(from: displayedMonth)!
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        // Monday = 1 offset. Calendar.weekday: Sun=1, Mon=2...Sat=7
        let mondayOffset = (firstWeekday + 5) % 7

        var items: [DayItem] = []

        // Leading empty cells
        for _ in 0..<mondayOffset {
            items.append(DayItem(day: 0, date: nil, exerciseCount: 0))
        }

        let today = calendar.startOfDay(for: .now)

        for day in range {
            var components = displayedMonth
            components.day = day
            let date = calendar.date(from: components)!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let count = sessions.filter { session in
                session.startDate >= startOfDay && session.startDate < endOfDay && session.wasCompleted
            }.reduce(0) { $0 + $1.exerciseLogs.filter { !$0.skipped }.count }

            let isToday = startOfDay == today
            items.append(DayItem(day: day, date: date, exerciseCount: count, isToday: isToday))
        }

        return items
    }

    private var maxExercises: Int {
        max(daysInMonth.map(\.exerciseCount).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(icon: "calendar", title: "Activity")

            // Month navigation
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1 : 0.3)
            }
            .padding(.horizontal, Spacing.xs)

            // Weekday headers
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daysInMonth) { item in
                    if item.day == 0 {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    } else {
                        dayCell(item)
                    }
                }
            }
        }
        .cardStyle()
        .sheet(item: $selectedDay) { date in
            DayDetailView(date: date, sessions: sessions)
                #if os(macOS)
                .frame(minWidth: 320, minHeight: 300)
                #endif
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        // Reorder to start from Monday: [Mon, Tue, ..., Sun]
        return Array(symbols[1...]) + [symbols[0]]
    }

    private func dayCell(_ item: DayItem) -> some View {
        Button {
            if let date = item.date {
                selectedDay = date
            }
        } label: {
            Text("\(item.day)")
                .font(.caption.weight(item.isToday ? .bold : .regular))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(cellColor(for: item))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .strokeBorder(item.isToday ? Color.accentColor : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(item.exerciseCount > 0 ? .white : .primary)
    }

    private func cellColor(for item: DayItem) -> Color {
        guard item.exerciseCount > 0 else {
            return .primary.opacity(0.05)
        }
        let intensity = Double(item.exerciseCount) / Double(maxExercises)
        let clamped = max(0.3, min(1.0, intensity))
        return .accentColor.opacity(clamped)
    }

    private func changeMonth(by value: Int) {
        guard var newMonth = calendar.date(byAdding: .month, value: value, to: monthDate) else { return }
        // Don't go past current month
        if newMonth > .now {
            newMonth = .now
        }
        let components = calendar.dateComponents([.year, .month], from: newMonth)
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = components
        }
    }
}

// MARK: - DayItem

private struct DayItem: Identifiable {
    let id = UUID()
    let day: Int
    let date: Date?
    let exerciseCount: Int
    var isToday: Bool = false
}

// MARK: - Date + Identifiable for sheet

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSinceReferenceDate }
}
