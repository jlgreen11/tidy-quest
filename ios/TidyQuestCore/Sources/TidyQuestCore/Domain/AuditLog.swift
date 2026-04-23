import Foundation

/// Mirrors the `audit_log` Postgres table (append-only).
public struct AuditLog: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID?
    public let actorUserId: UUID?
    public let action: AuditAction
    public let target: String?
    public let payload: [String: AnyCodable]
    public let createdAt: Date

    public init(
        id: UUID,
        familyId: UUID?,
        actorUserId: UUID?,
        action: AuditAction,
        target: String?,
        payload: [String: AnyCodable],
        createdAt: Date
    ) {
        self.id = id
        self.familyId = familyId
        self.actorUserId = actorUserId
        self.action = action
        self.target = target
        self.payload = payload
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId     = "family_id"
        case actorUserId  = "actor_user_id"
        case action
        case target
        case payload
        case createdAt    = "created_at"
    }
}
