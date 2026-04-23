import Foundation

/// Mirrors the `routine` Postgres table.
public struct Routine: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID
    public let name: String
    public let choreTemplateIds: [UUID]
    public let bonusPoints: Int
    public let activeForUserIds: [UUID]
    public let timeWindow: [String: AnyCodable]?
    public let active: Bool
    public let createdAt: Date
    public let archivedAt: Date?

    public init(
        id: UUID,
        familyId: UUID,
        name: String,
        choreTemplateIds: [UUID],
        bonusPoints: Int,
        activeForUserIds: [UUID],
        timeWindow: [String: AnyCodable]?,
        active: Bool,
        createdAt: Date,
        archivedAt: Date?
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.choreTemplateIds = choreTemplateIds
        self.bonusPoints = bonusPoints
        self.activeForUserIds = activeForUserIds
        self.timeWindow = timeWindow
        self.active = active
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId           = "family_id"
        case name
        case choreTemplateIds   = "chore_template_ids"
        case bonusPoints        = "bonus_points"
        case activeForUserIds   = "active_for_user_ids"
        case timeWindow         = "time_window"
        case active
        case createdAt          = "created_at"
        case archivedAt         = "archived_at"
    }
}
