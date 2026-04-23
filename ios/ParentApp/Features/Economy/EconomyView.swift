import SwiftUI
import TidyQuestCore

// MARK: - Navigation Route

enum EconomyRoute: Hashable {
    case streakDetail(kidId: UUID)
}

// MARK: - EconomyView

@available(iOS 17, *)
struct EconomyView: View {

    var familyRepo: FamilyRepository
    var choreRepo: ChoreRepository
    var ledgerRepo: LedgerRepository
    var rewardRepo: RewardRepository

    // Navigation path used for deep-links (e.g. Inflation Alert → FamilyView)
    @Binding var familyPath: NavigationPath

    @State private var economyPath = NavigationPath()

    // MARK: - Computed helpers

    private var kids: [AppUser] { familyRepo.kids }

    /// Parse "[low,high)" int4range string from Postgres.
    private var bandRange: (low: Int, high: Int)? {
        guard let raw = familyRepo.family?.weeklyBandTarget else { return nil }
        let stripped = raw.trimmingCharacters(in: CharacterSet(charactersIn: "[(])"))
        let parts = stripped.split(separator: ",")
        guard parts.count == 2,
              let lo = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let hi = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return (lo, hi)
    }

    /// Expected weekly earnings per kid based on active templates.
    private func weeklyEarnings(for kid: AppUser) -> Int {
        choreRepo.templates
            .filter { $0.targetUserIds.contains(kid.id) && $0.active }
            .reduce(0) { sum, t in
                let daysPerWeek: Int
                if let days = t.schedule["daysOfWeek"]?.value as? [Any] {
                    daysPerWeek = days.count
                } else {
                    daysPerWeek = 7
                }
                return sum + t.basePoints * daysPerWeek
            }
    }

    private var maxWeeklyEarnings: Int {
        kids.map { weeklyEarnings(for: $0) }.max() ?? 1
    }

