import Foundation

/// One method per edge function.
/// Async throws. Returns typed decoded domain values.
/// Implementations inject an `Idempotency-Key` header on every mutating call.
public protocol APIClient: Sendable {

    // MARK: - Family

    func createFamily(_ req: CreateFamilyRequest) async throws -> Family
    func updateFamily(_ req: UpdateFamilyRequest) async throws -> Family
    func deleteFamily(_ req: DeleteFamilyRequest) async throws

    // MARK: - Users

    func addKid(_ req: AddKidRequest) async throws -> AppUser
    func updateKid(_ req: UpdateKidRequest) async throws -> AppUser
    func pairDevice(_ req: PairDeviceRequest) async throws -> PairingCode
    func claimPairing(_ req: ClaimPairingRequest) async throws -> DeviceClaimResult
    func revokeDevice(_ req: RevokeDeviceRequest) async throws

    // MARK: - Chores

    func createChoreTemplate(_ req: CreateChoreTemplateRequest) async throws -> ChoreTemplate
    func updateChoreTemplate(_ req: UpdateChoreTemplateRequest) async throws -> ChoreTemplate
    func archiveChoreTemplate(_ id: UUID) async throws
    func completeChoreInstance(_ req: CompleteChoreRequest) async throws -> CompleteChoreResponse
    func approveChoreInstance(_ id: UUID) async throws -> ChoreInstance
    func rejectChoreInstance(_ id: UUID, reason: String?) async throws -> ChoreInstance

    // MARK: - Ledger & Redemption

    func requestRedemption(_ req: RequestRedemptionRequest) async throws -> RedemptionRequest
    func approveRedemption(_ id: UUID, appAttestToken: String) async throws -> RedemptionApprovedResponse
    func denyRedemption(_ id: UUID, reason: String?) async throws -> RedemptionRequest
    func issueFine(_ req: IssueFineRequest) async throws -> PointTransaction
    func reverseTransaction(_ id: UUID, reason: String, appAttestToken: String) async throws -> PointTransaction

    // MARK: - Challenges / Quests

    func fetchChallenges(familyId: UUID) async throws -> [Challenge]

    // MARK: - Subscription

    func updateSubscription(_ receipt: String) async throws -> Subscription

    // MARK: - Notifications

    func registerAPNSToken(_ token: String, appBundle: String) async throws

    // MARK: - Read / List

    func listFamilyUsers(familyId: UUID) async throws -> [AppUser]
    func listChoreTemplates(familyId: UUID) async throws -> [ChoreTemplate]
    func listTodayChoreInstances(familyId: UUID) async throws -> [ChoreInstance]
    func listPendingApprovals(familyId: UUID) async throws -> [ChoreInstance]
    func listTransactions(userId: UUID, limit: Int) async throws -> [PointTransaction]
    func listRewards(familyId: UUID) async throws -> [Reward]
    func listPendingRedemptions(familyId: UUID) async throws -> [RedemptionRequest]
    func listStreaks(familyId: UUID) async throws -> [Streak]
    func fetchFamily(id: UUID) async throws -> Family
    func fetchSubscription(familyId: UUID) async throws -> Subscription?
}
