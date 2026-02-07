import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var size: CGFloat = 80
    var trackColor: Color = .primary.opacity(0.15)
    var progressColor: Color = .accentColor

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            // Glow layer
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AngularGradient(
                        colors: [progressColor.opacity(0.6), progressColor],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * min(progress, 1.0))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth * 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: lineWidth)
                .opacity(0.3)

            // Progress stroke
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AngularGradient(
                        colors: [progressColor.opacity(0.6), progressColor],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * min(progress, 1.0))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        CircularProgressView(progress: 0.75)
        CircularProgressView(progress: 0.5, lineWidth: 4, size: 40, progressColor: .green)
        CircularProgressView(progress: 0.25, lineWidth: 12, size: 120, progressColor: .orange)
    }
    .padding()
}
