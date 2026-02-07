import SwiftUI

struct ExerciseSessionView: View {
    @Environment(\.dismiss) private var dismiss
    var sessionService: ExerciseSessionService

    var body: some View {
        VStack {
            switch sessionService.state {
            case .idle:
                ContentUnavailableView(
                    "No Active Session",
                    systemImage: "figure.run",
                    description: Text("Start a work timer to begin an exercise session.")
                )
                .transition(.opacity)

            case .running, .paused:
                if let exercise = sessionService.currentExercise {
                    VStack(spacing: Spacing.xl) {
                        ExerciseStepView(
                            exercise: exercise,
                            remainingSeconds: sessionService.remainingSeconds,
                            progress: sessionService.phaseProgress,
                            exerciseNumber: sessionService.currentExerciseIndex + 1,
                            totalExercises: sessionService.totalExercises,
                            currentSet: sessionService.currentSet,
                            phase: sessionService.phase
                        )

                        // Controls
                        HStack(spacing: Spacing.md) {
                            if sessionService.state == .running {
                                Button {
                                    sessionService.pause()
                                } label: {
                                    Label("Pause", systemImage: "pause.fill")
                                        .lineLimit(1)
                                }
                                .buttonStyle(PillButtonStyle(color: .orange))
                            } else {
                                Button {
                                    sessionService.resume()
                                } label: {
                                    Label("Resume", systemImage: "play.fill")
                                        .lineLimit(1)
                                }
                                .buttonStyle(PillButtonStyle(color: .green))
                            }

                            Button {
                                sessionService.skipCurrentExercise()
                            } label: {
                                Label("Skip", systemImage: "forward.fill")
                                    .lineLimit(1)
                            }
                            .buttonStyle(PillButtonStyle(color: .blue))

                            Button {
                                sessionService.cancelSession()
                                dismiss()
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                                    .lineLimit(1)
                            }
                            .buttonStyle(PillButtonStyle(color: .red))
                        }
                        .padding(.horizontal)
                    }
                    .transition(.opacity)
                }

            case .completed:
                ExerciseCompleteView(
                    logs: sessionService.completedLogs,
                    onDismiss: {
                        sessionService.cancelSession()
                        dismiss()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionService.state)
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 550)
        #endif
    }
}
