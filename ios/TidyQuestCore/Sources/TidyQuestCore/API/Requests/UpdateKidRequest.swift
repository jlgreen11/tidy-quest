import Foundation

// MARK: - Update Kid

/// Partial update of a child app_user row.
/// Do NOT include role — use revokeDevice / addKid for role changes.
public struct UpdateKidRequest: Sendable, Codable {
    public let kidUserId: UUID
    public let displayName: String?
    public let avatar: String?
    public let color: String?
    public let complexityTier: ComplexityTier?

    public init(
        kidUserId: UUID,
        displayName: String? = nil,
        avatar: String? = nil,
        color: String? = nil,
        complexityTier: ComplexityTier? = nil
    ) {
        self.kidUserId = kidUserId
        self.displayName = displayName
        self.avatar = avatar
        self.color = color
        self.complexityTier = complexityTier
    }

    enum CodingKeys: String, CodingKey {
        case kidUserId      = "kid_user_id"
        case displayName    = "display_name"
        case avatar
        case color
        case complexityTier = "complexity_tier"
    }
}
