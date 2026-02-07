import SwiftUI

struct QuickActionsView: View {
    let timerState: TimerState
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onSkip: () -> Void
    let onReset: () -> Void
    let onRestart: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            switch timerState {
            case .idle:
                actionButton("Start Timer", icon: "play.fill", color: .green, action: onStart)

            case .running:
                actionButton("Restart", icon: "arrow.counterclockwise", color: .mint, action: onRestart)
                actionButton("Pause", icon: "pause.fill", color: .orange, action: onPause)
                actionButton("Skip", icon: "forward.fill", color: .blue, action: onSkip)

            case .paused:
                actionButton("Restart", icon: "arrow.counterclockwise", color: .mint, action: onRestart)
                actionButton("Resume", icon: "play.fill", color: .green, action: onResume)
                actionButton("Reset", icon: "stop.fill", color: .red, action: onReset)

            case .exerciseTime:
                EmptyView()
            }
        }
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(PillButtonStyle(color: color))
    }
}
