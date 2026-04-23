import Foundation
import Observation

/// Observable repository for family and user data.
/// Views bind to `family`, `users`, `parents`, `kids` directly.
@available(iOS 17, macOS 14, *)
@Observable
public final class FamilyRepository: @unchecked Sendable {

    // MARK: - Published state

    public private(set) var family: Family?
    public private(set) var users: [AppUser] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: (any Error)?

    // MARK: - Derived

    public var parents: [AppUser] { users.filter { $0.role == .parent } }
    public var kids: [AppUser] { users.filter { $0.role == .child } }

    // MARK: - Dependencies

    private let apiClient: any APIClient

    public init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Load

    /// Bootstrap seed data for mock/preview environments.
    public func loadSeedData() {
        family = MockAPIClient.seedFamily
        users = MockAPIClient.seedUsers
    }

    // MARK: - Family mutations

    public func createFamily(_ req: CreateFamilyRequest) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            family = try await apiClient.createFamily(req)
        } catch {
            self.error = error
        }
    }

    public func updateFamily(_ req: UpdateFamilyRequest) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            family = try await apiClient.updateFamily(req)
        } catch {
            self.error = error
        }
    }

    // MARK: - User mutations

    public func addKid(_ req: AddKidRequest) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let kid = try await apiClient.addKid(req)
            users.append(kid)
        } catch {
            self.error = error
        }
    }

    public func pairDevice(for kidId: UUID) async throws -> PairingCode {
        let req = PairDeviceRequest(kidUserId: kidId)
        return try await apiClient.pairDevice(req)
    }

    public func revokeDevice(for kidId: UUID, appAttestToken: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let req = RevokeDeviceRequest(kidUserId: kidId, appAttestToken: appAttestToken)
            try await apiClient.revokeDevice(req)
        } catch {
            self.error = error
        }
    }

    /// Apply a realtime user-change event (e.g., balance update after a transaction).
    public func applyUserUpdate(_ user: AppUser) {
        if let idx = users.firstIndex(where: { $0.id == user.id }) {
            users[idx] = user
        } else {
            users.append(user)
        }
    }
}
