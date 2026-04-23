import Foundation

/// Local-only representation of a kid's stored device token.
/// Not backed by a separate Postgres table — stored in Keychain keyed by app bundle.
public struct DeviceToken: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID              // local identifier
    public let userId: UUID          // app_user.id this token belongs to
    public let familyId: UUID
    public let token: String         // opaque device token string
    public let appBundle: String     // e.g., "com.jlgreen11.tidyquest.kid"
    public let createdAt: Date

    public init(
        id: UUID,
        userId: UUID,
        familyId: UUID,
        token: String,
        appBundle: String,
        createdAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.familyId = familyId
        self.token = token
        self.appBundle = appBundle
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case familyId   = "family_id"
        case token
        case appBundle  = "app_bundle"
        case createdAt  = "created_at"
    }
}
