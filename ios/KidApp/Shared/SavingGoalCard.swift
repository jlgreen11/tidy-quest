import SwiftUI
import TidyQuestCore

// MARK: - SavingGoalCard

/// Hero card at the top of the Rewards tab showing saving-goal progress.
/// Animated progress ring with reward name and current/total balance.
struct SavingGoalCard: View {
    let reward: Reward
    let currentBalance: Int
    @Environment(\.tierTheme) private var tier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard reward.price > 0 else { return 0 }
        return min(Double(currentBalance) / Double(reward.price), 1.0)
    }

    private var remaining: Int {
        max(reward.price - currentBalance, 0)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: reduceMotion ? progress : progress)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .blue, .purple],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)
                    .animation(reduceMotion ? nil : .spring(duration: 0.8), value: progress)

                // Reward image placeholder
                // Asset naming convention: "reward-icon-<reward.id.uuidString>"
                // Falls back to SF Symbol icon from reward.icon field
                Image(systemName: reward.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.purple)
            }
            .accessibilityHidden(true)

            // Text stack
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.name)
                    .font(tier.headlineFont)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text("\(currentBalance)")
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(.purple)
                    Text("/")
                        .foregroundStyle(.secondary)
                    Text("\(reward.price) pts")
                        .font(.system(size: 17, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if remaining > 0 {
                    Text("\(remaining) more to go!")
                        .font(tier.captionFont)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Ready to redeem!", systemImage: "star.fill")
                        .font(tier.captionFont)
                        .foregroundStyle(.purple)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                .fill(.purple.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                        .stroke(.purple.opacity(0.18), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saving goal: \(reward.name). \(currentBalance) of \(reward.price) points. \(remaining > 0 ? "\(remaining) more to go" : "Ready to redeem").")
    }
}

// MARK: - Preview
#Preview("SavingGoalCard") {
    let reward = MockAPIClient.seedRewards.first(where: { $0.category == .savingGoal })!
    return VStack(spacing: 12) {
        SavingGoalCard(reward: reward, currentBalance: 340)
            .tierTheme(.standard)
        SavingGoalCard(reward: reward, currentBalance: 800)
            .tierTheme(.advanced)
    }
    .padding()
}
