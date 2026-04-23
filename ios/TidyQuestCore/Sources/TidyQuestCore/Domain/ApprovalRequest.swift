import Foundation

/// Mirrors the `approval_request` Postgres table.
/// Exactly one of choreInstanceId, redemptionRequestId, pointTransactionId is non-nil.
public struct ApprovalRequest: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID
    public let requestorUserId: UUID
    public let kind: ApprovalRequestKind
    public let status: ApprovalRequestStatus
    public let choreInstanceId: UUID?
    public let redemptionRequestId: UUID?
    public let pointTransactionId: UUID?
    public let reviewedByUserId: UUID?
    public let reviewedAt: Date?
    public let notes: String?
    public let createdAt: Date

    public init(
        id: UUID,
        familyId: UUID,
        requestorUserId: UUID,
        kind: ApprovalRequestKind,
        status: ApprovalRequestStatus,
        choreInstanceId: UUID?,
        redemptionRequestId: UUID?,
        pointTransactionId: UUID?,
        reviewedByUserId: UUID?,
        reviewedAt: Date?,
        notes: String?,
        createdAt: Date
    ) {
        self.id = id
        self.familyId = familyId
        self.requestorUserId = requestorUserId
        self.kind = kind
        self.status = status
        self.choreInstanceId = choreInstanceId
        self.redemptionRequestId = redemptionRequestId
        self.pointTransactionId = pointTransactionId
        self.reviewedByUserId = reviewedByUserId
        self.reviewedAt = reviewedAt
        self.notes = notes
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId             = "family_id"
        case requestorUserId      = "requestor_user_id"
        case kind
        case status
        case choreInstanceId      = "chore_instance_id"
        case redemptionRequestId  = "redemption_request_id"
        case pointTransactionId   = "point_transaction_id"
        case reviewedByUserId     = "reviewed_by_user_id"
        case reviewedAt           = "reviewed_at"
        case notes
        case createdAt            = "created_at"
    }
}
