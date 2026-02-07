import SwiftUI

struct TimerDisplayView: View {
    let remainingSeconds: Int
    let totalSeconds: Int
    let progress: Double
    let state: TimerState

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                CircularProgressView(
                    progress: progress,
                    lineWidth: 7,
                    size: 110,
                    progressColor: progressColor(for: state, remainingSeconds: remainingSeconds, totalSeconds: totalSeconds)
                )

                VStack(spacing: 2) {
                    Text(TimeFormatting.formatSeconds(remainingSeconds))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: remainingSeconds)

                    Text(stateLabel(for: state))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                }
            }
        }
    }
}

// MARK: - Compact row for multi-timer display

struct CompactTimerRow: View {
    let routineTimer: RoutineTimer

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            HStack {
                Text(routineTimer.routineName)
                    .font(nameFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(routineTimer.displayString)
                    .font(timeFont)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: routineTimer.remainingSeconds)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: barRadius)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: barHeight)

                    RoundedRectangle(cornerRadius: barRadius)
                        .fill(progressColor(for: routineTimer.state, remainingSeconds: routineTimer.remainingSeconds, totalSeconds: routineTimer.totalSeconds))
                        .frame(width: geometry.size.width * routineTimer.progress, height: barHeight)
                        .animation(.linear(duration: 1), value: routineTimer.progress)
                }
            }
            .frame(height: barHeight)
        }
        .padding(.vertical, verticalPadding)
    }

    #if os(iOS)
    private let nameFont: Font = .body
    private let timeFont: Font = .system(.title2, design: .rounded, weight: .semibold)
    private let barHeight: CGFloat = 6
    private let barRadius: CGFloat = 3
    private let rowSpacing: CGFloat = 8
    private let verticalPadding: CGFloat = 8
    #else
    private let nameFont: Font = .caption
    private let timeFont: Font = .system(.callout, design: .rounded, weight: .semibold)
    private let barHeight: CGFloat = 4
    private let barRadius: CGFloat = 2
    private let rowSpacing: CGFloat = 4
    private let verticalPadding: CGFloat = 2
    #endif
}

// MARK: - Shared helpers

private func progressColor(for state: TimerState, remainingSeconds: Int, totalSeconds: Int) -> Color {
    switch state {
    case .idle:
        return .secondary
    case .running:
        let fraction = Double(remainingSeconds) / max(Double(totalSeconds), 1)
        if fraction < 0.1 {
            return .red
        } else if fraction < 0.25 {
            return .orange
        }
        return .accentColor
    case .paused:
        return .orange
    case .exerciseTime:
        return .green
    }
}

private func stateLabel(for state: TimerState) -> String {
    switch state {
    case .idle: "Ready"
    case .running: "Working"
    case .paused: "Paused"
    case .exerciseTime: "Exercise!"
    }
}

#Preview {
    TimerDisplayView(
        remainingSeconds: 1935,
        totalSeconds: 2700,
        progress: 0.28,
        state: .running
    )
    .padding()
}
