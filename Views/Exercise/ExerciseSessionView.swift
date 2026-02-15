import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ExerciseSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("exerciseWindowAlwaysOnTop") private var alwaysOnTop = false
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

            case .preparing:
                VStack(spacing: Spacing.lg) {
                    Spacer()

                    Image(systemName: "figure.run")
                        .font(.system(size: 48))
                        .foregroundStyle(.accent)
                        .symbolEffect(.bounce)

                    Text("Get Ready!")
                        .font(.title.bold())

                    if let exercise = sessionService.currentExercise {
                        Text("First up: \(exercise.name)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(sessionService.preparingCountdown)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(sessionService.preparingPaused ? .orange : .green)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: sessionService.preparingCountdown)

                    Button {
                        sessionService.startNow()
                    } label: {
                        Label("Start Now", systemImage: "play.fill")
                    }
                    .buttonStyle(PillButtonStyle(color: .green))

                    HStack(spacing: Spacing.sm) {
                        if sessionService.preparingPaused {
                            Button {
                                sessionService.resumePreparing()
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                            .buttonStyle(PillButtonStyle(color: .green))
                        } else {
                            Button {
                                sessionService.pausePreparing()
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                            }
                            .buttonStyle(PillButtonStyle(color: .orange))
                        }

                        Button {
                            sessionService.cancelSession()
                            dismiss()
                        } label: {
                            Label("Skip", systemImage: "forward.end.fill")
                        }
                        .buttonStyle(PillButtonStyle(color: .secondary))
                    }

                    Spacer()
                }
                .transition(.opacity)

            case .waitingToStart:
                if let exercise = sessionService.currentExercise {
                    VStack(spacing: Spacing.lg) {
                        Spacer()

                        Image(systemName: exercise.iconName)
                            .font(.system(size: 48))
                            .foregroundStyle(.accent)

                        Text("Up Next")
                            .font(.title2.bold())

                        Text(exercise.name)
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("Exercise \(sessionService.currentExerciseIndex + 1) of \(sessionService.totalExercises)")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)

                        Button {
                            sessionService.startCurrentExercise()
                        } label: {
                            Label("Start Exercise", systemImage: "play.fill")
                        }
                        .buttonStyle(PillButtonStyle(color: .green))

                        HStack(spacing: Spacing.sm) {
                            Button {
                                sessionService.skipCurrentExercise()
                            } label: {
                                Label("Skip", systemImage: "forward.fill")
                            }
                            .buttonStyle(PillButtonStyle(color: .blue))

                            Button {
                                sessionService.cancelSession()
                                dismiss()
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                            }
                            .buttonStyle(PillButtonStyle(color: .red))
                        }

                        Spacer()
                    }
                    .transition(.opacity)
                }

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
        .background(WindowLevelAccessor(alwaysOnTop: alwaysOnTop))
        #endif
    }

}

#if os(macOS)
private struct WindowLevelAccessor: NSViewRepresentable {
    let alwaysOnTop: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.level = alwaysOnTop ? .floating : .normal
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.level = alwaysOnTop ? .floating : .normal
        }
    }
}
#endif
