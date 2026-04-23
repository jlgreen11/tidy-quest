import Foundation
import SwiftData

@available(iOS 17, macOS 14, *)
@Model
public final class RedemptionRequestModel {
    @Attribute(.unique) public var id: UUID
    public var familyId: UUID
    public var userId: UUID
    public var rewardId: UUID
    public var requestedAt: Date
    public var statusRaw: String
    public var approvedByUserId: UUID?
    public var approvedAt: Date?
    public var resultingTransactionId: UUID?
    public var notes: String?
    public var createdAt: Date

    public init(from domain: RedemptionRequest) {
        self.id = domain.id
        self.familyId = domain.familyId
        self.userId = domain.userId
        self.rewardId = domain.rewardId
        self.requestedAt = domain.requestedAt
        self.statusRaw = domain.status.rawValue
        self.approvedByUserId = domain.approvedByUserId
        self.approvedAt = domain.approvedAt
        self.resultingTransactionId = domain.resultingTransactionId
        self.notes = domain.notes
        self.createdAt = domain.createdAt
    }

    public var domain: RedemptionRequest {
        RedemptionRequest(
            id: id,
            familyId: familyId,
            userId: userId,
            rewardId: rewardId,
            requestedAt: requestedAt,
            status: RedemptionStatus(rawValue: statusRaw) ?? .pending,
            approvedByUserId: approvedByUserId,
            approvedAt: approvedAt,
            resultingTransactionId: resultingTransactionId,
            notes: notes,
            createdAt: createdAt
        )
    }
}
