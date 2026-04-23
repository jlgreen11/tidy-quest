import SwiftUI
import TidyQuestCore

// MARK: - RewardCard

/// Individual reward card in the Rewards tab grid/list.
/// Affordable = full color; unaffordable = 60% opacity + "X more" badge.
/// Cooldown-locked rewards show lock icon + countdown.
struct RewardCard: View {
    let reward: Reward
    let currentBalance: Int
    /// nil means no active cooldown. Otherwise: date the cooldown expires.
    let cooldownExpiresAt: Date?
    let onTap: () -> Void

    @Environment(\.tierTheme) private var tier
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    private var isAffordable: Bool { currentBalance >= reward.price }
    private var isOnCooldown: Bool {
        guard let exp = cooldownExpiresAt else { return false }
        return exp > Date()
    }
    private var isLocked: Bool { isOnCooldown }

    private var shortfall: Int { max(reward.price - currentBalance, 0) }

    // MARK: - Body

    var body: some View {
        Button(action: { if !isLocked { onTap() } }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Reward icon
                    Image(systemName: reward.icon)
                        .font(.system(size: tier == .starter ? 28 : 22))
                        .foregroundStyle(isAffordable ? categoryColor : .secondary)

                    Spacer()

                    if isLocked {
                        lockBadge
                    } else if !isAffordable {
                        shortfallBadge
                    }
                }

                Text(reward.name)
                    .font(tier.bodyFont)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                // Price
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("\(reward.price) pts")
                        .font(tier.captionFont)
                        .monospacedDigit()
                        .foregroundStyle(isAffordable ? .primary : .secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                    .fill(cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                            .stroke(isAffordable ? categoryColor.opacity(0.3) : Color.secondary.opacity(0.15), lineWidth: 1)
                    }
            }
            .opacity(isAffordable ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isLocked ? "" : (isAffordable ? "Double-tap to redeem" : "Not enough points"))
        .accessibilityAddTraits(isLocked || !isAffordable ? .isStaticText : [])
    }

    // MARK: - Sub-views

    private var lockBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            if let exp = cooldownExpiresAt {
                Text(cooldownLabel(until: exp))
                    .font(tier.captionFont)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: Capsule())
        .foregroundStyle(.secondary)
    }

    private var shortfallBadge: some View {
        Text("+\(shortfall)")
            .font(tier.captionFont)
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(.systemGray6)
            : Color(.systemBackground)
    }

    private var categoryColor: Color {
        // Note: .outing not yet in Core enum — ESCALATE for conductor to add.
        switch reward.category {
        case .screenTime:  .blue
        case .treat:       .orange
        case .privilege:   .purple
        case .cashOut:     .green
        case .savingGoal:  .indigo
        case .other:       .gray
        }
    }

    // MARK: - Helpers

    private func cooldownLabel(until date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "" }
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 { return "Available in \(hours)h" }
        return "Available in \(minutes)m"
    }

    private var accessibilityLabel: String {
        var parts = [reward.name, "\(reward.price) points"]
        if isLocked, let exp = cooldownExpiresAt {
            parts.append(cooldownLabel(until: exp))
        } else if !isAffordable {
            parts.append("Need \(shortfall) more points")
        } else {
            parts.append("Affordable")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview
#Preview("RewardCard — states") {
    let rewards = MockAPIClient.seedRewards
    return ScrollView {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            RewardCard(reward: rewards[0], currentBalance: 200, cooldownExpiresAt: nil, onTap: {})
                .tierTheme(.standard)
            RewardCard(reward: rewards[1], currentBalance: 40, cooldownExpiresAt: nil, onTap: {})
                .tierTheme(.standard)
            RewardCard(reward: rewards[2], currentBalance: 200, cooldownExpiresAt: Date().addingTimeInterval(6 * 3600), onTap: {})
                .tierTheme(.advanced)
            RewardCard(reward: rewards[3], currentBalance: 10, cooldownExpiresAt: nil, onTap: {})
                .tierTheme(.starter)
        }
        .padding()
    }
}