    /// Kids whose earnings drift outside the band by > 20%.
    private var inflationAlertKids: [AppUser] {
        guard let band = bandRange else { return [] }
        let threshold = 0.20
        return kids.filter { kid in
            let earnings = weeklyEarnings(for: kid)
            let low = Double(band.low) * (1.0 - threshold)
            let high = Double(band.high) * (1.0 + threshold)
            return Double(earnings) < low || Double(earnings) > high
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $economyPath) {
            ScrollView {
                LazyVStack(spacing: 20) {
                    weeklyEarningsCard
                    rewardAffordabilityCard
                    streakParticipationCard
                    if !inflationAlertKids.isEmpty {
                        inflationAlertCard
                    }
                    thisWeekSummaryCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .navigationTitle("Economy")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: EconomyRoute.self) { route in
                switch route {
                case .streakDetail(let kidId):
                    if let kid = kids.first(where: { $0.id == kidId }) {
                        StreakDetailView(kid: kid, choreRepo: choreRepo)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Cards

    private var weeklyEarningsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Label("Expected Weekly Earnings", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if kids.isEmpty {
                    Text("No kids in family yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(kids) { kid in
                        KidEarningsBar(
                            kid: kid,
                            earnings: weeklyEarnings(for: kid),
                            maxEarnings: maxWeeklyEarnings,
                            bandRange: bandRange
                        )
                    }
                }
            }
        }
    }

    private var rewardAffordabilityCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Reward Affordability", systemImage: "gift.fill")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if rewardRepo.activeRewards.isEmpty || kids.isEmpty {
                    Text("Add rewards and kids to see affordability.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rewardRepo.activeRewards.prefix(5)) { reward in
                        AffordabilityRow(
                            reward: reward,
                            kids: kids,
                            weeklyEarnings: { weeklyEarnings(for: $0) }
                        )
                        if reward.id != rewardRepo.activeRewards.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var streakParticipationCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Streak Participation", systemImage: "flame.fill")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if kids.isEmpty {
                    Text("No kids yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(kids) { kid in
                        let kidStreaks = choreRepo.streaks.filter { $0.userId == kid.id }
                        Button {
                            economyPath.append(EconomyRoute.streakDetail(kidId: kid.id))
                        } label: {
                            StreakParticipationRow(kid: kid, streaks: kidStreaks)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(kid.displayName) streaks. Tap for details.")
                        if kid.id != kids.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private var inflationAlertCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Inflation Alert", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .accessibilityAddTraits(.isHeader)

                ForEach(inflationAlertKids) { kid in
                    let earnings = weeklyEarnings(for: kid)
                    HStack {
                        KidColorDot(hexColor: kid.color)
                        Text("\(kid.displayName) earning \(earnings) pts/wk — outside target band")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .accessibilityLabel("\(kid.displayName) is earning \(earnings) points per week, outside the target band.")
                }

                Button {
                    familyPath.append("chores")
                } label: {
                    Label("Tune chore values", systemImage: "slider.horizontal.3")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.red)
                }
                .accessibilityHint("Opens the Family Chores settings to adjust point values.")
            }
        }
    }

    private var thisWeekSummaryCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Label("This Week", systemImage: "calendar.badge.checkmark")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if kids.isEmpty {
                    Text("No data yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(kids) { kid in
                        ThisWeekKidRow(
                            kid: kid,
                            choreRepo: choreRepo,
                            ledgerRepo: ledgerRepo,
                            rewardRepo: rewardRepo
                        )
                        if kid.id != kids.last?.id { Divider() }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

@available(iOS 17, *)
private struct KidEarningsBar: View {
    let kid: AppUser
    let earnings: Int
    let maxEarnings: Int
    let bandRange: (low: Int, high: Int)?

    private var kidColor: Color {
        Color(hex: kid.color) ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                KidColorDot(hexColor: kid.color)
                Text(kid.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(earnings) pts/wk")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(earnings) points per week")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Band overlay
                    if let band = bandRange, maxEarnings > 0 {
                        let lo = CGFloat(band.low) / CGFloat(maxEarnings)
                        let hi = min(CGFloat(band.high) / CGFloat(maxEarnings), 1.0)
                        Rectangle()
                            .fill(Color.green.opacity(0.15))
                            .frame(
                                width: geo.size.width * (hi - lo),
                                height: 10
                            )
                            .offset(x: geo.size.width * lo)
                            .cornerRadius(5)
                            .accessibilityHidden(true)
                    }

                    // Track
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 10)

                    // Fill
                    Capsule()
                        .fill(kidColor)
                        .frame(
                            width: maxEarnings > 0
                                ? geo.size.width * min(CGFloat(earnings) / CGFloat(maxEarnings), 1.0)
                                : 0,
                            height: 10
                        )
                        .animation(.easeOut(duration: 0.4), value: earnings)
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kid.displayName), \(earnings) points per week expected")
    }
}

@available(iOS 17, *)
private struct AffordabilityRow: View {
    let reward: Reward
    let kids: [AppUser]
    let weeklyEarnings: (AppUser) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: reward.icon)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(reward.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(reward.price) pts")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(kids) { kid in
                let earned = weeklyEarnings(kid)
                let daysText: String = {
                    if earned <= 0 { return "\(kid.displayName) cannot afford this yet" }
                    let days = Int(ceil(Double(reward.price) / Double(earned) * 7.0))
                    if days <= 0 { return "\(kid.displayName) can afford this now" }
                    return "\(kid.displayName) can afford this in ~\(days) day\(days == 1 ? "" : "s")"
                }()
                Text(daysText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 17, *)
private struct StreakParticipationRow: View {
    let kid: AppUser
    let streaks: [Streak]

    private var longestStreak: Int {
        streaks.map { $0.longestLength }.max() ?? 0
    }
    private var currentStreak: Int {
        streaks.map { $0.currentLength }.max() ?? 0
    }

    var body: some View {
        HStack {
            KidColorDot(hexColor: kid.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(kid.displayName)
                    .font(.subheadline.weight(.medium))
                Text("Current: \(currentStreak) day\(currentStreak == 1 ? "" : "s")  •  Longest: \(longestStreak)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

@available(iOS 17, *)
private struct ThisWeekKidRow: View {
    let kid: AppUser
    var choreRepo: ChoreRepository
    var ledgerRepo: LedgerRepository
    var rewardRepo: RewardRepository

    private var completedCount: Int {
        choreRepo.todayInstances
            .filter { $0.userId == kid.id && ($0.status == .completed || $0.status == .approved) }
            .count
    }

    private var finesCount: Int {
        ledgerRepo.transactions(for: kid.id)
            .filter { $0.kind == .fine }
            .count
    }

    private var redemptionsCount: Int {
        rewardRepo.redemptions
            .filter { $0.userId == kid.id && $0.status == .fulfilled }
            .count
    }

    var body: some View {
        HStack(spacing: 0) {
            KidColorDot(hexColor: kid.color)
            Text(kid.displayName)
                .font(.subheadline.weight(.medium))
                .padding(.leading, 6)
            Spacer()
            HStack(spacing: 16) {
                StatPill(value: completedCount, label: "done", icon: "checkmark.circle.fill", color: .green)
                StatPill(value: finesCount, label: "fines", icon: "minus.circle.fill", color: .red)
                StatPill(value: redemptionsCount, label: "redeemed", icon: "gift.fill", color: .purple)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(kid.displayName): \(completedCount) chores done, \(finesCount) fines, \(redemptionsCount) redemptions this week."
        )
    }
}

private struct StatPill: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("\(value) \(label)")
    }
}

private struct KidColorDot: View {
    let hexColor: String

    var body: some View {
        Circle()
            .fill(Color(hex: hexColor) ?? .accentColor)
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }
}

private struct CardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Color extension

private extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        self.init(
            red:   Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue:  Double( rgbValue & 0x0000FF) / 255.0
        )
    }
}

// MARK: - Preview

#Preview("EconomyView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    let chore = ChoreRepository(apiClient: client)
    let ledger = LedgerRepository(apiClient: client)
    let reward = RewardRepository(apiClient: client)
    family.loadSeedData()
    chore.loadSeedInstances(MockAPIClient.seedTemplates.prefix(3).map { t in
        ChoreInstance(
            id: UUID(), templateId: t.id, userId: t.targetUserIds[0],
            scheduledFor: "2026-04-22", windowStart: nil, windowEnd: nil,
            status: .approved, completedAt: Date(), approvedAt: Date(),
            proofPhotoId: nil, awardedPoints: t.basePoints,
            completedByDevice: nil, completedAsUser: nil, createdAt: Date()
        )
    })
    return NavigationStack {
        EconomyView(
            familyRepo: family,
            choreRepo: chore,
            ledgerRepo: ledger,
            rewardRepo: reward,
            familyPath: .constant(NavigationPath())
        )
    }
}
