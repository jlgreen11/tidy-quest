import Foundation

/// In-memory mock that serves the Chen-Rodriguez seed data.
/// UI agents use this for pure-UI work without a live backend.
public final class MockAPIClient: APIClient, @unchecked Sendable {

    // MARK: - Seed UUIDs (match supabase/seed.sql)

    public enum SeedID {
        public static let family      = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        public static let mei         = UUID(uuidString: "22222222-2222-2222-2222-222222222221")!
        public static let luis        = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        public static let ava         = UUID(uuidString: "33333333-3333-3333-3333-333333333331")!
        public static let kai         = UUID(uuidString: "33333333-3333-3333-3333-333333333332")!
        public static let zara        = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        public static let theo        = UUID(uuidString: "33333333-3333-3333-3333-333333333334")!
        public static let system      = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

        public static let templateAvaMakeBed    = UUID(uuidString: "44444444-4444-4444-4444-444444444401")!
        public static let templateAvaBrushTeeth = UUID(uuidString: "44444444-4444-4444-4444-444444444402")!
        public static let templateKaiMakeBed    = UUID(uuidString: "44444444-4444-4444-4444-444444444403")!
        public static let templateKaiHomework   = UUID(uuidString: "44444444-4444-4444-4444-444444444404")!
        public static let templateZaraDishwasher = UUID(uuidString: "44444444-4444-4444-4444-444444444405")!
        public static let templateZaraCats      = UUID(uuidString: "44444444-4444-4444-4444-444444444406")!
        public static let templateTheoFeedDog   = UUID(uuidString: "44444444-4444-4444-4444-444444444407")!
        public static let templateTheoToys      = UUID(uuidString: "44444444-4444-4444-4444-444444444408")!

        public static let questWeekendDeepClean = UUID(uuidString: "77777777-7777-7777-7777-777777777701")!

        public static let reward30MinTablet     = UUID(uuidString: "55555555-5555-5555-5555-555555555501")!
        public static let rewardIceCream        = UUID(uuidString: "55555555-5555-5555-5555-555555555502")!
        public static let rewardPickRestaurant  = UUID(uuidString: "55555555-5555-5555-5555-555555555503")!
        public static let rewardStayUpLate      = UUID(uuidString: "55555555-5555-5555-5555-555555555504")!
        public static let rewardCashOut         = UUID(uuidString: "55555555-5555-5555-5555-555555555505")!
        public static let rewardLegoKit         = UUID(uuidString: "55555555-5555-5555-5555-555555555506")!
        public static let rewardPickMovie       = UUID(uuidString: "55555555-5555-5555-5555-555555555507")!
    }

    // MARK: - Seed Data

    public static let seedFamily: Family = Family(
        id: SeedID.family,
        name: "Chen-Rodriguez",
        timezone: "America/Los_Angeles",
        dailyResetTime: "04:00",
        quietHoursStart: "21:00",
        quietHoursEnd: "07:00",
        leaderboardEnabled: false,
        siblingLedgerVisible: false,
        subscriptionTier: .trial,
        subscriptionExpiresAt: Date().addingTimeInterval(5 * 86400),
        weeklyBandTarget: "[250,500)",
        dailyDeductionCap: 50,
        weeklyDeductionCap: 150,
        settings: [:],
        createdAt: Date().addingTimeInterval(-22 * 86400),
        deletedAt: nil
    )

    private static func makeDate(daysAgo: Double = 0, hoursOffset: Double = 0) -> Date {
        Date().addingTimeInterval(-(daysAgo * 86400) + (hoursOffset * 3600))
    }

