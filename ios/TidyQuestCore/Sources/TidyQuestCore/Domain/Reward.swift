import Foundation

/// Mirrors the `reward` Postgres table.
public struct Reward: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID
    public let name: String
    public let icon: String
    public let category: RewardCategory
    public let price: Int
    public let cooldown: Int?              // seconds; nil = no cooldown
    public let autoApproveUnder: Int?     // points threshold; nil = never auto-approve
    public let active: Bool
    public let createdAt: Date
    public let archivedAt: Date?

    public init(
        id: UUID,
        familyId: UUID,
        name: String,
        icon: String,
        category: RewardCategory,
        price: Int,
        cooldown: Int?,
        autoApproveUnder: Int?,
        active: Bool,
        createdAt: Date,
        archivedAt: Date?
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.icon = icon
        self.category = category
        self.price = price
        self.cooldown = cooldown
        self.autoApproveUnder = autoApproveUnder
        self.active = active
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId         = "family_id"
        case name
        case icon
        case category
        case price
        case cooldown
        case autoApproveUnder = "auto_approve_under"
        case active
        case createdAt        = "created_at"
        case archivedAt       = "archived_at"
    }
}
