import SwiftUI

// MARK: - ConfettiView

/// Particle burst overlay, respects Reduce Motion.
///
/// Usage: wrap a ZStack and drive `isActive` from a `@State` flag:
/// ```swift
/// ZStack {
///     content
///     ConfettiView(isActive: $showConfetti)
/// }
/// ```
struct ConfettiView: View {
    @Binding var isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particleCount = 60
    private let colors: [Color] = [
        .init(hex: "FF6B6B"), .init(hex: "FFD93D"), .init(hex: "6BCB77"),
        .init(hex: "4D96FF"), .init(hex: "B983FF"), .init(hex: "FF8FB1")
    ]

    var body: some View {
        if isActive {
            if reduceMotion {
                // Reduced motion: simple checkmark flash instead of particles
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .transition(.opacity)
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(1000))
                            withAnimation { isActive = false }
                        }
                    }
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.0)
                        for i in 0..<particleCount {
                            let seed = Double(i) / Double(particleCount)
                            let angle = seed * .pi * 2
                            let speed: Double = 80 + seed * 120
                            let x = size.width / 2 + cos(angle) * speed * elapsed
                            let y = size.height / 2 - sin(angle) * speed * elapsed + 0.5 * 200 * elapsed * elapsed
                            let opacity = max(0, 1 - elapsed / 1.5)
                            let color = colors[i % colors.count]
                            context.opacity = opacity
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 8, height: 8)),
                                with: .color(color)
                            )
                        }
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .onAppear {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1500))
                        isActive = false
                    }
                }
            }
        }
    }
}

// MARK: - Color hex init (local, mirrors TidyQuestCore's)
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let int = UInt64(hex, radix: 16) ?? 0
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview
#Preview("Confetti — full motion") {
    @Previewable @State var show = true
    return ZStack {
        Color.white.ignoresSafeArea()
        Button("Fire!") { show = true }
        ConfettiView(isActive: $show)
    }
}
