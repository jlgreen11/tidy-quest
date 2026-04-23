import SwiftUI

/// Animated circular progress ring. Respects Reduce Motion via @Environment.
struct ProgressRing: View {
    /// Value between 0.0 and 1.0.
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 6
    var size: CGFloat = 48

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: displayedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion {
                displayedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 0.6)) {
                    displayedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                displayedProgress = newValue
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    displayedProgress = newValue
                }
            }
        }
        .accessibilityLabel("Progress: \(Int(progress * 100)) percent")
    }
}

#Preview("ProgressRing") {
    HStack(spacing: 24) {
        ProgressRing(progress: 0.0, color: .blue, size: 56)
        ProgressRing(progress: 0.5, color: .green, size: 56)
        ProgressRing(progress: 1.0, color: .purple, size: 56)
    }
    .padding()
    .previewLayout(.sizeThatFits)
}
