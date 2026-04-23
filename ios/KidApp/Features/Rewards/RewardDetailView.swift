import SwiftUI
import TidyQuestCore

// MARK: - RewardDetailView

/// Detail + confirm-redeem sheet for a reward.
/// Shows "Request sent to mom" if not auto-approved, or "Redeemed!" with balance ticker if auto-approved.
struct RewardDetailView: View {
    let reward: Reward
    let currentBalance: Int
    let parentName: String
    let onRedeem: () -> Void
    @Binding var isPresented: Bool

    @Environment(\.tierTheme) private var tier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var redeemState: RedeemState = .idle

    enum RedeemState {
        case idle
        case confirming
        case redeeming
        case sentToParent
        case redeemed(balanceAfter: Int)
        case error(String)
    }

    // MARK: - Derived

    private var canAfford: Bool { currentBalance >= reward.price }
    private var isAutoApproved: Bool {
        guard let threshold = reward.autoApproveUnder else { return false }
        return reward.price <= threshold
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon hero
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: reward.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(categoryColor)
                    }
                    .padding(.top, 8)

                    // Name + price
                    VStack(spacing: 6) {
                        Text(reward.name)
                            .font(tier.headlineFont)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text("\(reward.price) points")
                                .font(tier.bodyFont)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    // Balance indicator
                    balanceRow

                    // State-dependent content
                    switch redeemState {
                    case .idle, .confirming:
                        idleContent
                    case .redeeming:
                        ProgressView("Redeeming...")
                            .padding()
                    case .sentToParent:
                        sentToParentContent
                    case .redeemed(let balanceAfter):
                        redeemedContent(balanceAfter: balanceAfter)
                    case .error(let message):
                        errorContent(message: message)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }

    // MARK: - Balance row

    private var balanceRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your balance")
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
                Text("\(currentBalance) pts")
                    .font(tier.bodyFont)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("After redeem")
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
                Text("\(max(currentBalance - reward.price, 0)) pts")
                    .font(tier.bodyFont)
                    .monospacedDigit()
                    .foregroundStyle(canAfford ? .green : .red)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Balance: \(currentBalance) points. After redeem: \(max(currentBalance - reward.price, 0)) points.")
    }

    // MARK: - Idle content

    private var idleContent: some View {
        VStack(spacing: 16) {
            if canAfford {
                Button {
                    redeemState = .redeeming
                    performRedeem()
                } label: {
                    Label("Redeem Now", systemImage: "checkmark.circle.fill")
                        .font(tier.bodyFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(categoryColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: tier.tileCornerRadius))
                }
                .accessibilityLabel("Redeem \(reward.name) for \(reward.price) points")
            } else {
                VStack(spacing: 8) {
                    Label("Not enough points", systemImage: "exclamationmark.circle")
                        .font(tier.bodyFont)
                        .foregroundStyle(.secondary)
                    Text("You need \(reward.price - currentBalance) more points")
                        .font(tier.captionFont)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: tier.tileCornerRadius))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Not enough points. You need \(reward.price - currentBalance) more.")
            }
        }
    }

    // MARK: - Sent to parent content

    private var sentToParentContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
                .symbolEffect(.bounce, options: .speed(0.8))

            Text("Request sent to \(parentName)!")
                .font(tier.headlineFont)
                .multilineTextAlignment(.center)

            Text("You'll get a notification when it's approved.")
                .font(tier.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Done") { isPresented = false }
                .buttonStyle(.bordered)
                .padding(.top, 8)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Request sent to \(parentName). You'll be notified when approved.")
    }

    // MARK: - Redeemed content

    private func redeemedContent(balanceAfter: Int) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, options: .speed(0.8))

            Text("Redeemed!")
                .font(tier.headlineFont)
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Text("New balance:")
                    .font(tier.bodyFont)
                    .foregroundStyle(.secondary)
                Text("\(balanceAfter) pts")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
            }

            Button("Done") { isPresented = false }
                .buttonStyle(.bordered)
                .padding(.top, 8)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Redeemed! New balance: \(balanceAfter) points.")
    }

    // MARK: - Error content

    private func errorContent(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)

            Text(message)
                .font(tier.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") { redeemState = .idle }
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Perform redeem

    private func performRedeem() {
        // The actual async call is in RewardsView.requestRedemption.
        // Here we simulate a state transition for the detail sheet's UX.
        // In production, the view model / repository layer calls back with the result.
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            if isAutoApproved {
                HapticFeedback.success()
                redeemState = .redeemed(balanceAfter: currentBalance - reward.price)
            } else {
                HapticFeedback.light()
                redeemState = .sentToParent
            }
            onRedeem()
        }
    }

    // MARK: - Helpers

    private var categoryColor: Color {
        switch reward.category {
        case .screenTime:  .blue
        case .treat:       .orange
        case .privilege:   .purple
        case .cashOut:     .green
        case .savingGoal:  .indigo
        case .other:       .gray
        }
    }
}

// MARK: - Preview
#Preview("RewardDetailView — affordable") {
    let reward = MockAPIClient.seedRewards.first(where: { $0.category == .screenTime })!
    return RewardDetailView(
        reward: reward,
        currentBalance: 200,
        parentName: "Mom",
        onRedeem: {},
        isPresented: .constant(true)
    )
    .tierTheme(.standard)
}

#Preview("RewardDetailView — unaffordable") {
    let reward = MockAPIClient.seedRewards.first(where: { $0.category == .privilege })!
    return RewardDetailView(
        reward: reward,
        currentBalance: 30,
        parentName: "Dad",
        onRedeem: {},
        isPresented: .constant(true)
    )
    .tierTheme(.advanced)
}
