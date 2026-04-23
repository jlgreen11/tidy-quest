import SwiftUI
import TidyQuestCore

@main
@available(iOS 17, *)
struct TidyQuestParentApp: App {

    // MARK: - Dependencies

    #if DEBUG
    private let apiClient: any APIClient = MockAPIClient()
    #else
    private let apiClient: any APIClient = SupabaseAPIClient()
    #endif

    @State private var authController: AuthController
    @State private var familyRepo: FamilyRepository
    @State private var choreRepo: ChoreRepository
    @State private var ledgerRepo: LedgerRepository
    @State private var rewardRepo: RewardRepository

    init() {
        #if DEBUG
        let client: any APIClient = MockAPIClient()
        #else
        let client: any APIClient = SupabaseAPIClient()
        #endif

        let keychain = KeychainStore(service: "com.jlgreen11.tidyquest.parent")
        _authController = State(initialValue: AuthController(apiClient: client, keychain: keychain))
        _familyRepo     = State(initialValue: FamilyRepository(apiClient: client))
        _choreRepo      = State(initialValue: ChoreRepository(apiClient: client))
        _ledgerRepo     = State(initialValue: LedgerRepository(apiClient: client))
        _rewardRepo     = State(initialValue: RewardRepository(apiClient: client))

    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            RootGate(
                authController: authController,
                familyRepo: familyRepo,
                choreRepo: choreRepo,
                ledgerRepo: ledgerRepo,
                rewardRepo: rewardRepo,
                apiClient: apiClient
            )
            .task {
                #if DEBUG
                // Seed data loaded for mock; skip live auth
                familyRepo.loadSeedData()
                #else
                await authController.restoreSession()
                #endif
            }
            // Deep-link stub — real wiring in Act 4
            .onContinueUserActivity("com.jlgreen11.tidyquest.approval") { _ in
                // Act 4 will navigate to Approvals tab and highlight the item
            }
        }
    }
}

// MARK: - Root gate (Onboarding vs main app)

/// Shows OnboardingFlow when no family exists yet; otherwise shows ParentRootView.
@available(iOS 17, *)
private struct RootGate: View {
    var authController: AuthController
    var familyRepo: FamilyRepository
    var choreRepo: ChoreRepository
    var ledgerRepo: LedgerRepository
    var rewardRepo: RewardRepository
    var apiClient: any APIClient

    var body: some View {
        if authController.currentUser == nil && familyRepo.family == nil {
            OnboardingFlow(
                familyRepo: familyRepo,
                authController: authController,
                apiClient: apiClient,
                onComplete: {
                    // After onboarding, family is created; RootGate re-evaluates.
                }
            )
        } else {
            ParentRootView(
                authController: authController,
                familyRepo: familyRepo,
                choreRepo: choreRepo,
                ledgerRepo: ledgerRepo,
                rewardRepo: rewardRepo
            )
        }
    }
}
