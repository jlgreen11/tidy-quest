import SwiftUI
import TidyQuestCore

// MARK: - RewardsView

/// Rewards tab — kid's reward store.
///
/// Layout:
///   1. Saving goal card hero (if saving goal exists)
///   2. Affordable / All filter toggle
///   3. Per-category sections
///
/// Affordable = price <= currentBalance (full color).
/// Unaffordable = 60% opacity + "X more points" badge.
/// Cooldown-locked = lock icon + "Available in Xh" countdown.
@MainActor
struct RewardsView: View {
    let kid: AppUser
    let rewardRepository: RewardRepository
    let ledgerRepository: LedgerRepository

    @Environment(\.tierTheme) private var tier

    // MARK: - Filter state

    @State private var showAffordableOnly = false
    @State private var selectedReward: Reward?
    @State private var showDetail = false

    // MARK: - Derived

    private var balance: Int { ledgerRepository.balance(for: kid.id) }

    private var savingGoal: Reward? {
        rewardRepository.activeRewards.first(where: { $0.category == .savingGoal })
    }

    private var filteredRewards: [Reward] {
        let active = rewardRepository.activeRewards
            .filter { $0.category != .savingGoal }  // saving goal shown in hero
        if showAffordableOnly {
            return active.filter { $0.price <= balance }
        }
        return active
    }

    private var rewardsByCategory: [(RewardCategory, [Reward])] {
        // Note: Core does not have .outing — ESCALATE to conductor to add it.
        // PLAN §2.5 lists "Outings" as a distinct category; for now using .other as catchall.
        let categories: [RewardCategory] = [.screenTime, .treat, .privilege, .cashOut, .other]
        return categories.compactMap { cat in
            let items = filteredRewards.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    private var activeRedemptions: [RedemptionRequest] {
        rewardRepository.pendingRedemptions(for: kid.id)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // 1. Saving goal hero card
                    if let goal = savingGoal {
                        savingGoalSection(goal: goal)
                            .padding(.horizontal, 16)
                    }

                    // 2. Filter toggle
                    filterToggle
                        .padding(.horizontal, 16)

                    // 3. Per-category sections
                    if filteredRewards.isEmpty {
                        emptyState
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(rewardsByCategory, id: \.0) { category, rewards in
                            categorySectionView(category: category, rewards: rewards)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    balancePill
                }
            }
            .sheet(item: $selectedReward) { reward in
                RewardDetailView(
                    reward: reward,
                    currentBalance: balance,
                    parentName: parentNameForKid,
                    onRedeem: { Task { await requestRedemption(for: reward) } },
                    isPresented: Binding(
                        get: { selectedReward != nil },
                        set: { if !$0 { selectedReward = nil } }
                    )
                )
            }
        }
    }

    // MARK: - Saving goal section

    private func savingGoalSection(goal: Reward) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your saving goal")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)

            SavingGoalCard(reward: goal, currentBalance: balance)
        }
    }

    // MARK: - Filter toggle

    private var filterToggle: some View {
        Picker("Filter", selection: $showAffordableOnly) {
            Text("Affordable").tag(true)
            Text("All").tag(false)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Show rewards: Affordable or All")
    }

    // MARK: - Category section

    private func categorySectionView(category: RewardCategory, rewards: [Reward]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: categoryIcon(category))
                    .foregroundStyle(categoryColor(category))
                    .accessibilityHidden(true)
                Text(categoryDisplayName(category))
                    .font(tier.bodyFont)
                    .foregroundStyle(.primary)
            }

            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(rewards) { reward in
                    RewardCard(
                        reward: reward,
                        currentBalance: balance,
                        cooldownExpiresAt: cooldownDate(for: reward),
                        onTap: { selectedReward = reward }
                    )
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        // Starter: single column (larger tiles).
        // Standard/Advanced: 2 columns.
        switch tier {
        case .starter:  [GridItem(.flexible())]
        case .standard, .advanced: [GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No affordable rewards yet", systemImage: "star")
        } description: {
            Text("Complete more chores to earn points!")
        } actions: {
            Button("Show all") { showAffordableOnly = false }
                .buttonStyle(.bordered)
        }
    }

    // MARK: - Balance pill

    @ViewBuilder
    private var balancePill: some View {
        if tier.showNumericBalance {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("\(balance)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: balance)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .accessibilityLabel("\(balance) points")
        } else {
            JarProgressView(balance: balance, kidColor: Color(hex: kid.color))
                .scaleEffect(0.55)
                .frame(width: 60, height: 44)
        }
    }

    // MARK: - Cooldown helper

    private func cooldownDate(for reward: Reward) -> Date? {
        guard let cooldown = reward.cooldown else { return nil }
        // Check recent redemptions for this reward
        let recent = activeRedemptions.filter { $0.rewardId == reward.id }.max(by: { $0.requestedAt < $1.requestedAt })
        guard let last = recent else { return nil }
        let expires = last.requestedAt.addingTimeInterval(TimeInterval(cooldown))
        return expires > Date() ? expires : nil
    }

    // MARK: - Redemption

    private func requestRedemption(for reward: Reward) async {
        do {
            _ = try await rewardRepository.requestRedemption(rewardId: reward.id, userId: kid.id)
        } catch {
            // Error surfaces via rewardRepository.error
        }
    }

    // MARK: - Category helpers

    private var parentNameForKid: String { "Mom" } // Resolved by parent display_name in production

    private func categoryDisplayName(_ c: RewardCategory) -> String {
        switch c {
        case .screenTime: "Screen Time"
        case .treat:      "Treats"
        case .privilege:  "Privileges"
        case .cashOut:    "Cash-out"
        case .savingGoal: "Saving Goals"
        case .other:      "Other"
        }
    }

    private func categoryIcon(_ c: RewardCategory) -> String {
        switch c {
        case .screenTime: "ipad"
        case .treat:      "fork.knife"
        case .privilege:  "crown.fill"
        case .cashOut:    "dollarsign.circle.fill"
        case .savingGoal: "star.fill"
        case .other:      "gift.fill"
        }
    }

    private func categoryColor(_ c: RewardCategory) -> Color {
        switch c {
        case .screenTime: .blue
        case .treat:      .orange
        case .privilege:  .purple
        case .cashOut:    .green
        case .savingGoal: .indigo
        case .other:      .gray
        }
    }
}

// MARK: - RewardCategory + outing

// Note: RewardCategory enum in Core doesn't have .outing — it has .other.
// ESCALATE: PLAN §2.5 lists "Outings" as a category. Core Enums.swift has `other` not `outing`.
// For now, treating .other as the outing catchall. A Core enum update will be needed.
// The display name shows "Other" for now — can be split when Core adds .outing.

// MARK: - Preview

#Preview("RewardsView — Standard") {
    let api = MockAPIClient()
    let rewards = RewardRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .standard })!
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return RewardsView(kid: kid, rewardRepository: rewards, ledgerRepository: ledger)
        .tierTheme(.standard)
}

#Preview("RewardsView — Starter") {
    let api = MockAPIClient()
    let rewards = RewardRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .starter })!
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return RewardsView(kid: kid, rewardRepository: rewards, ledgerRepository: ledger)
        .tierTheme(.starter)
}

#Preview("RewardsView — Advanced, low balance") {
    let api = MockAPIClient()
    let rewards = RewardRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .advanced && $0.role == .child })!
    ledger.setBalance(25, for: kid.id)  // Intentionally low to show unaffordable states
    return RewardsView(kid: kid, rewardRepository: rewards, ledgerRepository: ledger)
        .tierTheme(.advanced)
}
