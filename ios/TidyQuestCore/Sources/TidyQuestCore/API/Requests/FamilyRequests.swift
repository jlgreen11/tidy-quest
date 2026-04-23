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
    public let dailyResetTime: String?          // "HH:MM"
    public let quietHoursStart: String?         // "HH:MM"
    public let quietHoursEnd: String?           // "HH:MM"
    public let leaderboardEnabled: Bool?
    public let siblingLedgerVisible: Bool?
    /// Postgres int4range encoded as "[low,high)" string, e.g. "[250,500)".
    public let weeklyBandTarget: String?
    public let dailyDeductionCap: Int?
    public let weeklyDeductionCap: Int?
    /// Partial settings merge — keys present here are merged into the existing jsonb column.
    public let settings: [String: AnyCodable]?

    public init(
        familyId: UUID,
        name: String? = nil,
        timezone: String? = nil,
        dailyResetTime: String? = nil,
        quietHoursStart: String? = nil,
        quietHoursEnd: String? = nil,
        leaderboardEnabled: Bool? = nil,
        siblingLedgerVisible: Bool? = nil,
        weeklyBandTarget: String? = nil,
        dailyDeductionCap: Int? = nil,
        weeklyDeductionCap: Int? = nil,
        settings: [String: AnyCodable]? = nil
    ) {
        self.familyId = familyId
        self.name = name
        self.timezone = timezone
        self.dailyResetTime = dailyResetTime
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.leaderboardEnabled = leaderboardEnabled
        self.siblingLedgerVisible = siblingLedgerVisible
        self.weeklyBandTarget = weeklyBandTarget
        self.dailyDeductionCap = dailyDeductionCap
        self.weeklyDeductionCap = weeklyDeductionCap
        self.settings = settings
    }

    enum CodingKeys: String, CodingKey {
        case familyId             = "family_id"
        case name
        case timezone
        case dailyResetTime       = "daily_reset_time"
        case quietHoursStart      = "quiet_hours_start"
        case quietHoursEnd        = "quiet_hours_end"
        case leaderboardEnabled   = "leaderboard_enabled"
        case siblingLedgerVisible = "sibling_ledger_visible"
        case weeklyBandTarget     = "weekly_band_target"
        case dailyDeductionCap    = "daily_deduction_cap"
        case weeklyDeductionCap   = "weekly_deduction_cap"
        case settings
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
