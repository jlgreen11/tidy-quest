import Foundation
import Supabase

/// Production API client backed by Supabase edge functions.
/// Reads `SupabaseURL` and `SupabaseAnonKey` from `Bundle.main.infoDictionary`.
/// Every mutating call adds an `Idempotency-Key: <uuid>` header.
public final class SupabaseAPIClient: APIClient {

    private let supabase: SupabaseClient
    private let jsonDecoder: JSONDecoder

    public init() {
        guard
            let urlString = Bundle.main.infoDictionary?["SupabaseURL"] as? String,
            let url = URL(string: urlString),
            let anonKey = Bundle.main.infoDictionary?["SupabaseAnonKey"] as? String
        else {
            fatalError("SupabaseURL and SupabaseAnonKey must be set in Info.plist")
        }
        self.supabase = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.jsonDecoder = dec
    }

    /// Initialiser for testing with explicit credentials.
    public init(supabaseURL: URL, supabaseAnonKey: String) {
        self.supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.jsonDecoder = dec
    }

    // MARK: - Private helpers

    private func idempotencyHeaders() -> [String: String] {
        ["Idempotency-Key": UUID().uuidString]
    }

    /// Call an edge function with automatic idempotency key injection. Returns decoded response.
    private func invoke<Req: Encodable, Res: Decodable>(
        function: String,
        body: Req
    ) async throws -> Res {
        do {
            let result: Res = try await supabase.functions.invoke(
                function,
                options: FunctionInvokeOptions(
                    headers: idempotencyHeaders(),
                    body: body
                ),
                decoder: jsonDecoder
            )
            return result
        } catch let funcError as FunctionsError {
            if case .httpError(_, let data) = funcError,
               let apiError = APIError.parseEdgeError(from: data) {
                throw apiError
            }
            throw APIError.networkError(funcError.localizedDescription)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    /// Invoke a function without a typed return value.
    private func invokeVoid<Req: Encodable>(function: String, body: Req) async throws {
        do {
            try await supabase.functions.invoke(
                function,
                options: FunctionInvokeOptions(
                    headers: idempotencyHeaders(),
                    body: body
                )
            )
        } catch let funcError as FunctionsError {
            if case .httpError(_, let data) = funcError,
               let apiError = APIError.parseEdgeError(from: data) {
                throw apiError
            }
            throw APIError.networkError(funcError.localizedDescription)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Family

    public func createFamily(_ req: CreateFamilyRequest) async throws -> Family {
        try await invoke(function: "family.create", body: req)
    }

    public func updateFamily(_ req: UpdateFamilyRequest) async throws -> Family {
        try await invoke(function: "family.update", body: req)
    }

    public func deleteFamily(_ req: DeleteFamilyRequest) async throws {
        try await invokeVoid(function: "family.delete", body: req)
    }

    // MARK: - Users

    public func addKid(_ req: AddKidRequest) async throws -> AppUser {
        try await invoke(function: "user.add-kid", body: req)
    }

    public func pairDevice(_ req: PairDeviceRequest) async throws -> PairingCode {
        try await invoke(function: "user.pair-device", body: req)
    }

    public func claimPairing(_ req: ClaimPairingRequest) async throws -> DeviceClaimResult {
        try await invoke(function: "user.claim-pair", body: req)
    }

    public func revokeDevice(_ req: RevokeDeviceRequest) async throws {
        try await invokeVoid(function: "user.revoke-device", body: req)
    }

    // MARK: - Chores

    public func createChoreTemplate(_ req: CreateChoreTemplateRequest) async throws -> ChoreTemplate {
        try await invoke(function: "chore-template.create", body: req)
    }

    public func updateChoreTemplate(_ req: UpdateChoreTemplateRequest) async throws -> ChoreTemplate {
        try await invoke(function: "chore-template.update", body: req)
    }

    public func archiveChoreTemplate(_ id: UUID) async throws {
        struct Body: Encodable { let template_id: UUID }
        try await invokeVoid(function: "chore-template.archive", body: Body(template_id: id))
    }

    public func completeChoreInstance(_ req: CompleteChoreRequest) async throws -> CompleteChoreResponse {
        try await invoke(function: "chore-instance.complete", body: req)
    }

    public func approveChoreInstance(_ id: UUID) async throws -> ChoreInstance {
        struct Body: Encodable { let instance_id: UUID }
        return try await invoke(function: "chore-instance.approve", body: Body(instance_id: id))
    }

    public func rejectChoreInstance(_ id: UUID, reason: String?) async throws -> ChoreInstance {
        struct Body: Encodable { let instance_id: UUID; let reason: String? }
        return try await invoke(
            function: "chore-instance.reject",
            body: Body(instance_id: id, reason: reason)
        )
    }

    // MARK: - Ledger & Redemption

    public func requestRedemption(_ req: RequestRedemptionRequest) async throws -> RedemptionRequest {
        try await invoke(function: "redemption.request", body: req)
    }

    public func approveRedemption(_ id: UUID, appAttestToken: String) async throws -> RedemptionApprovedResponse {
        struct Body: Encodable { let request_id: UUID; let app_attest_token: String }
        return try await invoke(
            function: "redemption.approve",
            body: Body(request_id: id, app_attest_token: appAttestToken)
        )
    }

    public func denyRedemption(_ id: UUID, reason: String?) async throws -> RedemptionRequest {
        struct Body: Encodable { let request_id: UUID; let reason: String? }
        return try await invoke(
            function: "redemption.deny",
            body: Body(request_id: id, reason: reason)
        )
    }

    public func issueFine(_ req: IssueFineRequest) async throws -> PointTransaction {
        struct ResponseWrapper: Decodable { let transaction: PointTransaction }
        let wrapper: ResponseWrapper = try await invoke(function: "point-transaction.fine", body: req)
        return wrapper.transaction
    }

    public func reverseTransaction(_ id: UUID, reason: String, appAttestToken: String) async throws -> PointTransaction {
        struct Body: Encodable { let transaction_id: UUID; let reason: String; let app_attest_token: String }
        return try await invoke(
            function: "point-transaction.reverse",
            body: Body(transaction_id: id, reason: reason, app_attest_token: appAttestToken)
        )
    }

    // MARK: - Challenges / Quests

    public func fetchChallenges(familyId: UUID) async throws -> [Challenge] {
        struct Body: Encodable { let family_id: UUID }
        return try await invoke(function: "challenge.list", body: Body(family_id: familyId))
    }

    // MARK: - Subscription

    public func updateSubscription(_ receipt: String) async throws -> Subscription {
        struct Body: Encodable { let receipt: String }
        return try await invoke(function: "subscription.update", body: Body(receipt: receipt))
    }

    // MARK: - Notifications

    public func registerAPNSToken(_ token: String, appBundle: String) async throws {
        let req = RegisterAPNSTokenRequest(token: token, appBundle: appBundle)
        try await invokeVoid(function: "notification.register-apns", body: req)
    }
}
