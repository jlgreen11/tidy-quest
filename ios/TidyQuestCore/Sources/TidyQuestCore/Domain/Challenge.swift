import Foundation

/// Mirrors the `challenge` Postgres table (a.k.a. quest).
public struct Challenge: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let familyId: UUID
    public let name: String
    public let description: String?
    public let startAt: Date
    public let endAt: Date
    public let participantUserIds: [UUID]
    public let constituentChoreTemplateIds: [UUID]
    public let bonusPoints: Int
    public let status: ChallengeStatus
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        familyId: UUID,
        name: String,
        description: String?,
        startAt: Date,
        endAt: Date,
        participantUserIds: [UUID],
        constituentChoreTemplateIds: [UUID],
        bonusPoints: Int,
        status: ChallengeStatus,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.description = description
        self.startAt = startAt
        self.endAt = endAt
        self.participantUserIds = participantUserIds
        self.constituentChoreTemplateIds = constituentChoreTemplateIds
        self.bonusPoints = bonusPoints
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId                       = "family_id"
        case name
        case description
        case startAt                        = "start_at"
        case endAt                          = "end_at"
        case participantUserIds             = "participant_user_ids"
        case constituentChoreTemplateIds    = "constituent_chore_template_ids"
        case bonusPoints                    = "bonus_points"
        case status
        case createdAt                      = "created_at"
        case updatedAt                      = "updated_at"
    }
}
