import Foundation

/// Mirrors the `family` Postgres table.
public struct Family: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let name: String
    public let timezone: String
    public let dailyResetTime: String          // "HH:MM" — Postgres `time` as string
    public let quietHoursStart: String
    public let quietHoursEnd: String
    public let leaderboardEnabled: Bool
    public let siblingLedgerVisible: Bool
    public let subscriptionTier: SubscriptionTier
    public let subscriptionExpiresAt: Date?
    /// Postgres `int4range` arrives as a string like "[300,500)" — parsed client-side.
    public let weeklyBandTarget: String?
    public let dailyDeductionCap: Int
    public let weeklyDeductionCap: Int
    public let settings: [String: AnyCodable]
    public let createdAt: Date
    public let deletedAt: Date?

    public init(
        id: UUID,
        name: String,
        timezone: String,
        dailyResetTime: String,
        quietHoursStart: String,
        quietHoursEnd: String,
        leaderboardEnabled: Bool,
        siblingLedgerVisible: Bool,
        subscriptionTier: SubscriptionTier,
        subscriptionExpiresAt: Date?,
        weeklyBandTarget: String?,
        dailyDeductionCap: Int,
        weeklyDeductionCap: Int,
        settings: [String: AnyCodable],
        createdAt: Date,
        deletedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.timezone = timezone
        self.dailyResetTime = dailyResetTime
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.leaderboardEnabled = leaderboardEnabled
        self.siblingLedgerVisible = siblingLedgerVisible
        self.subscriptionTier = subscriptionTier
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.weeklyBandTarget = weeklyBandTarget
        self.dailyDeductionCap = dailyDeductionCap
        self.weeklyDeductionCap = weeklyDeductionCap
        self.settings = settings
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case timezone
        case dailyResetTime          = "daily_reset_time"
        case quietHoursStart         = "quiet_hours_start"
        case quietHoursEnd           = "quiet_hours_end"
        case leaderboardEnabled      = "leaderboard_enabled"
        case siblingLedgerVisible    = "sibling_ledger_visible"
        case subscriptionTier        = "subscription_tier"
        case subscriptionExpiresAt   = "subscription_expires_at"
        case weeklyBandTarget        = "weekly_band_target"
        case dailyDeductionCap       = "daily_deduction_cap"
        case weeklyDeductionCap      = "weekly_deduction_cap"
        case settings
        case createdAt               = "created_at"
        case deletedAt               = "deleted_at"
    }
}
