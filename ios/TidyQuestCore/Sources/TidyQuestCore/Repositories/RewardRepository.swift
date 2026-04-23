import Foundation
import Observation

/// Observable repository for the reward catalog and redemption requests.
@available(iOS 17, macOS 14, *)
@Observable
public final class RewardRepository: @unchecked Sendable {

    // MARK: - Published state

    public private(set) var rewards: [Reward] = []
    public private(set) var redemptions: [RedemptionRequest] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: (any Error)?

    // MARK: - Derived

    public var activeRewards: [Reward] { rewards.filter { $0.active } }

    public func pendingRedemptions(for userId: UUID) -> [RedemptionRequest] {
        redemptions.filter { $0.userId == userId && $0.status == .pending }
    }

    public func allPendingRedemptions() -> [RedemptionRequest] {
        redemptions.filter { $0.status == .pending }
    }

    // MARK: - Dependencies

    private let apiClient: any APIClient

    public init(apiClient: any APIClient) {
        self.apiClient = apiClient
        rewards = MockAPIClient.seedRewards
    }

    // MARK: - Redemption mutations

    public func requestRedemption(rewardId: UUID, userId: UUID) async throws -> RedemptionRequest {
        let req = RequestRedemptionRequest(rewardId: rewardId, userId: userId)
        let redemption = try await apiClient.requestRedemption(req)
        applyRedemptionUpdate(redemption)
        return redemption
    }

    public func approveRedemption(_ id: UUID, appAttestToken: String) async throws -> RedemptionApprovedResponse {
        let response = try await apiClient.approveRedemption(id, appAttestToken: appAttestToken)
        applyRedemptionUpdate(response.redemptionRequest)
        return response
    }

    public func denyRedemption(_ id: UUID, reason: String?) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let updated = try await apiClient.denyRedemption(id, reason: reason)
            applyRedemptionUpdate(updated)
        } catch {
            self.error = error
        }
    }

    // MARK: - Realtime application

    public func applyRedemptionUpdate(_ redemption: RedemptionRequest) {
        if let idx = redemptions.firstIndex(where: { $0.id == redemption.id }) {
            redemptions[idx] = redemption
        } else {
            redemptions.append(redemption)
        }
    }

    public func applyRewardUpdate(_ reward: Reward) {
        if let idx = rewards.firstIndex(where: { $0.id == reward.id }) {
            rewards[idx] = reward
        } else {
            rewards.append(reward)
        }
    }
}
