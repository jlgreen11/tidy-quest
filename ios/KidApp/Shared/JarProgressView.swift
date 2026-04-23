import SwiftUI
import TidyQuestCore

// MARK: - JarProgressView

/// Starter-tier balance visualization: a glass jar filling with colored balls.
/// 1 ball per 10 points. Maximum displayed: 30 balls (overflow handled gracefully).
///
/// Accessibility: announces "N points, shown as a jar with M balls" to VoiceOver.
/// Does NOT show the numeric balance on-screen — that's by design for the Starter tier.
struct JarProgressView: View {
    /// Current balance in points.
    let balance: Int

    /// Kid's primary color (from AppUser.color hex string).
    let kidColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Layout constants
    private let ballSize: CGFloat = 16
    private let columns = 5
    private let maxBalls = 30

    private var ballCount: Int {
        min(balance / 10, maxBalls)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                // Jar outline
                jarShape
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 2.5)

                // Fill level: colored translucent band
                GeometryReader { geo in
                    let fillFraction = min(Double(ballCount) / Double(maxBalls), 1.0)
                    let fillHeight = geo.size.height * fillFraction
                    kidColor
                        .opacity(0.15)
                        .frame(height: fillHeight)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .clipShape(jarShape)
                        .animation(reduceMotion ? nil : .spring(duration: 0.6), value: fillFraction)
                }

                // Balls grid inside jar
                let grid = GridItem(.adaptive(minimum: ballSize + 4), spacing: 4)
                LazyVGrid(columns: Array(repeating: grid, count: columns), spacing: 4) {
                    ForEach(0..<ballCount, id: \.self) { i in
                        Circle()
                            .fill(kidColor)
                            .frame(width: ballSize, height: ballSize)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                            .id(i)
                    }
                }
                .padding(10)
            }
            .frame(width: 100, height: 120)

            // Label below jar
            Text("Saving up!")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(balance) points, shown as a jar with \(ballCount) ball\(ballCount == 1 ? "" : "s")")
    }

    // MARK: - Jar path

    private var jarShape: some Shape {
        JarShape()
    }
}

// MARK: - JarShape

private struct JarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let neckRatio: CGFloat = 0.7
        let neckTop: CGFloat = rect.height * 0.18
        let w = rect.width
        let h = rect.height

        // Neck
        path.move(to: CGPoint(x: w * (1 - neckRatio) / 2, y: 0))
        path.addLine(to: CGPoint(x: w * (1 + neckRatio) / 2, y: 0))
        // Right shoulder
        path.addCurve(
            to: CGPoint(x: w, y: neckTop),
            control1: CGPoint(x: w * (1 + neckRatio) / 2, y: neckTop * 0.3),
            control2: CGPoint(x: w, y: neckTop * 0.5)
        )
        // Right side + bottom
        path.addLine(to: CGPoint(x: w, y: h - 8))
        path.addCurve(
            to: CGPoint(x: 0, y: h - 8),
            control1: CGPoint(x: w, y: h),
            control2: CGPoint(x: 0, y: h)
        )
        // Left side + shoulder
        path.addLine(to: CGPoint(x: 0, y: neckTop))
        path.addCurve(
            to: CGPoint(x: w * (1 - neckRatio) / 2, y: 0),
            control1: CGPoint(x: 0, y: neckTop * 0.5),
            control2: CGPoint(x: w * (1 - neckRatio) / 2, y: neckTop * 0.3)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview
#Preview("JarProgressView") {
    HStack(spacing: 24) {
        VStack {
            JarProgressView(balance: 0, kidColor: .orange)
            Text("0 pts").font(.caption)
        }
        VStack {
            JarProgressView(balance: 80, kidColor: Color(red: 0.3, green: 0.6, blue: 1.0))
            Text("80 pts").font(.caption)
        }
        VStack {
            JarProgressView(balance: 300, kidColor: Color(red: 0.7, green: 0.4, blue: 1.0))
            Text("300 pts").font(.caption)
        }
    }
    .padding()
}
