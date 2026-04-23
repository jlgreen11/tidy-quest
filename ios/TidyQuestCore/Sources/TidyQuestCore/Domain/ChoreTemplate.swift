import Foundation

/// Mirrors the `chore_template` Postgres table.
public struct ChoreTemplate: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID
    public let name: String
    public let icon: String
    public let description: String?
    public let type: ChoreType
    public let schedule: [String: AnyCodable]
    public let targetUserIds: [UUID]
    public let basePoints: Int
    public let cutoffTime: String?             // "HH:MM" or nil
    public let requiresPhoto: Bool
    public let requiresApproval: Bool
    public let onMiss: OnMissPolicy
    public let onMissAmount: Int
    public let active: Bool
    public let createdAt: Date
    public let archivedAt: Date?

    public init(
        id: UUID,
        familyId: UUID,
        name: String,
        icon: String,
        description: String?,
        type: ChoreType,
        schedule: [String: AnyCodable],
        targetUserIds: [UUID],
        basePoints: Int,
        cutoffTime: String?,
        requiresPhoto: Bool,
        requiresApproval: Bool,
        onMiss: OnMissPolicy,
        onMissAmount: Int,
        active: Bool,
        createdAt: Date,
        archivedAt: Date?
    ) {
        self.id = id
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
        self.active = active
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
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
        case active
        case createdAt        = "created_at"
        case archivedAt       = "archived_at"
    }
}
