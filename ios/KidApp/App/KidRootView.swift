import SwiftUI
import TidyQuestCore

// MARK: - KidRootView

/// Root tab controller for the Kid app.
/// 5 tabs: Home, Rewards, Quests, Me — Ledger accessed from Me per PLAN §5.2.
/// Injects TierTheme via environment based on the authenticated kid's ComplexityTier.
/// Fine bottom sheet fires automatically on in-app fine realtime events.
@MainActor
struct KidRootView: View {
    let kid: AppUser
    let choreRepository: ChoreRepository
    let ledgerRepository: LedgerRepository
    let rewardRepository: RewardRepository
    let questRepository: QuestRepository
    /// FamilyRepository used to resolve the primary parent's display name.
    let familyRepository: FamilyRepository

    // MARK: - State

    @State private var selectedTab: Tab = .home
    /// When non-nil, the FineBottomSheet is presented.
    @State private var pendingFine: PointTransaction?

    enum Tab: Hashable {
        case home, rewards, quests, me
    }

    // MARK: - Derived

    private var tier: Tier { kid.complexityTier.tier }

    /// Resolved parent name from FamilyRepository.
    /// Single parent → their display name. Multiple parents → "your parents".
    private var parentName: String {
        let parents = familyRepository.parents
        if parents.isEmpty {
            return "your parent"
        } else if parents.count == 1 {
            return parents[0].displayName
        } else {
            // Pick primary parent (first parent in the list, or first with apple_sub set).
            let primary = parents.first(where: { $0.appleSub != nil }) ?? parents[0]
            return primary.displayName
        }
    }

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

            QuestsView(
                kid: kid,
                questRepository: questRepository,
                choreRepository: choreRepository
            )
            .tierTheme(tier)
            .tabItem {
                Label("Quests", systemImage: "map.fill")
            }
            .tag(Tab.quests)

            MeView(
                kid: kid,
                choreRepository: choreRepository,
                ledgerRepository: ledgerRepository
            )
            .tierTheme(tier)
            .tabItem {
                Label("Me", systemImage: "person.fill")
            }
            .tag(Tab.me)
        }
        .tint(Color(hex: kid.color))
        .fineBottomSheet(
            fine: $pendingFine,
            parentName: parentName,
            onContest: { txn in contestFine(txn) }
        )
        .task {
            // Load family data to resolve parentName
            await familyRepository.loadFamilyIfNeeded()

            // Load quests
            if let familyId = kid.familyId {
                try? await questRepository.loadForFamily(familyId)
            }

            // In production:
            // Register kidHome realtime scope for chore completions + fine events.
            // When a PointTransaction INSERT fires with kind=='fine' and userId==kid.id,
            // set pendingFine = the transaction to trigger FineBottomSheet.
        }
    }

    // MARK: - Fine contest

    private func contestFine(_ txn: PointTransaction) {
        // Creates an ApprovalRequest of kind .transactionContest back to the parent.
        // In production: call APIClient.createApprovalRequest(...)
        // For MVP, the LedgerView/FineBottomSheet handles the confirmation toast.
    }
}

// MARK: - FamilyRepository extension — load-if-needed

extension FamilyRepository {
    /// Loads seed data in DEBUG builds; no-op in production (data loaded by auth flow).
    func loadFamilyIfNeeded() async {
        #if DEBUG
        if family == nil {
            loadSeedData()
        }
        #endif
    }
}

// MARK: - Preview

#Preview("KidRootView — Standard") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let rewards = RewardRepository(apiClient: api)
    let quests = QuestRepository(apiClient: api)
    let family = FamilyRepository(apiClient: api)
    quests.loadSeedData()
    family.loadSeedData()
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .standard })!
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return KidRootView(
        kid: kid,
        choreRepository: chore,
        ledgerRepository: ledger,
        rewardRepository: rewards,
        questRepository: quests,
        familyRepository: family
    )
}

#Preview("KidRootView — Starter") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let rewards = RewardRepository(apiClient: api)
    let quests = QuestRepository(apiClient: api)
    let family = FamilyRepository(apiClient: api)
    quests.loadSeedData()
    family.loadSeedData()
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .starter })!
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return KidRootView(
        kid: kid,
        choreRepository: chore,
        ledgerRepository: ledger,
        rewardRepository: rewards,
        questRepository: quests,
        familyRepository: family
    )
}

#Preview("KidRootView — Advanced") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let rewards = RewardRepository(apiClient: api)
    let quests = QuestRepository(apiClient: api)
    let family = FamilyRepository(apiClient: api)
    quests.loadSeedData()
    family.loadSeedData()
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .advanced && $0.role == .child })!
    ledger.setBalance(kid.cachedBalance, for: kid.id)
    return KidRootView(
        kid: kid,
        choreRepository: chore,
        ledgerRepository: ledger,
        rewardRepository: rewards,
        questRepository: quests,
        familyRepository: family
    )
}
