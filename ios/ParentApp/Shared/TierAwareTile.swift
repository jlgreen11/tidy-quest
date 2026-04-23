import SwiftUI
import TidyQuestCore

/// Shared tile container that applies the kid's tier-aware corner radius
/// and a subtle background, ready to wrap chore rows or kid cards.
struct TierAwareTile<Content: View>: View {
    let tier: Tier
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: tier.tileCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview("TierAwareTile") {
    VStack(spacing: 12) {
        TierAwareTile(tier: .starter, color: .orange) {
            Text("Starter tile — 28pt radius")
                .font(Tier.starter.bodyFont)
        }
        TierAwareTile(tier: .standard, color: .blue) {
            Text("Standard tile — 20pt radius")
                .font(Tier.standard.bodyFont)
        }
        TierAwareTile(tier: .advanced, color: .purple) {
            Text("Advanced tile — 14pt radius")
                .font(Tier.advanced.bodyFont)
        }
    }
    .padding()
}
