import SwiftUI
import TidyQuestCore

// MARK: - TidyQuestKidApp

/// Kid app entry point.
/// Wires AuthController (device-pairing flavor), ChoreRepository, LedgerRepository,
/// and RewardRepository — all fed from MockAPIClient() in DEBUG builds.
@main
struct TidyQuestKidApp: App {

    // MARK: - Dependencies (shared across the app lifetime)

    private let apiClient: any APIClient
    private let authController: AuthController
    private let choreRepository: ChoreRepository
    private let ledgerRepository: LedgerRepository
    private let rewardRepository: RewardRepository

    init() {
        #if DEBUG
        let client = MockAPIClient()
        #else
        // Production: SupabaseAPIClient reads SupabaseURL and SupabaseAnonKey from Info.plist.
        // These are populated per-scheme via xcconfig (see ARCHITECTURE.md).
        let client = SupabaseAPIClient()
        #endif

        self.apiClient = client
        self.authController = AuthController(
            apiClient: client,
            keychain: KeychainStore(service: "com.jlgreen11.tidyquest.kid")
        )
        self.choreRepository = ChoreRepository(apiClient: client)
        self.ledgerRepository = LedgerRepository(apiClient: client)
        self.rewardRepository = RewardRepository(apiClient: client)
    }

    var body: some Scene {
        WindowGroup {
            AppRootGate(
                authController: authController,
                choreRepository: choreRepository,
                ledgerRepository: ledgerRepository,
                rewardRepository: rewardRepository
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

    var body: some View {
        Group {
            if authController.isLoading {
                splashView
            } else if let kid = authController.currentUser, kid.role == .child {
                KidRootView(
                    kid: kid,
                    choreRepository: choreRepository,
                    ledgerRepository: ledgerRepository,
                    rewardRepository: rewardRepository
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

    private var splashView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.bounce, options: .repeating.speed(0.4))

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
        rewardRepository: RewardRepository(apiClient: MockAPIClient())
    )
}

#Preview("AppRootGate — authenticated (Standard kid)") {
    let api = MockAPIClient()
    @Previewable @State var auth = AuthController(
        apiClient: api,
        keychain: KeychainStore(service: "com.jlgreen11.tidyquest.kid")
    )
    let kid = MockAPIClient.seedUsers.first(where: { $0.complexityTier == .standard })!
    auth.setCurrentUser(kid)
    return AppRootGate(
        authController: auth,
        choreRepository: ChoreRepository(apiClient: api),
        ledgerRepository: LedgerRepository(apiClient: api),
        rewardRepository: RewardRepository(apiClient: api)
    )
}
