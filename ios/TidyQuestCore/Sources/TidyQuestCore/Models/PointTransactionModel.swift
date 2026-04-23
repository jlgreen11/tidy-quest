import Foundation
import SwiftData

@available(iOS 17, macOS 14, *)
@Model
public final class PointTransactionModel {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var familyId: UUID
    public var amount: Int
    public var kindRaw: String
    public var referenceId: UUID?
    public var reason: String?
    public var createdByUserId: UUID
    @Attribute(.unique) public var idempotencyKey: UUID
    public var choreInstanceId: UUID?
    public var createdAt: Date
    public var reversedByTransactionId: UUID?

    public init(from domain: PointTransaction) {
        self.id = domain.id
        self.userId = domain.userId
        self.familyId = domain.familyId
        self.amount = domain.amount
        self.kindRaw = domain.kind.rawValue
        self.referenceId = domain.referenceId
        self.reason = domain.reason
        self.createdByUserId = domain.createdByUserId
        self.idempotencyKey = domain.idempotencyKey
        self.choreInstanceId = domain.choreInstanceId
        self.createdAt = domain.createdAt
        self.reversedByTransactionId = domain.reversedByTransactionId
    }

    public var domain: PointTransaction {
        PointTransaction(
            id: id,
            userId: userId,
            familyId: familyId,
            amount: amount,
            kind: PointTxnKind(rawValue: kindRaw) ?? .adjustment,
            referenceId: referenceId,
            reason: reason,
            createdByUserId: createdByUserId,
            idempotencyKey: idempotencyKey,
            choreInstanceId: choreInstanceId,
            createdAt: createdAt,
            reversedByTransactionId: reversedByTransactionId
        )
    }
}