    public static let seedUsers: [AppUser] = [
        AppUser(
            id: SeedID.mei, familyId: SeedID.family, role: .parent,
            displayName: "Mei", avatar: "parent-1", color: "#FF6B6B",
            complexityTier: .advanced, birthdate: "1987-04-15", appleSub: "apple-mock-mei-001",
            devicePairingCode: nil, devicePairingExpiresAt: nil,
            cachedBalance: 0, cachedBalanceAsOfTxnId: nil,
            createdAt: makeDate(daysAgo: 22), deletedAt: nil
        ),
        AppUser(
            id: SeedID.luis, familyId: SeedID.family, role: .parent,
            displayName: "Luis", avatar: "parent-2", color: "#6BCB77",
            complexityTier: .advanced, birthdate: "1985-09-03", appleSub: "apple-mock-luis-002",
            devicePairingCode: nil, devicePairingExpiresAt: nil,
            cachedBalance: 0, cachedBalanceAsOfTxnId: nil,
            createdAt: makeDate(daysAgo: 22), deletedAt: nil
        ),
        AppUser(
            id: SeedID.ava, familyId: SeedID.family, role: .child,
            displayName: "Ava", avatar: "kid-butterfly", color: "#FFD93D",
            complexityTier: .starter, birthdate: "2019-04-22", appleSub: nil,
            devicePairingCode: nil, devicePairingExpiresAt: nil,
            cachedBalance: 125, cachedBalanceAsOfTxnId: nil,
            createdAt: makeDate(daysAgo: 22), deletedAt: nil
        ),
        AppUser(
            id: SeedID.kai, familyId: SeedID.family, role: .child,
            displayName: "Kai", avatar: "kid-rocket", color: "#4D96FF",
            complexityTier: .standard, birthdate: "2016-04-22", appleSub: nil,
            devicePairingCode: nil, devicePairingExpiresAt: nil,
            cachedBalance: 340, cachedBalanceAsOfTxnId: nil,
            createdAt: makeDate(daysAgo: 22), deletedAt: nil
        ),
        AppUser(
            id: SeedID.zara, familyId: SeedID.family, role: .child,
            displayName: "Zara", avatar: "kid-star", color: "#B983FF",
            complexityTier: .advanced, birthdate: "2013-04-22", appleSub: nil,
            devicePairingCode: nil, devicePairingExpiresAt: nil,
            cachedBalance: 215, cachedBalanceAsOfTxnId: nil,
            createdAt: makeDate(daysAgo: 22), deletedAt: nil
        ),
        AppUser(
            id: SeedID.theo, familyId: SeedID.family, role: .child,
            displayName: "Theo", avatar: "kid-dinosaur", color: "#FF8FB1",
            complexityTier: .starter, birthdate: "2020-04-22", appleSub: nil,
            devicePairingCode: nil, devicePairingExpiresAt: nil,
            cachedBalance: 88, cachedBalanceAsOfTxnId: nil,
            createdAt: makeDate(daysAgo: 22), deletedAt: nil
        )
    ]

    // Helper: wrap [Int] as AnyCodable schedule value
    private static func allWeek() -> [String: AnyCodable] {
        ["daysOfWeek": AnyCodable([AnyCodable(0),AnyCodable(1),AnyCodable(2),AnyCodable(3),AnyCodable(4),AnyCodable(5),AnyCodable(6)])]
    }
    private static func weeknights() -> [String: AnyCodable] {
        ["daysOfWeek": AnyCodable([AnyCodable(1),AnyCodable(2),AnyCodable(3),AnyCodable(4)])]
    }

    public static let seedTemplates: [ChoreTemplate] = [
        ChoreTemplate(
            id: SeedID.templateAvaMakeBed, familyId: SeedID.family,
            name: "Make bed", icon: "bed.double.fill",
            description: "Make your bed every morning", type: .daily,
            schedule: allWeek(),
            targetUserIds: [SeedID.ava], basePoints: 5, cutoffTime: "09:00",
            requiresPhoto: false, requiresApproval: false, onMiss: .decay, onMissAmount: 0,
            active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil
        ),
        ChoreTemplate(
            id: SeedID.templateAvaBrushTeeth, familyId: SeedID.family,
            name: "Brush teeth", icon: "heart.fill",
            description: "Morning teeth brushing", type: .daily,
            schedule: allWeek(),
            targetUserIds: [SeedID.ava], basePoints: 3, cutoffTime: "09:00",
            requiresPhoto: false, requiresApproval: false, onMiss: .decay, onMissAmount: 0,
            active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil
        ),
        ChoreTemplate(
            id: SeedID.templateKaiMakeBed, familyId: SeedID.family,
            name: "Make bed", icon: "bed.double.fill",
            description: "Make your bed every morning", type: .daily,
            schedule: allWeek(),
            targetUserIds: [SeedID.kai], basePoints: 5, cutoffTime: "09:00",
            requiresPhoto: false, requiresApproval: false, onMiss: .decay, onMissAmount: 0,
            active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil
        ),
        ChoreTemplate(
            id: SeedID.templateKaiHomework, familyId: SeedID.family,
            name: "Homework", icon: "book.fill",
            description: "Finish today's assigned homework", type: .daily,
            schedule: weeknights(),
            targetUserIds: [SeedID.kai], basePoints: 15, cutoffTime: "19:00",
            requiresPhoto: false, requiresApproval: true, onMiss: .decay, onMissAmount: 0,
            active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil
        ),
        ChoreTemplate(
            id: SeedID.templateZaraDishwasher, familyId: SeedID.family,
            name: "Empty dishwasher", icon: "dishwasher",
            description: "Unload and put everything away", type: .daily,
            schedule: allWeek(),
            targetUserIds: [SeedID.zara], basePoints: 12, cutoffTime: "20:00",
            requiresPhoto: false, requiresApproval: false, onMiss: .decay, onMissAmount: 0,
            active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil
        ),
        ChoreTemplate(
            id: SeedID.templateZaraCats, familyId: SeedID.family,
            name: "Feed cats", icon: "pawprint.fill",
            description: "Morning + evening cat feeding", type: .daily,
            schedule: allWeek(),
            targetUserIds: [SeedID.zara], basePoints: 8, cutoffTime: "21:00",
            requiresPhoto: true, requiresApproval: false, onMiss: .decay, onMissAmount: 0,
            active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil
        ),
        ChoreTemplate(
            id: SeedID.templateTheoFeedDog, familyId: SeedID.family,
            name: "Feed dog", icon: "pawprint.circle.fill",
            description: "Feed the dog his kibble", type: .daily,
            schedule: allWeek(),
            targetUserIds: [SeedID.theo], basePoints: 8, cutoffTime: "08:00",
            requiresPhoto: true, requiresApproval: true, onMiss: .decay, onMissAmount: 0,
            active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil
        )
    ]

