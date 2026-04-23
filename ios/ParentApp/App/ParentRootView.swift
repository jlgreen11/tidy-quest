import SwiftUI
import TidyQuestCore

/// Root 5-tab controller for the Parent app.
/// Economy and Settings tabs show "Coming soon" placeholders (C3 fills in Wave B).
@available(iOS 17, *)
struct ParentRootView: View {
    var authController: AuthController
    var familyRepo: FamilyRepository
    var choreRepo: ChoreRepository
    var ledgerRepo: LedgerRepository
    var rewardRepo: RewardRepository

    @State private var selectedTab: Tab = .today
    @State private var approvalsPath = NavigationPath()
    @State private var familyPath = NavigationPath()

    enum Tab: Int, CaseIterable {
        case today, approvals, family, economy, settings
    }

    // MARK: - Pending badge count

    private var pendingCount: Int {
        choreRepo.pendingApprovals.count + rewardRepo.allPendingRedemptions().count
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // Today
            NavigationStack {
                TodayView(
                    familyRepo: familyRepo,
                    choreRepo: choreRepo,
                    ledgerRepo: ledgerRepo,
                    rewardRepo: rewardRepo,
                    onSeeAllApprovals: { selectedTab = .approvals }
                )
            }
            .tabItem {
                Label("Today", systemImage: "sun.max.fill")
            }
            .tag(Tab.today)
            .accessibilityLabel("Today tab")

            // Approvals
            NavigationStack(path: $approvalsPath) {
                ApprovalsView(
                    choreRepo: choreRepo,
                    rewardRepo: rewardRepo,
                    familyRepo: familyRepo
                )
            }
            .tabItem {
                Label("Approvals", systemImage: "checkmark.circle.fill")
            }
            .badge(pendingCount > 0 ? pendingCount : 0)
            .tag(Tab.approvals)
            .accessibilityLabel("Approvals tab, \(pendingCount) pending")

            // Family
            FamilyView(
                familyRepo: familyRepo,
                choreRepo: choreRepo,
                rewardRepo: rewardRepo
            )
            .tabItem {
                Label("Family", systemImage: "person.3.fill")
            }
            .tag(Tab.family)
            .accessibilityLabel("Family tab")

            // Economy — placeholder for Wave B (C3)
            NavigationStack {
                PlaceholderView(title: "Economy", icon: "chart.bar.fill")
            }
            .tabItem {
                Label("Economy", systemImage: "chart.bar.fill")
            }
            .tag(Tab.economy)
            .accessibilityLabel("Economy tab — coming soon")

            // Settings — placeholder for Wave B (C3)
            NavigationStack {
                PlaceholderView(title: "Settings", icon: "gearshape.fill")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
            .accessibilityLabel("Settings tab — coming soon")
        }
    }
}

// MARK: - Coming-soon placeholder

private struct PlaceholderView: View {
    let title: String
    let icon: String

    var body: some View {
        EmptyStateView(
            systemImage: icon,
            title: title,
            message: "Coming soon — this tab will be built in Wave B."
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview

#Preview("ParentRootView") {
    let client = MockAPIClient()
    let auth = AuthController(apiClient: client, keychain: KeychainStore(service: "com.jlgreen11.tidyquest.parent.preview"))
    let family = FamilyRepository(apiClient: client)
    let chore = ChoreRepository(apiClient: client)
    let ledger = LedgerRepository(apiClient: client)
    let reward = RewardRepository(apiClient: client)
    family.loadSeedData()
    return ParentRootView(
        authController: auth,
        familyRepo: family,
        choreRepo: chore,
        ledgerRepo: ledger,
        rewardRepo: reward
    )
}
