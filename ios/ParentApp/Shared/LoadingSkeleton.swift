import SwiftUI

/// Shimmer placeholder used across loading states.
struct LoadingSkeleton: View {
    var cornerRadius: CGFloat = 8
    var height: CGFloat = 20

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(shimmerGradient)
            .frame(height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityLabel("Loading")
            .accessibilityHidden(true)
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(.systemFill), location: phase - 0.3),
                .init(color: Color(.tertiarySystemFill), location: phase),
                .init(color: Color(.systemFill), location: phase + 0.3)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// A ready-made skeleton block for card-style placeholders.
struct SkeletonCard: View {
    var lineCount: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LoadingSkeleton(cornerRadius: 6, height: 16)
                .frame(width: 160)
            ForEach(0..<lineCount, id: \.self) { _ in
                LoadingSkeleton(height: 12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("LoadingSkeleton") {
    VStack(spacing: 16) {
        SkeletonCard(lineCount: 2)
        SkeletonCard(lineCount: 3)
    }
    .padding()
}
