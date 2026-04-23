import Foundation

/// Mirrors the `streak` Postgres table.
/// Exactly one of choreTemplateId or routineId is non-nil (enforced by DB CHECK constraint).
public struct Streak: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let userId: UUID
    public let choreTemplateId: UUID?
    public let routineId: UUID?
    public let currentLength: Int
    public let longestLength: Int
    public let lastCompletedDate: String?     // "YYYY-MM-DD"
    public let freezesRemaining: Int
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        userId: UUID,
        choreTemplateId: UUID?,
        routineId: UUID?,
        currentLength: Int,
        longestLength: Int,
        lastCompletedDate: String?,
        freezesRemaining: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.choreTemplateId = choreTemplateId
        self.routineId = routineId
        self.currentLength = currentLength
        self.longestLength = longestLength
        self.lastCompletedDate = lastCompletedDate
        self.freezesRemaining = freezesRemaining
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId             = "user_id"
        case choreTemplateId    = "chore_template_id"
        case routineId          = "routine_id"
        case currentLength      = "current_length"
        case longestLength      = "longest_length"
        case lastCompletedDate  = "last_completed_date"
        case freezesRemaining   = "freezes_remaining"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
    }
}
