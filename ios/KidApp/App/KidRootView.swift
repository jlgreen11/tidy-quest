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
        .tint(Color(hex: kid.color) ?? .accentColor)
        .fineBottomSheet(
            fine: $pendingFine,
            parentName: parentName,
            onContest: { txn in contestFine(txn) }
        )
        .task {
            // Load family data to resolve parentName
            await familyRepository.loadFamilyIfNeeded()

            // Seed today's chore instances and templates for this kid.
            // loadToday(for:) equivalent — populates ChoreRepository from mock data.
            await choreRepository.loadTodayIfNeeded(for: kid.id)

            // Seed ledger transactions for this kid.
            // loadTransactions(userId:) equivalent — no-op if already set.
            ledgerRepository.seedTransactionsIfNeeded(for: kid)

            // Reward catalog is seeded in RewardRepository.init; no action needed
            // (loadCatalog(familyId:) equivalent is covered by init-time seed).

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

// MARK: - ChoreRepository extension — load today if needed

extension ChoreRepository {
    /// In DEBUG builds, seeds today's instances for the given kid from MockAPIClient data.
    /// Equivalent of a production `loadToday(for:)` call.
    /// No-op if instances are already loaded (idempotent).
    @MainActor
    func loadTodayIfNeeded(for userId: UUID) async {
        #if DEBUG
        guard todayInstances.filter({ $0.userId == userId }).isEmpty else { return }
        // Load matching seed templates and build pending instances for today
        let today: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "America/Los_Angeles")
            return f.string(from: Date())
        }()
        // Merge with seed instances from MockAPIClient that belong to this kid
        let seedForKid = MockAPIClient.seedTemplates
            .filter { $0.targetUserIds.contains(userId) }
        // Prefer existing seed instances; generate any missing ones as pending
        let existingIds = Set(todayInstances.map { $0.templateId })
        let newInstances: [ChoreInstance] = seedForKid
            .filter { !existingIds.contains($0.id) }
            .map { template in
                ChoreInstance(
                    id: UUID(),
                    templateId: template.id,
                    userId: userId,
                    scheduledFor: today,
                    windowStart: nil, windowEnd: nil,
                    status: .pending,
                    completedAt: nil, approvedAt: nil,
                    proofPhotoId: nil, awardedPoints: nil,
                    completedByDevice: nil, completedAsUser: nil,
                    createdAt: Date()
                )
            }
        // Note: ChoreRepository.templates cannot be seeded from outside TidyQuestCore
        // (private(set) across modules). HomeView falls back to MockAPIClient.seedTemplates
        // in DEBUG builds when choreRepository.templates is empty.
        loadSeedInstances(todayInstances + newInstances)
        #endif
    }
}

// MARK: - LedgerRepository extension — seed transactions if needed

extension LedgerRepository {
    /// In DEBUG builds, seeds the kid's balance and a minimal transaction history
    /// if nothing has been set yet. Equivalent of a production `loadTransactions(userId:)`.
    func seedTransactionsIfNeeded(for kid: AppUser) {
        #if DEBUG
        guard balance(for: kid.id) == 0 && transactions(for: kid.id).isEmpty else { return }
        setBalance(kid.cachedBalance, for: kid.id)
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
