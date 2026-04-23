import Foundation

// MARK: - Chore Template

public struct CreateChoreTemplateRequest: Codable, Sendable {
    public let familyId: UUID
    public let name: String
    public let icon: String
    public let description: String?
    public let type: ChoreType
    public let schedule: [String: AnyCodable]
    public let targetUserIds: [UUID]
    public let basePoints: Int
    public let cutoffTime: String?
    public let requiresPhoto: Bool
    public let requiresApproval: Bool
    public let onMiss: OnMissPolicy
    public let onMissAmount: Int

    public init(
        familyId: UUID,
        name: String,
        icon: String,
        description: String? = nil,
        type: ChoreType,
        schedule: [String: AnyCodable],
        targetUserIds: [UUID],
        basePoints: Int,
        cutoffTime: String? = nil,
        requiresPhoto: Bool = false,
        requiresApproval: Bool = false,
        onMiss: OnMissPolicy = .decay,
        onMissAmount: Int = 0
    ) {
        self.familyId = familyId
        self.name = name
        self.icon = icon
        self.description = description
        self.type = type
        self.schedule = schedule
        self.targetUserIds = targetUserIds
        self.basePoints = basePoints
        self.cutoffTime = cutoffTime
        self.requiresPhoto = requiresPhoto
        self.requiresApproval = requiresApproval
        self.onMiss = onMiss
        self.onMissAmount = onMissAmount
    }

    enum CodingKeys: String, CodingKey {
        case familyId         = "family_id"
        case name
        case icon
        case description
        case type
        case schedule
        case targetUserIds    = "target_user_ids"
        case basePoints       = "base_points"
        case cutoffTime       = "cutoff_time"
        case requiresPhoto    = "requires_photo"
        case requiresApproval = "requires_approval"
        case onMiss           = "on_miss"
        case onMissAmount     = "on_miss_amount"
    }
}

public struct UpdateChoreTemplateRequest: Codable, Sendable {
    public let templateId: UUID
    public let name: String?
    public let icon: String?
    public let description: String?
    public let basePoints: Int?
    public let cutoffTime: String?
    public let requiresPhoto: Bool?
    public let requiresApproval: Bool?
    public let onMiss: OnMissPolicy?
    public let onMissAmount: Int?
    public let targetUserIds: [UUID]?

    public init(
        templateId: UUID,
        name: String? = nil,
        icon: String? = nil,
        description: String? = nil,
        basePoints: Int? = nil,
        cutoffTime: String? = nil,
        requiresPhoto: Bool? = nil,
        requiresApproval: Bool? = nil,
        onMiss: OnMissPolicy? = nil,
        onMissAmount: Int? = nil,
        targetUserIds: [UUID]? = nil
    ) {
        self.templateId = templateId
        self.name = name
        self.icon = icon
        self.description = description
        self.basePoints = basePoints
        self.cutoffTime = cutoffTime
        self.requiresPhoto = requiresPhoto
        self.requiresApproval = requiresApproval
        self.onMiss = onMiss
        self.onMissAmount = onMissAmount
        self.targetUserIds = targetUserIds
    }

    enum CodingKeys: String, CodingKey {
        case templateId       = "template_id"
        case name
        case icon
        case description
        case basePoints       = "base_points"
        case cutoffTime       = "cutoff_time"
        case requiresPhoto    = "requires_photo"
        case requiresApproval = "requires_approval"
        case onMiss           = "on_miss"
        case onMissAmount     = "on_miss_amount"
        case targetUserIds    = "target_user_ids"
    }
}

// MARK: - Chore Instance

public struct CompleteChoreRequest: Codable, Sendable {
    public let instanceId: UUID
    public let completedAt: Date
    public let proofPhotoId: UUID?
    public let completedByDevice: String?

    public init(
        instanceId: UUID,
        completedAt: Date = Date(),
        proofPhotoId: UUID? = nil,
        completedByDevice: String? = nil
    ) {
        self.instanceId = instanceId
        self.completedAt = completedAt
        self.proofPhotoId = proofPhotoId
        self.completedByDevice = completedByDevice
    }

    enum CodingKeys: String, CodingKey {
        case instanceId       = "instance_id"
        case completedAt      = "completed_at"
        case proofPhotoId     = "proof_photo_id"
        case completedByDevice = "completed_by_device"
    }
}

public struct CompleteChoreResponse: Codable, Sendable {
    public let instance: ChoreInstance
    public let transaction: PointTransaction?
    public let balanceAfter: Int?

    public init(instance: ChoreInstance, transaction: PointTransaction?, balanceAfter: Int?) {
        self.instance = instance
        self.transaction = transaction
        self.balanceAfter = balanceAfter
    }

    enum CodingKeys: String, CodingKey {
        case instance
        case transaction
        case balanceAfter = "balance_after"
    }
}
