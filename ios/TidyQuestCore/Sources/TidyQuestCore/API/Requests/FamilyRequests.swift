import Foundation

// MARK: - Create Family

public struct CreateFamilyRequest: Codable, Sendable {
    public let name: String
    public let timezone: String
    public let dailyResetTime: String
    public let quietHoursStart: String
    public let quietHoursEnd: String

    public init(
        name: String,
        timezone: String,
        dailyResetTime: String = "04:00",
        quietHoursStart: String = "21:00",
        quietHoursEnd: String = "07:00"
    ) {
        self.name = name
        self.timezone = timezone
        self.dailyResetTime = dailyResetTime
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
    }

    enum CodingKeys: String, CodingKey {
        case name
        case timezone
        case dailyResetTime  = "daily_reset_time"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd   = "quiet_hours_end"
    }
}

// MARK: - Update Family

public struct UpdateFamilyRequest: Codable, Sendable {
    public let familyId: UUID
    public let name: String?
    public let timezone: String?
    public let leaderboardEnabled: Bool?
    public let siblingLedgerVisible: Bool?
    public let dailyDeductionCap: Int?
    public let weeklyDeductionCap: Int?

    public init(
        familyId: UUID,
        name: String? = nil,
        timezone: String? = nil,
        leaderboardEnabled: Bool? = nil,
        siblingLedgerVisible: Bool? = nil,
        dailyDeductionCap: Int? = nil,
        weeklyDeductionCap: Int? = nil
    ) {
        self.familyId = familyId
        self.name = name
        self.timezone = timezone
        self.leaderboardEnabled = leaderboardEnabled
        self.siblingLedgerVisible = siblingLedgerVisible
        self.dailyDeductionCap = dailyDeductionCap
        self.weeklyDeductionCap = weeklyDeductionCap
    }

    enum CodingKeys: String, CodingKey {
        case familyId            = "family_id"
        case name
        case timezone
        case leaderboardEnabled  = "leaderboard_enabled"
        case siblingLedgerVisible = "sibling_ledger_visible"
        case dailyDeductionCap   = "daily_deduction_cap"
        case weeklyDeductionCap  = "weekly_deduction_cap"
    }
}

// MARK: - Delete Family

public struct DeleteFamilyRequest: Codable, Sendable {
    public let familyId: UUID
    public let appAttestToken: String

    public init(familyId: UUID, appAttestToken: String) {
        self.familyId = familyId
        self.appAttestToken = appAttestToken
    }

    enum CodingKeys: String, CodingKey {
        case familyId       = "family_id"
        case appAttestToken = "app_attest_token"
    }
}
