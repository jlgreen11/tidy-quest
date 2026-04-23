import SwiftUI
import TidyQuestCore

// MARK: - StreakBadge

/// Flame icon + day count badge.
/// Visible on Standard tier applicable tiles; hidden on Starter (too young) and configurable on Advanced.
/// Always has an accessibility label — screen reader announces "[N]-day streak".
struct StreakBadge: View {
    let count: Int
    @Environment(\.tierTheme) private var tier

    private var flameColor: Color {
        switch count {
        case 0..<3:  .orange
        case 3..<7:  .red
        default:     Color(red: 1.0, green: 0.3, blue: 0.0)
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .foregroundStyle(flameColor)
                .font(.system(size: tier == .advanced ? 12 : 14))
                .symbolEffect(.bounce, options: .speed(1.5))

            Text("\(count)")
                .font(tier.captionFont)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count)-day streak")
    }
}

// MARK: - Preview
#Preview("StreakBadge") {
    HStack(spacing: 12) {
        StreakBadge(count: 1).tierTheme(.starter)
        StreakBadge(count: 4).tierTheme(.standard)
        StreakBadge(count: 14).tierTheme(.advanced)
    }
    .padding()
}
