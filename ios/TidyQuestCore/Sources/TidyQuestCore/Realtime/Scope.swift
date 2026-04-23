import Foundation

/// Subscription scope per UI screen.
/// Each scope maps to a set of Supabase Realtime channel subscriptions.
/// Scopes are cancelled on view disappear (`.task {}` lifecycle).
public enum RealtimeScope: Sendable, Hashable {
    /// Parent Today tab: today's chore instances, pending redemptions, today's transactions.
    case parentToday

    /// Parent Approvals tab: pending chore instances, pending redemption requests.
    case parentApprovals

    /// Kid Home screen: own chore instances for today, own point transactions.
    case kidHome(kidId: UUID)

    /// Kid Rewards screen: reward catalog, own redemption requests.
    case kidRewards(kidId: UUID)
}

/// A realtime event emitted to subscribers.
public enum RealtimeEvent: Sendable {
    case choreInstanceChanged(ChoreInstance)
    case pointTransactionAdded(PointTransaction)
    case redemptionRequestChanged(RedemptionRequest)
    case rewardChanged(Reward)
    case connected
    case disconnected(reason: String?)
}
