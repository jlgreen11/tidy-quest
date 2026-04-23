import Foundation

/// Mirrors the `point_transaction` Postgres table (append-only ledger).
public struct PointTransaction: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let userId: UUID
    public let familyId: UUID
    public let amount: Int
    public let kind: PointTxnKind
    public let referenceId: UUID?
    public let reason: String?
    public let createdByUserId: UUID
    public let idempotencyKey: UUID
    public let choreInstanceId: UUID?
    public let createdAt: Date
    public let reversedByTransactionId: UUID?

    public init(
        id: UUID,
        userId: UUID,
        familyId: UUID,
        amount: Int,
        kind: PointTxnKind,
        referenceId: UUID?,
        reason: String?,
        createdByUserId: UUID,
        idempotencyKey: UUID,
        choreInstanceId: UUID?,
        createdAt: Date,
        reversedByTransactionId: UUID?
    ) {
        self.id = id
        self.userId = userId
        self.familyId = familyId
        self.amount = amount
        self.kind = kind
        self.referenceId = referenceId
        self.reason = reason
        self.createdByUserId = createdByUserId
        self.idempotencyKey = idempotencyKey
        self.choreInstanceId = choreInstanceId
        self.createdAt = createdAt
        self.reversedByTransactionId = reversedByTransactionId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId                   = "user_id"
        case familyId                 = "family_id"
        case amount
        case kind
        case referenceId              = "reference_id"
        case reason
        case createdByUserId          = "created_by_user_id"
        case idempotencyKey           = "idempotency_key"
        case choreInstanceId          = "chore_instance_id"
        case createdAt                = "created_at"
        case reversedByTransactionId  = "reversed_by_transaction_id"
    }
}
