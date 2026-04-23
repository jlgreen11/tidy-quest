import SwiftUI
import TidyQuestCore

// MARK: - KidRootView

/// Root tab controller for the Kid app.
/// 5 tabs: Home, Rewards, Quests (placeholder), Me (placeholder), with Ledger accessed from Me.
/// Injects TierTheme via environment based on the authenticated kid's ComplexityTier.
@MainActor
struct KidRootView: View {
    let kid: AppUser
    let choreRepository: ChoreRepository
    let ledgerRepository: LedgerRepository
    let rewardRepository: RewardRepository

    // MARK: - State

    @State private var selectedTab: Tab = .home

    enum Tab: Hashable {
        case home, rewards, quests, me
    }

    // MARK: - Derived

    private var tier: Tier { kid.complexityTier.tier }

    /// Display name of the approving parent.
    /// In production: resolved from family members. For now, hardcoded to first parent name.
    private var parentName: String { "Mom" }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                kid: kid,
                choreRepository: choreRepository,
                ledgerRepository: ledgerRepository,
                parentName: parentName
            )
            .tierTheme(tier)
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)

            RewardsView(
                kid: kid,
                rewardRepository: rewardRepository,
                ledgerRepository: ledgerRepository
            )
            .tierTheme(tier)
            .tabItem {
                Label("Rewards", systemImage: "star.fill")
            }
            .tag(Tab.rewards)

            // Placeholder — C4 Wave B
            QuestsPlaceholderView()
                .tierTheme(tier)
                .tabItem {
                    Label("Quests", systemImage: "map.fill")
                }
                .tag(Tab.quests)

            // Placeholder — C4 Wave B
            MePlaceholderView(kid: kid, ledgerRepository: ledgerRepository)
                .tierTheme(tier)
                .tabItem {
                    Label("Me", systemImage: "person.fill")
                }
                .tag(Tab.me)
        }
        .tint(Color(hex: kid.color))
        .task {
            // Realtime subscriptions registered here.
            // In production: RealtimeSubscription.scope(for: .kidHome(kidId: kid.id))
            // and .kidRewards(kidId: kid.id) are registered and cancelled via .task {}.
        }
    }
}

// MARK: - QuestsPlaceholderView

/// Placeholder — C4 Wave B will replace this.
struct QuestsPlaceholderView: View {
    @Environment(\.tierTheme) private var tier

    var body: some View {
        ContentUnavailableView {
            Label("Quests", systemImage: "map.fill")
        } description: {
            Text("Coming soon! Check back for new quests.")
        }
        .navigationTitle("Quests")
    }
}

// MARK: - MePlaceholderView

/// Placeholder — C4 Wave B will replace this.
/// Ledger is a sub-screen of Me per PLAN §5.2.
struct MePlaceholderView: View {
    let kid: AppUser
    let ledgerRepository: LedgerRepository
    @Environment(\.tierTheme) private var tier

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color(hex: kid.color))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(kid.displayName)
                                .font(tier.headlineFont)
                            Text("\(ledgerRepository.balance(for: kid.id)) points")
                                .font(tier.captionFont)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("History") {
                    let txns = ledgerRepository.transactions(for: kid.id)
                    if txns.isEmpty {
                        Text("No transactions yet")
                            .foregroundStyle(.secondary)
                            .font(tier.captionFont)
                    } else {
                        ForEach(txns.prefix(10)) { txn in
                            HStack {
                                Image(systemName: txn.amount > 0 ? "plus.circle.fill" : "minus.circle.fill")
                                    .foregroundStyle(txn.amount > 0 ? .green : .red)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading) {
                                    Text(txn.reason ?? txn.kind.rawValue)
                                        .font(tier.bodyFont)
                                        .lineLimit(1)
                                    Text(txn.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(tier.captionFont)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(txn.amount > 0 ? "+\(txn.amount)" : "\(txn.amount)")
                                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(txn.amount > 0 ? .green : .red)
                                    .monospacedDigit()
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(txn.amount > 0 ? "Earned" : "Spent") \(abs(txn.amount)) points. \(txn.reason ?? txn.kind.rawValue). \(txn.createdAt.formatted(date: .abbreviated, time: .shortened)).")
                        }
                    }
                }
            }
            .navigationTitle("Me")
        }
    }
}

// MARK: - Preview
#Preview("KidRootView — Standard") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let rewards = RewardRepository(apiClient: api)
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .standard })!
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return KidRootView(kid: kid, choreRepository: chore, ledgerRepository: ledger, rewardRepository: rewards)
}

#Preview("KidRootView — Starter") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let rewards = RewardRepository(apiClient: api)
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .starter })!
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return KidRootView(kid: kid, choreRepository: chore, ledgerRepository: ledger, rewardRepository: rewards)
}
