import Foundation
import Supabase

/// Manages Supabase Realtime channel subscriptions for a given scope.
/// UI agents subscribe in `.task {}` blocks using `AsyncStream<RealtimeEvent>`.
///
/// Usage:
/// ```swift
/// let sub = RealtimeSubscription(client: supabaseClient, familyId: familyId)
/// for await event in sub.stream(for: .parentToday) {
///     // handle event
/// }
/// ```
@available(iOS 17, macOS 14, *)
public final class RealtimeSubscription: Sendable {

    private let client: SupabaseClient
    private let familyId: UUID

    public init(client: SupabaseClient, familyId: UUID) {
        self.client = client
        self.familyId = familyId
    }

    // MARK: - Public stream entry point

    /// Returns an `AsyncStream<RealtimeEvent>` for the given scope.
    /// The stream terminates when the caller's `Task` is cancelled.
    public func stream(for scope: RealtimeScope) -> AsyncStream<RealtimeEvent> {
        AsyncStream<RealtimeEvent> { [client, familyId] continuation in
            let channels = Self.makeChannels(
                scope: scope,
                familyId: familyId,
                client: client,
                continuation: continuation
            )
            continuation.yield(.connected)
            continuation.onTermination = { _ in
                Task {
                    for channel in channels {
                        await channel.unsubscribe()
                    }
                }
            }
        }
    }

    // MARK: - Channel builders

    private static func makeChannels(
        scope: RealtimeScope,
        familyId: UUID,
        client: SupabaseClient,
        continuation: AsyncStream<RealtimeEvent>.Continuation
    ) -> [RealtimeChannelV2] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch scope {
        case .parentToday:
            return [
                choreInstanceChannel(
                    name: "parent-today-chores",
                    client: client, decoder: decoder, continuation: continuation
                ),
                redemptionChannel(
                    name: "parent-today-redemptions",
                    client: client, decoder: decoder, continuation: continuation
                ),
                transactionChannel(
                    name: "parent-today-txns",
                    client: client, decoder: decoder, continuation: continuation
                )
            ]

        case .parentApprovals:
            return [
                choreInstanceChannel(
                    name: "parent-approvals-chores",
                    client: client, decoder: decoder, continuation: continuation
                ),
                redemptionChannel(
                    name: "parent-approvals-redemptions",
                    client: client, decoder: decoder, continuation: continuation
                )
            ]

        case .kidHome(let kidId):
            return [
                choreInstanceChannel(
                    name: "kid-home-chores-\(kidId.uuidString)",
                    client: client, decoder: decoder, continuation: continuation
                ),
                transactionChannel(
                    name: "kid-home-txns-\(kidId.uuidString)",
                    client: client, decoder: decoder, continuation: continuation
                )
            ]

        case .kidRewards(let kidId):
            return [
                rewardChannel(
                    name: "kid-rewards-catalog-\(kidId.uuidString)",
                    client: client, decoder: decoder, continuation: continuation
                ),
                redemptionChannel(
                    name: "kid-rewards-redemptions-\(kidId.uuidString)",
                    client: client, decoder: decoder, continuation: continuation
                )
            ]
        }
    }

    // MARK: - Per-table channel helpers

    private static func choreInstanceChannel(
        name: String,
        client: SupabaseClient,
        decoder: JSONDecoder,
        continuation: AsyncStream<RealtimeEvent>.Continuation
    ) -> RealtimeChannelV2 {
        let channel = client.channel(name)
        Task {
            await channel.subscribe()
            for await change in channel.postgresChange(AnyAction.self, schema: "public", table: "chore_instance") {
                guard let instance = change.decodeIfHasRecord(as: ChoreInstance.self, decoder: decoder) else { continue }
                continuation.yield(.choreInstanceChanged(instance))
            }
        }
        return channel
    }

    private static func transactionChannel(
        name: String,
        client: SupabaseClient,
        decoder: JSONDecoder,
        continuation: AsyncStream<RealtimeEvent>.Continuation
    ) -> RealtimeChannelV2 {
        let channel = client.channel(name)
        Task {
            await channel.subscribe()
            for await change in channel.postgresChange(AnyAction.self, schema: "public", table: "point_transaction") {
                guard let txn = change.decodeIfHasRecord(as: PointTransaction.self, decoder: decoder) else { continue }
                continuation.yield(.pointTransactionAdded(txn))
            }
        }
        return channel
    }

    private static func redemptionChannel(
        name: String,
        client: SupabaseClient,
        decoder: JSONDecoder,
        continuation: AsyncStream<RealtimeEvent>.Continuation
    ) -> RealtimeChannelV2 {
        let channel = client.channel(name)
        Task {
            await channel.subscribe()
            for await change in channel.postgresChange(AnyAction.self, schema: "public", table: "redemption_request") {
                guard let req = change.decodeIfHasRecord(as: RedemptionRequest.self, decoder: decoder) else { continue }
                continuation.yield(.redemptionRequestChanged(req))
            }
        }
        return channel
    }

    private static func rewardChannel(
        name: String,
        client: SupabaseClient,
        decoder: JSONDecoder,
        continuation: AsyncStream<RealtimeEvent>.Continuation
    ) -> RealtimeChannelV2 {
        let channel = client.channel(name)
        Task {
            await channel.subscribe()
            for await change in channel.postgresChange(AnyAction.self, schema: "public", table: "reward") {
                guard let reward = change.decodeIfHasRecord(as: Reward.self, decoder: decoder) else { continue }
                continuation.yield(.rewardChanged(reward))
            }
        }
        return channel
    }
}

// MARK: - AnyAction helper

extension AnyAction {
    /// Decode the record from insert or update actions; returns nil for delete actions.
    func decodeIfHasRecord<T: Decodable>(as type: T.Type, decoder: JSONDecoder) -> T? {
        switch self {
        case .insert(let action): try? action.decodeRecord(as: type, decoder: decoder)
        case .update(let action): try? action.decodeRecord(as: type, decoder: decoder)
        case .delete:             nil
        }
    }
}
