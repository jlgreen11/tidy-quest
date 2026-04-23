import SwiftUI
import TidyQuestCore

// MARK: - TidyQuestKidApp

/// Kid app entry point.
/// Wires AuthController (device-pairing flavor), ChoreRepository, LedgerRepository,
/// RewardRepository, QuestRepository, and FamilyRepository — all fed from MockAPIClient()
/// in DEBUG builds.
@main
struct TidyQuestKidApp: App {

    // MARK: - Dependencies (shared across the app lifetime)

    private let apiClient: any APIClient
    private let authController: AuthController
    private let choreRepository: ChoreRepository
    private let ledgerRepository: LedgerRepository
    private let rewardRepository: RewardRepository
    private let questRepository: QuestRepository
    private let familyRepository: FamilyRepository

    init() {
        #if DEBUG
        let client = MockAPIClient()
        #else
        // Production: SupabaseAPIClient reads SupabaseURL and SupabaseAnonKey from Info.plist.
        // These are populated per-scheme via xcconfig (see ARCHITECTURE.md).
        let client = SupabaseAPIClient()
        #endif

        let keychain = KeychainStore(service: "com.jlgreen11.tidyquest.kid")

        #if DEBUG
        // Auto-pair to Kai (Chen-Rodriguez family, Standard tier) so the simulator
        // skips PairDeviceView and lands directly on HomeView with real mock data.
        // MockAPIClient.claimPairing always returns Kai for any code, so storing any
        // non-empty token here causes restoreSession() to succeed immediately.
        try? keychain.set("debug-mock-device-token-kai", forKey: KeychainStore.Keys.deviceToken)
        #endif

        self.apiClient = client
        self.authController = AuthController(
            apiClient: client,
            keychain: keychain
        )
        self.choreRepository = ChoreRepository(apiClient: client)
        self.ledgerRepository = LedgerRepository(apiClient: client)
        self.rewardRepository = RewardRepository(apiClient: client)
        self.questRepository = QuestRepository(apiClient: client)
        self.familyRepository = FamilyRepository(apiClient: client)
    }

    var body: some Scene {
        WindowGroup {
            AppRootGate(
                authController: authController,
                choreRepository: choreRepository,
                ledgerRepository: ledgerRepository,
                rewardRepository: rewardRepository,
                questRepository: questRepository,
                familyRepository: familyRepository
            )
            .task {
                await authController.restoreSession()
            }
        }
    }
}

// MARK: - AppRootGate

/// Routes between PairDeviceView (no session) and KidRootView (session active).
@MainActor
struct AppRootGate: View {
    @Bindable var authController: AuthController
    let choreRepository: ChoreRepository
    let ledgerRepository: LedgerRepository
    let rewardRepository: RewardRepository
    let questRepository: QuestRepository
    let familyRepository: FamilyRepository

    var body: some View {
        Group {
            if authController.isLoading {
                splashView
            } else if let kid = authController.currentUser, kid.role == .child {
                KidRootView(
                    kid: kid,
                    choreRepository: choreRepository,
                    ledgerRepository: ledgerRepository,
                    rewardRepository: rewardRepository,
                    questRepository: questRepository,
                    familyRepository: familyRepository
                )
                .tierTheme(kid.complexityTier.tier)
                .onAppear {
                    // Seed ledger balance from cached value
                    ledgerRepository.setBalance(kid.cachedBalance, for: kid.id)
                    // Seed chore instances from repository
                    choreRepository.loadSeedInstances(choreRepository.instances(for: kid.id))
                }
            } else {
                PairDeviceView(authController: authController)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authController.currentUser?.id)
    }

    // MARK: - Splash

    @ViewBuilder private var splashIcon: some View {
        let base = Image(systemName: "star.circle.fill")
            .font(.system(size: 80))
            .foregroundStyle(
                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        if #available(iOS 18.0, *) {
            base.symbolEffect(.bounce, options: .repeating.speed(0.4))
        } else {
            base
        }
    }

    private var splashView: some View {
        VStack(spacing: 16) {
            splashIcon

            Text("TidyQuest")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview("AppRootGate — unauthenticated") {
    @Previewable @State var auth = AuthController(
        apiClient: MockAPIClient(),
        keychain: KeychainStore(service: "com.jlgreen11.tidyquest.kid")
    )
    return AppRootGate(
        authController: auth,
        choreRepository: ChoreRepository(apiClient: MockAPIClient()),
        ledgerRepository: LedgerRepository(apiClient: MockAPIClient()),
        rewardRepository: RewardRepository(apiClient: MockAPIClient()),
        questRepository: QuestRepository(apiClient: MockAPIClient()),
        familyRepository: FamilyRepository(apiClient: MockAPIClient())
    )
}

#Preview("AppRootGate — authenticated (Standard kid)") {
    struct AuthenticatedPreview: View {
        let api = MockAPIClient()
        @State var auth: AuthController
        init() {
            let a = AuthController(
                apiClient: MockAPIClient(),
                keychain: KeychainStore(service: "com.jlgreen11.tidyquest.kid")
            )
            if let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .standard }) {
                a.setCurrentUser(kid)
            }
            _auth = State(initialValue: a)
        }
        var body: some View {
            let family = FamilyRepository(apiClient: api)
            let _ = family.loadSeedData()
            AppRootGate(
                authController: auth,
                choreRepository: ChoreRepository(apiClient: api),
                ledgerRepository: LedgerRepository(apiClient: api),
                rewardRepository: RewardRepository(apiClient: api),
                questRepository: QuestRepository(apiClient: api),
                familyRepository: family
            )
        }
    }
    return AuthenticatedPreview()
}
