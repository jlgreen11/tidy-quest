import Foundation

/// Mirrors the `chore_instance` Postgres table.
public struct ChoreInstance: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let templateId: UUID
    public let userId: UUID
    public let scheduledFor: String           // "YYYY-MM-DD"
    public let windowStart: String?           // "HH:MM"
    public let windowEnd: String?
    public let status: ChoreInstanceStatus
    public let completedAt: Date?
    public let approvedAt: Date?
    public let proofPhotoId: UUID?
    public let awardedPoints: Int?
    public let completedByDevice: String?
    public let completedAsUser: UUID?
    public let createdAt: Date

    public init(
        id: UUID,
        templateId: UUID,
        userId: UUID,
        scheduledFor: String,
        windowStart: String?,
        windowEnd: String?,
        status: ChoreInstanceStatus,
        completedAt: Date?,
        approvedAt: Date?,
        proofPhotoId: UUID?,
        awardedPoints: Int?,
        completedByDevice: String?,
        completedAsUser: UUID?,
        createdAt: Date
    ) {
        self.id = id
        self.templateId = templateId
        self.userId = userId
        self.scheduledFor = scheduledFor
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.status = status
        self.completedAt = completedAt
        self.approvedAt = approvedAt
        self.proofPhotoId = proofPhotoId
        self.awardedPoints = awardedPoints
        self.completedByDevice = completedByDevice
        self.completedAsUser = completedAsUser
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case templateId         = "template_id"
        case userId             = "user_id"
        case scheduledFor       = "scheduled_for"
        case windowStart        = "window_start"
        case windowEnd          = "window_end"
        case status
        case completedAt        = "completed_at"
        case approvedAt         = "approved_at"
        case proofPhotoId       = "proof_photo_id"
        case awardedPoints      = "awarded_points"
        case completedByDevice  = "completed_by_device"
        case completedAsUser    = "completed_as_user"
        case createdAt          = "created_at"
    }
}