    /// Weekend Deep Clean quest — active, 2 of 5 chore templates done per kid, ends Sunday 6 PM.
    public static var seedChallenges: [Challenge] {
        let now = Date()
        // Start of this week (Saturday), end Sunday 6 PM
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)  // 1=Sun…7=Sat
        let daysTilSat = (7 - weekday) % 7
        let daysTilSun = daysTilSat + 1
        let saturday = calendar.date(byAdding: .day, value: daysTilSat, to: now) ?? now
        let startAt = calendar.startOfDay(for: saturday)
        var components = DateComponents()
        components.hour = 18
        let sunday = calendar.date(byAdding: .day, value: daysTilSun, to: calendar.startOfDay(for: now)) ?? now
        let endAt = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: sunday) ?? now.addingTimeInterval(86400)

        return [
            Challenge(
                id: SeedID.questWeekendDeepClean,
                familyId: SeedID.family,
                name: "Weekend Deep Clean",
                description: "Work together to earn a family bonus! Complete all assigned chores before Sunday 6 PM.",
                startAt: startAt,
                endAt: endAt,
                participantUserIds: [SeedID.ava, SeedID.kai, SeedID.zara, SeedID.theo],
                constituentChoreTemplateIds: [
                    SeedID.templateAvaMakeBed,
                    SeedID.templateAvaBrushTeeth,
                    SeedID.templateKaiMakeBed,
                    SeedID.templateZaraDishwasher,
                    SeedID.templateZaraCats
                ],
                bonusPoints: 100,
                status: .active,
                createdAt: now.addingTimeInterval(-86400),
                updatedAt: now.addingTimeInterval(-3600)
            )
        ]
    }

    public static let seedRewards: [Reward] = [
        Reward(id: SeedID.reward30MinTablet, familyId: SeedID.family, name: "30 min tablet time",
               icon: "ipad", category: .screenTime, price: 75, cooldown: 86400, autoApproveUnder: 30,
               active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil),
        Reward(id: SeedID.rewardIceCream, familyId: SeedID.family, name: "Ice cream after dinner",
               icon: "fork.knife", category: .treat, price: 60, cooldown: 172800, autoApproveUnder: nil,
               active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil),
        Reward(id: SeedID.rewardPickRestaurant, familyId: SeedID.family, name: "Pick the restaurant",
               icon: "house.fill", category: .privilege, price: 100, cooldown: nil, autoApproveUnder: nil,
               active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil),
        Reward(id: SeedID.rewardStayUpLate, familyId: SeedID.family, name: "Stay up 30 min late",
               icon: "moon.stars.fill", category: .privilege, price: 50, cooldown: 604800, autoApproveUnder: nil,
               active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil),
        Reward(id: SeedID.rewardCashOut, familyId: SeedID.family, name: "Cash-out $1 (IOU)",
               icon: "dollarsign.circle.fill", category: .cashOut, price: 100, cooldown: nil, autoApproveUnder: nil,
               active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil),
        Reward(id: SeedID.rewardLegoKit, familyId: SeedID.family, name: "Lego Dots Butterfly Kit",
               icon: "star.fill", category: .savingGoal, price: 800, cooldown: nil, autoApproveUnder: nil,
               active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil),
        Reward(id: SeedID.rewardPickMovie, familyId: SeedID.family, name: "Pick the family movie",
               icon: "film.fill", category: .privilege, price: 80, cooldown: 604800, autoApproveUnder: nil,
               active: true, createdAt: makeDate(daysAgo: 22), archivedAt: nil)
    ]

    // MARK: - Public seed accessors (for DEBUG-mode repository bootstrap)

    /// Today's chore instances for the Chen-Rodriguez family. Consumed by
    /// `ChoreRepository.loadSeedInstances` on app launch in DEBUG so the UI
    /// renders with data instead of empty states.
    public static var seedTodayInstances: [ChoreInstance] {
        let today = isoDate(from: Date())
        return [
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666601")!, templateId: SeedID.templateAvaMakeBed, userId: SeedID.ava, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .approved, completedAt: Date().addingTimeInterval(-4 * 3600), approvedAt: Date().addingTimeInterval(-4 * 3600), proofPhotoId: nil, awardedPoints: 5, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666602")!, templateId: SeedID.templateAvaBrushTeeth, userId: SeedID.ava, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .pending, completedAt: nil, approvedAt: nil, proofPhotoId: nil, awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666603")!, templateId: SeedID.templateKaiMakeBed, userId: SeedID.kai, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .approved, completedAt: Date().addingTimeInterval(-5 * 3600), approvedAt: Date().addingTimeInterval(-5 * 3600), proofPhotoId: nil, awardedPoints: 5, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666604")!, templateId: SeedID.templateKaiHomework, userId: SeedID.kai, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .pending, completedAt: nil, approvedAt: nil, proofPhotoId: nil, awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666605")!, templateId: SeedID.templateZaraDishwasher, userId: SeedID.zara, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .pending, completedAt: nil, approvedAt: nil, proofPhotoId: nil, awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666606")!, templateId: SeedID.templateZaraCats, userId: SeedID.zara, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .completed, completedAt: Date().addingTimeInterval(-2 * 3600), approvedAt: nil, proofPhotoId: nil, awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666607")!, templateId: SeedID.templateTheoFeedDog, userId: SeedID.theo, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .completed, completedAt: Date().addingTimeInterval(-3 * 3600), approvedAt: nil, proofPhotoId: UUID(), awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date())
        ]
    }

    /// Recent transactions per kid — representative balances for the demo.
    /// Not intended to replicate the full 22-day DB history; covers the last
    /// few events so the ledger view shows something substantive.
    public static func seedTransactions(for kidId: UUID) -> [PointTransaction] {
        let now = Date()
        let family = SeedID.family
        let sentinel = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        func tx(_ amt: Int, _ kind: PointTxnKind, _ reason: String? = nil, _ agoSec: TimeInterval = 3600, _ actor: UUID? = nil) -> PointTransaction {
            PointTransaction(id: UUID(), userId: kidId, familyId: family, amount: amt, kind: kind, referenceId: nil, reason: reason, createdByUserId: actor ?? kidId, idempotencyKey: UUID(), choreInstanceId: nil, createdAt: now.addingTimeInterval(-agoSec), reversedByTransactionId: nil)
        }
        // Baseline history per kid — chosen to hit plausible balances matching seed.sql patterns.
        // First transaction is an opening adjustment representing the 3-week earning
        // history that the full DB seed models procedurally; keeping recent events
        // below it so the ledger view has something substantive to show.
        switch kidId {
        case SeedID.ava: // 6yo starter, target ~340 pts (Lego saving goal at 340/800)
            return [
                tx(334, .adjustment, "Opening balance", 1_728_000, sentinel),
                tx(5,  .choreCompletion, nil, 14_400),
                tx(3,  .choreCompletion, nil, 36_000),
                tx(5,  .choreCompletion, nil, 122_400),
                tx(8,  .choreBonus,     nil, 190_000),
                tx(-15, .redemption,    "Ice cream after dinner", 259_200)
            ]
        case SeedID.kai: // 9yo standard, target ~420 pts, ADHD, 14-day streak
            return [
                tx(415, .adjustment, "Opening balance", 1_728_000, sentinel),
                tx(5,  .choreCompletion, nil, 18_000),
                tx(15, .choreCompletion, nil, 86_400),
                tx(25, .streakBonus,    nil, 90_000),
                tx(30, .choreCompletion, nil, 170_000),
                tx(-75, .redemption,    "30 min tablet time", 259_200),
                tx(5,  .choreCompletion, nil, 345_600)
            ]
        case SeedID.zara: // 12yo advanced, target ~560 pts, cash-out user, contested fine
            return [
                tx(585, .adjustment, "Opening balance", 1_728_000, sentinel),
                tx(12, .choreCompletion, nil, 14_400),
                tx(8,  .choreCompletion, nil, 50_400),
                tx(-5, .fine,           "Rude to sibling", 172_800, UUID(uuidString: "22222222-2222-2222-2222-222222222221")),
                tx(40, .choreCompletion, nil, 259_200),
                tx(-100, .redemption,   "Cash-out $1 (IOU)", 345_600),
                tx(12, .choreCompletion, nil, 432_000),
                tx(8,  .choreCompletion, nil, 518_400)
            ]
        case SeedID.theo: // 5yo starter, target ~95 pts
            return [
                tx(84, .adjustment, "Opening balance", 1_728_000, sentinel),
                tx(8,  .choreCompletion, nil, 10_800),
                tx(5,  .choreCompletion, nil, 72_000),
                tx(-10, .fine,          "Rude to sibling", 90_000, UUID(uuidString: "22222222-2222-2222-2222-222222222221")),
                tx(8,  .choreCompletion, nil, 172_800),
                tx(8,  .choreCompletion, nil, 259_200)
            ]
        default:
            return []
        }
    }

    /// Convenience: balance for a kid derived from seedTransactions.
    public static func seedBalance(for kidId: UUID) -> Int {
        seedTransactions(for: kidId).reduce(0) { $0 + $1.amount }
    }

    /// Active (non-fulfilled/denied) redemption requests.
    public static var seedPendingRedemptions: [RedemptionRequest] { [] }

    // MARK: - Mutable in-memory state

    private var families: [UUID: Family] = [SeedID.family: seedFamily]
    private var users: [UUID: AppUser]
    private var templates: [UUID: ChoreTemplate]
    private var instances: [UUID: ChoreInstance] = [:]
    private var transactions: [UUID: PointTransaction] = [:]
    private var rewards: [UUID: Reward]
    private var redemptions: [UUID: RedemptionRequest] = [:]
    private var challenges: [UUID: Challenge]
    private var subscription: Subscription = Subscription(
        id: UUID(uuidString: "88888888-8888-8888-8888-888888888801")!,
        familyId: SeedID.family,
        storeTransactionId: "mock-trial-receipt-001",
        productId: "com.jlgreen11.tidyquest.trial",
        tier: .trial,
        purchasedAt: Date().addingTimeInterval(-9 * 86400),
        expiresAt: Date().addingTimeInterval(5 * 86400),
        status: .trial,
        receiptHash: "mock-hash-trial-001",
        createdAt: Date().addingTimeInterval(-9 * 86400),
        updatedAt: Date().addingTimeInterval(-9 * 86400)
    )

    public init() {
        users = Dictionary(uniqueKeysWithValues: Self.seedUsers.map { ($0.id, $0) })
        templates = Dictionary(uniqueKeysWithValues: Self.seedTemplates.map { ($0.id, $0) })
        rewards = Dictionary(uniqueKeysWithValues: Self.seedRewards.map { ($0.id, $0) })
        challenges = Dictionary(uniqueKeysWithValues: Self.seedChallenges.map { ($0.id, $0) })

        // Seed today's chore instances
        let today = Self.isoDate(from: Date())
        let seedInstances: [ChoreInstance] = [
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666601")!, templateId: SeedID.templateAvaMakeBed, userId: SeedID.ava, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .approved, completedAt: Date().addingTimeInterval(-4 * 3600), approvedAt: Date().addingTimeInterval(-4 * 3600), proofPhotoId: nil, awardedPoints: 5, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666602")!, templateId: SeedID.templateAvaBrushTeeth, userId: SeedID.ava, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .pending, completedAt: nil, approvedAt: nil, proofPhotoId: nil, awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666603")!, templateId: SeedID.templateKaiMakeBed, userId: SeedID.kai, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .approved, completedAt: Date().addingTimeInterval(-5 * 3600), approvedAt: Date().addingTimeInterval(-5 * 3600), proofPhotoId: nil, awardedPoints: 5, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666604")!, templateId: SeedID.templateKaiHomework, userId: SeedID.kai, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .pending, completedAt: nil, approvedAt: nil, proofPhotoId: nil, awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666605")!, templateId: SeedID.templateZaraDishwasher, userId: SeedID.zara, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .pending, completedAt: nil, approvedAt: nil, proofPhotoId: nil, awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666606")!, templateId: SeedID.templateZaraCats, userId: SeedID.zara, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .completed, completedAt: Date().addingTimeInterval(-2 * 3600), approvedAt: nil, proofPhotoId: nil, awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date()),
            ChoreInstance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666607")!, templateId: SeedID.templateTheoFeedDog, userId: SeedID.theo, scheduledFor: today, windowStart: nil, windowEnd: nil, status: .completed, completedAt: Date().addingTimeInterval(-3 * 3600), approvedAt: nil, proofPhotoId: UUID(), awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date())
        ]
        instances = Dictionary(uniqueKeysWithValues: seedInstances.map { ($0.id, $0) })
    }

    // MARK: - Helpers

    private static func isoDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: date)
    }

    // MARK: - Family

    public func createFamily(_ req: CreateFamilyRequest) async throws -> Family {
        let family = Family(
            id: UUID(), name: req.name, timezone: req.timezone,
            dailyResetTime: req.dailyResetTime, quietHoursStart: req.quietHoursStart,
            quietHoursEnd: req.quietHoursEnd, leaderboardEnabled: false,
            siblingLedgerVisible: false, subscriptionTier: .trial,
            subscriptionExpiresAt: Date().addingTimeInterval(14 * 86400),
            weeklyBandTarget: nil, dailyDeductionCap: 50, weeklyDeductionCap: 150,
            settings: [:], createdAt: Date(), deletedAt: nil
        )
        families[family.id] = family
        return family
    }

    public func updateFamily(_ req: UpdateFamilyRequest) async throws -> Family {
        guard let existing = families[req.familyId] else { throw APIError.notFound }
        // Merge settings: existing keys + incoming keys (incoming wins on conflict)
        var mergedSettings = existing.settings
        if let incoming = req.settings {
            for (k, v) in incoming { mergedSettings[k] = v }
        }
        let updated = Family(
            id: existing.id,
            name: req.name ?? existing.name,
            timezone: req.timezone ?? existing.timezone,
            dailyResetTime: req.dailyResetTime ?? existing.dailyResetTime,
            quietHoursStart: req.quietHoursStart ?? existing.quietHoursStart,
            quietHoursEnd: req.quietHoursEnd ?? existing.quietHoursEnd,
            leaderboardEnabled: req.leaderboardEnabled ?? existing.leaderboardEnabled,
            siblingLedgerVisible: req.siblingLedgerVisible ?? existing.siblingLedgerVisible,
            subscriptionTier: existing.subscriptionTier,
            subscriptionExpiresAt: existing.subscriptionExpiresAt,
            weeklyBandTarget: req.weeklyBandTarget ?? existing.weeklyBandTarget,
            dailyDeductionCap: req.dailyDeductionCap ?? existing.dailyDeductionCap,
            weeklyDeductionCap: req.weeklyDeductionCap ?? existing.weeklyDeductionCap,
            settings: mergedSettings,
            createdAt: existing.createdAt,
            deletedAt: existing.deletedAt
        )
        families[existing.id] = updated
        return updated
    }

    public func deleteFamily(_ req: DeleteFamilyRequest) async throws {
        families.removeValue(forKey: req.familyId)
    }

    // MARK: - Users

    public func addKid(_ req: AddKidRequest) async throws -> AppUser {
        let kid = AppUser(
            id: UUID(), familyId: req.familyId, role: .child,
            displayName: req.displayName, avatar: req.avatar, color: req.color,
            complexityTier: req.complexityTier, birthdate: req.birthdate,
            appleSub: nil, devicePairingCode: nil, devicePairingExpiresAt: nil,
            cachedBalance: 0, cachedBalanceAsOfTxnId: nil, createdAt: Date(), deletedAt: nil
        )
        users[kid.id] = kid
        return kid
    }

    public func updateKid(_ req: UpdateKidRequest) async throws -> AppUser {
        guard let existing = users[req.kidUserId] else { throw APIError.notFound }
        guard existing.role == .child else { throw APIError.notFound }
        let updated = AppUser(
            id: existing.id,
            familyId: existing.familyId,
            role: existing.role,
            displayName: req.displayName ?? existing.displayName,
            avatar: req.avatar ?? existing.avatar,
            color: req.color ?? existing.color,
            complexityTier: req.complexityTier ?? existing.complexityTier,
            birthdate: existing.birthdate,
            appleSub: existing.appleSub,
            devicePairingCode: existing.devicePairingCode,
            devicePairingExpiresAt: existing.devicePairingExpiresAt,
            cachedBalance: existing.cachedBalance,
            cachedBalanceAsOfTxnId: existing.cachedBalanceAsOfTxnId,
            createdAt: existing.createdAt,
            deletedAt: existing.deletedAt
        )
        users[existing.id] = updated
        return updated
    }

    public func pairDevice(_ req: PairDeviceRequest) async throws -> PairingCode {
        let code = String(Int.random(in: 100000...999999))
        return PairingCode(code: code, expiresAt: Date().addingTimeInterval(300))
    }

    public func claimPairing(_ req: ClaimPairingRequest) async throws -> DeviceClaimResult {
        // Return Kai as the mock kid for any pairing claim
        guard let kai = users[SeedID.kai] else { throw APIError.notFound }
        return DeviceClaimResult(deviceToken: "mock-device-token-\(UUID().uuidString)", user: kai)
    }

    public func revokeDevice(_ req: RevokeDeviceRequest) async throws {
        // no-op in mock
    }

    // MARK: - Chores

    public func createChoreTemplate(_ req: CreateChoreTemplateRequest) async throws -> ChoreTemplate {
        let template = ChoreTemplate(
            id: UUID(), familyId: req.familyId, name: req.name, icon: req.icon,
            description: req.description, type: req.type, schedule: req.schedule,
            targetUserIds: req.targetUserIds, basePoints: req.basePoints,
            cutoffTime: req.cutoffTime, requiresPhoto: req.requiresPhoto,
            requiresApproval: req.requiresApproval, onMiss: req.onMiss,
            onMissAmount: req.onMissAmount, active: true, createdAt: Date(), archivedAt: nil
        )
        templates[template.id] = template
        return template
    }

    public func updateChoreTemplate(_ req: UpdateChoreTemplateRequest) async throws -> ChoreTemplate {
        guard let existing = templates[req.templateId] else { throw APIError.notFound }
        let updated = ChoreTemplate(
            id: existing.id, familyId: existing.familyId,
            name: req.name ?? existing.name, icon: req.icon ?? existing.icon,
            description: req.description ?? existing.description,
            type: existing.type, schedule: existing.schedule,
            targetUserIds: req.targetUserIds ?? existing.targetUserIds,
            basePoints: req.basePoints ?? existing.basePoints,
            cutoffTime: req.cutoffTime ?? existing.cutoffTime,
            requiresPhoto: req.requiresPhoto ?? existing.requiresPhoto,
            requiresApproval: req.requiresApproval ?? existing.requiresApproval,
            onMiss: req.onMiss ?? existing.onMiss,
            onMissAmount: req.onMissAmount ?? existing.onMissAmount,
            active: existing.active, createdAt: existing.createdAt, archivedAt: nil
        )
        templates[existing.id] = updated
        return updated
    }

    public func archiveChoreTemplate(_ id: UUID) async throws {
        templates.removeValue(forKey: id)
    }

    public func completeChoreInstance(_ req: CompleteChoreRequest) async throws -> CompleteChoreResponse {
        guard var instance = instances[req.instanceId] else { throw APIError.invalidInstance }
        guard instance.status == .pending else { throw APIError.choreAlreadyCompleted }
        instance = ChoreInstance(
            id: instance.id, templateId: instance.templateId, userId: instance.userId,
            scheduledFor: instance.scheduledFor, windowStart: instance.windowStart,
            windowEnd: instance.windowEnd, status: .completed,
            completedAt: req.completedAt, approvedAt: nil,
            proofPhotoId: req.proofPhotoId, awardedPoints: nil,
            completedByDevice: req.completedByDevice, completedAsUser: nil,
            createdAt: instance.createdAt
        )
        instances[instance.id] = instance
        return CompleteChoreResponse(instance: instance, transaction: nil, balanceAfter: nil)
    }

    public func approveChoreInstance(_ id: UUID) async throws -> ChoreInstance {
        guard var instance = instances[id] else { throw APIError.invalidInstance }
        let points = templates[instance.templateId]?.basePoints ?? 0
        instance = ChoreInstance(
            id: instance.id, templateId: instance.templateId, userId: instance.userId,
            scheduledFor: instance.scheduledFor, windowStart: instance.windowStart,
            windowEnd: instance.windowEnd, status: .approved,
            completedAt: instance.completedAt, approvedAt: Date(),
            proofPhotoId: instance.proofPhotoId, awardedPoints: points,
            completedByDevice: instance.completedByDevice, completedAsUser: instance.completedAsUser,
            createdAt: instance.createdAt
        )
        instances[id] = instance
        return instance
    }

    public func rejectChoreInstance(_ id: UUID, reason: String?) async throws -> ChoreInstance {
        guard var instance = instances[id] else { throw APIError.invalidInstance }
        instance = ChoreInstance(
            id: instance.id, templateId: instance.templateId, userId: instance.userId,
            scheduledFor: instance.scheduledFor, windowStart: instance.windowStart,
            windowEnd: instance.windowEnd, status: .rejected,
            completedAt: instance.completedAt, approvedAt: nil,
            proofPhotoId: instance.proofPhotoId, awardedPoints: 0,
            completedByDevice: instance.completedByDevice, completedAsUser: instance.completedAsUser,
            createdAt: instance.createdAt
        )
        instances[id] = instance
        return instance
    }

    // MARK: - Ledger & Redemption

    public func requestRedemption(_ req: RequestRedemptionRequest) async throws -> RedemptionRequest {
        guard let reward = rewards[req.rewardId] else { throw APIError.rewardUnavailable }
        guard let user = users[req.userId], user.cachedBalance >= reward.price else {
            throw APIError.insufficientBalance
        }
        let redemption = RedemptionRequest(
            id: UUID(), familyId: SeedID.family, userId: req.userId, rewardId: req.rewardId,
            requestedAt: Date(), status: .pending, approvedByUserId: nil, approvedAt: nil,
            resultingTransactionId: nil, notes: nil, createdAt: Date()
        )
        redemptions[redemption.id] = redemption
        return redemption
    }

    public func approveRedemption(_ id: UUID, appAttestToken: String) async throws -> RedemptionApprovedResponse {
        guard var redemption = redemptions[id] else { throw APIError.notFound }
        guard let reward = rewards[redemption.rewardId] else { throw APIError.rewardUnavailable }
        let txn = PointTransaction(
            id: UUID(), userId: redemption.userId, familyId: SeedID.family,
            amount: -reward.price, kind: .redemption, referenceId: redemption.rewardId,
            reason: "Reward: \(reward.name)", createdByUserId: redemption.userId,
            idempotencyKey: UUID(), choreInstanceId: nil, createdAt: Date(),
            reversedByTransactionId: nil
        )
        transactions[txn.id] = txn
        redemption = RedemptionRequest(
            id: redemption.id, familyId: redemption.familyId, userId: redemption.userId,
            rewardId: redemption.rewardId, requestedAt: redemption.requestedAt,
            status: .fulfilled, approvedByUserId: SeedID.mei, approvedAt: Date(),
            resultingTransactionId: txn.id, notes: nil, createdAt: redemption.createdAt
        )
        redemptions[id] = redemption
        let balanceAfter = (users[redemption.userId]?.cachedBalance ?? 0) - reward.price
        return RedemptionApprovedResponse(redemptionRequest: redemption, transaction: txn, balanceAfter: balanceAfter)
    }

    public func denyRedemption(_ id: UUID, reason: String?) async throws -> RedemptionRequest {
        guard var redemption = redemptions[id] else { throw APIError.notFound }
        redemption = RedemptionRequest(
            id: redemption.id, familyId: redemption.familyId, userId: redemption.userId,
            rewardId: redemption.rewardId, requestedAt: redemption.requestedAt,
            status: .denied, approvedByUserId: nil, approvedAt: nil,
            resultingTransactionId: nil, notes: reason, createdAt: redemption.createdAt
        )
        redemptions[id] = redemption
        return redemption
    }

    public func issueFine(_ req: IssueFineRequest) async throws -> PointTransaction {
        let txn = PointTransaction(
            id: UUID(), userId: req.userId, familyId: SeedID.family,
            amount: -req.amount, kind: .fine, referenceId: nil,
            reason: req.reason, createdByUserId: SeedID.mei,
            idempotencyKey: UUID(), choreInstanceId: nil, createdAt: Date(),
            reversedByTransactionId: nil
        )
        transactions[txn.id] = txn
        return txn
    }

    public func reverseTransaction(_ id: UUID, reason: String, appAttestToken: String) async throws -> PointTransaction {
        guard let original = transactions[id] else { throw APIError.notFound }
        let reversal = PointTransaction(
            id: UUID(), userId: original.userId, familyId: original.familyId,
            amount: -original.amount, kind: .correction, referenceId: original.id,
            reason: reason, createdByUserId: SeedID.mei,
            idempotencyKey: UUID(), choreInstanceId: nil, createdAt: Date(),
            reversedByTransactionId: nil
        )
        transactions[reversal.id] = reversal
        return reversal
    }

    // MARK: - Challenges / Quests

    public func fetchChallenges(familyId: UUID) async throws -> [Challenge] {
        challenges.values.filter { $0.familyId == familyId }.sorted { $0.startAt < $1.startAt }
    }

    // MARK: - Subscription

    public func updateSubscription(_ receipt: String) async throws -> Subscription {
        return subscription
    }

    // MARK: - Notifications

    public func registerAPNSToken(_ token: String, appBundle: String) async throws {
        // no-op in mock
    }

    // MARK: - Read / List

    public func listFamilyUsers(familyId: UUID) async throws -> [AppUser] {
        users.values.filter { $0.familyId == familyId }
    }

    public func listChoreTemplates(familyId: UUID) async throws -> [ChoreTemplate] {
        templates.values.filter { $0.familyId == familyId && $0.active }
    }

    public func listTodayChoreInstances(familyId: UUID) async throws -> [ChoreInstance] {
        let today = Self.isoDate(from: Date())
        // Filter instances whose owning user belongs to the family
        let familyUserIds = Set(users.values.filter { $0.familyId == familyId }.map { $0.id })
        return instances.values.filter { familyUserIds.contains($0.userId) && $0.scheduledFor == today }
    }

    public func listPendingApprovals(familyId: UUID) async throws -> [ChoreInstance] {
        let familyUserIds = Set(users.values.filter { $0.familyId == familyId }.map { $0.id })
        return instances.values.filter {
            familyUserIds.contains($0.userId) &&
            ($0.status == .completed || $0.status == .pending)
        }
    }

    public func listTransactions(userId: UUID, limit: Int) async throws -> [PointTransaction] {
        let sorted = transactions.values
            .filter { $0.userId == userId }
            .sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(limit))
    }

    public func listRewards(familyId: UUID) async throws -> [Reward] {
        rewards.values.filter { $0.familyId == familyId && $0.active }
    }

    public func listPendingRedemptions(familyId: UUID) async throws -> [RedemptionRequest] {
        redemptions.values.filter { $0.familyId == familyId && $0.status == .pending }
    }

    public func listStreaks(familyId: UUID) async throws -> [Streak] {
        // No streaks in seed data; returns empty array.
        []
    }

    public func fetchFamily(id: UUID) async throws -> Family {
        guard let family = families[id] else { throw APIError.notFound }
        return family
    }

    public func fetchSubscription(familyId: UUID) async throws -> Subscription? {
        guard subscription.familyId == familyId else { return nil }
        return subscription
    }
}
