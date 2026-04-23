import SwiftUI
import TidyQuestCore

/// Balance display pill with tabular numerals and tier-aware font.
/// Starter tier shows a jar icon instead of raw integer per ARCHITECTURE token.
struct BalancePill: View {
    let balance: Int
    let tier: Tier
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.showNumericBalance ? "star.fill" : "jar.fill")
                .font(.caption)
                .foregroundStyle(color)

            if tier.showNumericBalance {
                Text("\(balance)")
                    .font(tier.bodyFont.monospacedDigit())
                    .foregroundStyle(.primary)
            } else {
                // Starter: jar metaphor — show relative fullness label
                Text(jarLabel(for: balance))
                    .font(tier.bodyFont)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
        .accessibilityLabel(tier.showNumericBalance
            ? "\(balance) points"
            : "\(jarLabel(for: balance)) jar")
    }

    private func jarLabel(for balance: Int) -> String {
        switch balance {
        case ..<20:   "Nearly empty"
        case 20..<100: "A little full"
        case 100..<300: "Half full"
        case 300..<600: "Mostly full"
        default:        "Overflowing"
        }
    }
}

#Preview("BalancePill tiers") {
    VStack(spacing: 12) {
        BalancePill(balance: 125, tier: .starter, color: .orange)
        BalancePill(balance: 340, tier: .standard, color: .blue)
        BalancePill(balance: 215, tier: .advanced, color: .purple)
    }
    .padding()
    .previewLayout(.sizeThatFits)
}
