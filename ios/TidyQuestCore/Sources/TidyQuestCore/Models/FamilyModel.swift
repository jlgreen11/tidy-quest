import Foundation
import SwiftData

@available(iOS 17, macOS 14, *)
@Model
public final class FamilyModel {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var timezone: String
    public var dailyResetTime: String
    public var quietHoursStart: String
    public var quietHoursEnd: String
    public var leaderboardEnabled: Bool
    public var siblingLedgerVisible: Bool
    public var subscriptionTierRaw: String
    public var subscriptionExpiresAt: Date?
    public var weeklyBandTarget: String?
    public var dailyDeductionCap: Int
    public var weeklyDeductionCap: Int
    public var settingsData: Data
    public var createdAt: Date
    public var deletedAt: Date?

    @Relationship(deleteRule: .cascade) public var users: [AppUserModel]

    public init(from domain: Family) {
        self.id = domain.id
        self.name = domain.name
        self.timezone = domain.timezone
        self.dailyResetTime = domain.dailyResetTime
        self.quietHoursStart = domain.quietHoursStart
        self.quietHoursEnd = domain.quietHoursEnd
        self.leaderboardEnabled = domain.leaderboardEnabled
        self.siblingLedgerVisible = domain.siblingLedgerVisible
        self.subscriptionTierRaw = domain.subscriptionTier.rawValue
        self.subscriptionExpiresAt = domain.subscriptionExpiresAt
        self.weeklyBandTarget = domain.weeklyBandTarget
        self.dailyDeductionCap = domain.dailyDeductionCap
        self.weeklyDeductionCap = domain.weeklyDeductionCap
        self.settingsData = (try? JSONEncoder().encode(domain.settings)) ?? Data()
        self.createdAt = domain.createdAt
        self.deletedAt = domain.deletedAt
        self.users = []
    }

    public var domain: Family {
        let settings = (try? JSONDecoder().decode([String: AnyCodable].self, from: settingsData)) ?? [:]
        return Family(
            id: id,
            name: name,
            timezone: timezone,
            dailyResetTime: dailyResetTime,
            quietHoursStart: quietHoursStart,
            quietHoursEnd: quietHoursEnd,
            leaderboardEnabled: leaderboardEnabled,
            siblingLedgerVisible: siblingLedgerVisible,
            subscriptionTier: SubscriptionTier(rawValue: subscriptionTierRaw) ?? .trial,
            subscriptionExpiresAt: subscriptionExpiresAt,
            weeklyBandTarget: weeklyBandTarget,
            dailyDeductionCap: dailyDeductionCap,
            weeklyDeductionCap: weeklyDeductionCap,
            settings: settings,
            createdAt: createdAt,
            deletedAt: deletedAt
        )
    }
}
