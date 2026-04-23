import Foundation

/// Mirrors the `notification` Postgres table.
public struct Notification: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID
    public let userId: UUID
    public let kind: NotificationKind
    public let payload: [String: AnyCodable]
    public let sentAt: Date?
    public let readAt: Date?
    public let createdAt: Date

    public init(
        id: UUID,
        familyId: UUID,
        userId: UUID,
        kind: NotificationKind,
        payload: [String: AnyCodable],
        sentAt: Date?,
        readAt: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.familyId = familyId
        self.userId = userId
        self.kind = kind
        self.payload = payload
        self.sentAt = sentAt
        self.readAt = readAt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId   = "family_id"
        case userId     = "user_id"
        case kind
        case payload
        case sentAt     = "sent_at"
        case readAt     = "read_at"
        case createdAt  = "created_at"
    }
}
