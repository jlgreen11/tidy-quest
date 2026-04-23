import Foundation

/// Mirrors the `redemption_request` Postgres table.
public struct RedemptionRequest: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID
    public let userId: UUID
    public let rewardId: UUID
    public let requestedAt: Date
    public let status: RedemptionStatus
    public let approvedByUserId: UUID?
    public let approvedAt: Date?
    public let resultingTransactionId: UUID?
    public let notes: String?
    public let createdAt: Date

    public init(
        id: UUID,
        familyId: UUID,
        userId: UUID,
        rewardId: UUID,
        requestedAt: Date,
        status: RedemptionStatus,
        approvedByUserId: UUID?,
        approvedAt: Date?,
        resultingTransactionId: UUID?,
        notes: String?,
        createdAt: Date
    ) {
        self.id = id
        self.familyId = familyId
        self.userId = userId
        self.rewardId = rewardId
        self.requestedAt = requestedAt
        self.status = status
        self.approvedByUserId = approvedByUserId
        self.approvedAt = approvedAt
        self.resultingTransactionId = resultingTransactionId
        self.notes = notes
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId                 = "family_id"
        case userId                   = "user_id"
        case rewardId                 = "reward_id"
        case requestedAt              = "requested_at"
        case status
        case approvedByUserId         = "approved_by_user_id"
        case approvedAt               = "approved_at"
        case resultingTransactionId   = "resulting_transaction_id"
        case notes
        case createdAt                = "created_at"
    }
}
