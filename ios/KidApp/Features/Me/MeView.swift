import SwiftUI
import TidyQuestCore

// MARK: - MeView

/// Me tab — avatar, streaks, achievements, ledger subscreen, and kid settings.
/// Ledger is accessed as a disclosure row, per PLAN §5.2.
@MainActor
struct MeView: View {
    let kid: AppUser
    let choreRepository: ChoreRepository
    let ledgerRepository: LedgerRepository

    @Environment(\.tierTheme) private var environmentTier
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Local state

    @State private var soundEnabled: Bool = true
    @State private var showLedger = false

    #if DEBUG
    /// DEBUG-only: overrides the kid's real tier for visual QA.
    /// nil = use the environment tier from the kid's ComplexityTier.
    @State private var debugTierOverride: Tier? = nil
    #endif

    // MARK: - Effective tier

    /// The tier used for rendering — honours the DEBUG switcher when set.
    private var tier: Tier {
        #if DEBUG
        return debugTierOverride ?? environmentTier
        #else
        return environmentTier
        #endif
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                #if DEBUG
                // DEBUG banner: shows when the tier switcher is active
                if let override = debugTierOverride {
                    Section {
                        Label(
                            "DEBUG: Tier overridden to \(override.debugLabel)",
                            systemImage: "hammer.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    }
                }
                #endif

                // Avatar section
                avatarSection

                // Streaks section (Standard / Advanced only)
                if tier != .starter {
                    streaksSection
                }

                // Achievements section
                achievementsSection

                // Ledger disclosure row
                Section {
                    NavigationLink(destination: LedgerView(
                        kid: kid,
                        ledgerRepository: ledgerRepository
                    )) {
                        Label("Point History", systemImage: "list.bullet.rectangle.fill")
                            .font(tier.bodyFont)
                            .accessibilityLabel("Point history — see all your earned and spent points")
                    }
                    .frame(minHeight: tier.minTapTarget)
                }

                // Kid settings
                settingsSection
            }
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.large)
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        debugTierOverride = (debugTierOverride ?? environmentTier).nextDebugTier
                    } label: {
                        Label(
                            "Switch tier",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .foregroundStyle(.orange)
                    }
                    .accessibilityLabel("DEBUG: cycle complexity tier")
                }
            }
            #endif
        }
        .tierTheme(tier)
    }

    // MARK: - Avatar section

    private var avatarSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .strokeBorder(Color(hex: kid.color) ?? .accentColor, lineWidth: tier == .starter ? 5 : 3)
                        .frame(
                            width: tier == .starter ? 88 : (tier == .standard ? 72 : 60),
                            height: tier == .starter ? 88 : (tier == .standard ? 72 : 60)
                        )
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: tier == .starter ? 64 : (tier == .standard ? 52 : 44)))
                        .foregroundStyle(Color(hex: kid.color) ?? .accentColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(kid.displayName)
                        .font(tier.headlineFont)
                        .foregroundStyle(.primary)
                    if tier.showNumericBalance {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                            Text("\(ledgerRepository.balance(for: kid.id)) points")
                                .font(tier.captionFont)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    } else {
                        Text("Keep it up!")
                            .font(tier.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(kid.displayName). \(ledgerRepository.balance(for: kid.id)) points.")
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Streaks section

    @ViewBuilder
    private var streaksSection: some View {
        let streaks = choreRepository.streaks.filter { $0.userId == kid.id && $0.currentLength > 0 }
        Section {
            if streaks.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "flame")
                        .font(.body)
                        .foregroundStyle(.orange.opacity(0.5))
                        .accessibilityHidden(true)
                    Text("Complete chores daily to build streaks!")
                        .font(tier.bodyFont)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: tier.minTapTarget)
            } else {
                ForEach(streaks) { streak in
                    streakRow(streak)
                }
            }
        } header: {
            Text("Streaks")
                .font(tier.captionFont)
        }
    }

    private func streakRow(_ streak: Streak) -> some View {
        let choreName: String = {
            if let tmplId = streak.choreTemplateId {
                return choreRepository.templates.first(where: { $0.id == tmplId })?.name ?? "Chore"
            }
            return "Routine"
        }()
        return HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(tier == .standard ? .title3 : .body)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(choreName)
                    .font(tier.bodyFont)
                    .foregroundStyle(.primary)
                Text("Longest: \(streak.longestLength) days")
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(streak.currentLength)")
                .font(.system(size: tier == .standard ? 26 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .monospacedDigit()
            Text("days")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: tier.minTapTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(choreName) streak: \(streak.currentLength) days. Longest: \(streak.longestLength) days.")
    }

    // MARK: - Achievements section

    private var achievementsSection: some View {
        Section {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: tier == .starter ? 16 : 12) {
                ForEach(Achievement.mvpBadges(for: kid, ledger: ledgerRepository, chores: choreRepository)) { badge in
                    AchievementBadge(badge: badge, tier: tier)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Achievements")
                .font(tier.captionFont)
        }
    }

    // MARK: - Settings section

    private var settingsSection: some View {
        Section("Settings") {
            // Sound toggle
            Toggle(isOn: $soundEnabled) {
                Label("Sound effects", systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(tier.bodyFont)
            }
            .frame(minHeight: tier.minTapTarget)
            .accessibilityLabel("Sound effects \(soundEnabled ? "on" : "off"). Double-tap to toggle.")
        }
    }
}

// MARK: - Achievement model (MVP stubs)

struct Achievement: Identifiable {
    let id: String
    let title: String
    let icon: String
    let description: String
    var earned: Bool

    static func mvpBadges(
        for kid: AppUser,
        ledger: LedgerRepository,
        chores: ChoreRepository
    ) -> [Achievement] {
        let txns = ledger.transactions(for: kid.id)
        let hasFirstChore = txns.contains { $0.kind == .choreCompletion }
        let has7DayStreak = chores.streaks.first { $0.userId == kid.id && $0.currentLength >= 7 } != nil
        let dailyMax = txns
            .filter { $0.amount > 0 }
            .reduce(into: [String: Int]()) { acc, txn in
                let day = txn.createdAt.formatted(.dateTime.year().month().day())
                acc[day, default: 0] += txn.amount
            }
            .values.max() ?? 0
        let has10PtDay = dailyMax >= 10

        return [
            Achievement(
                id: "first_chore",
                title: "First Chore!",
                icon: "checkmark.circle.fill",
                description: "Complete your very first chore",
                earned: hasFirstChore
            ),
            Achievement(
                id: "streak_7",
                title: "7-Day Streak",
                icon: "flame.fill",
                description: "7 days in a row",
                earned: has7DayStreak
            ),
            Achievement(
                id: "10pt_day",
                title: "10-Point Day",
                icon: "star.fill",
                description: "Earn 10+ points in one day",
                earned: has10PtDay
            )
        ]
    }
}

// MARK: - AchievementBadge

struct AchievementBadge: View {
    let badge: Achievement
    let tier: Tier

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.earned
                          ? Color.yellow.opacity(0.18)
                          : Color.secondary.opacity(0.08))
                    .frame(
                        width: tier == .starter ? 72 : (tier == .standard ? 60 : 50),
                        height: tier == .starter ? 72 : (tier == .standard ? 60 : 50)
                    )
                Image(systemName: badge.icon)
                    .font(.system(size: tier == .starter ? 30 : 24))
                    .foregroundStyle(badge.earned ? Color.yellow : Color.secondary.opacity(0.35))
                    .saturation(badge.earned ? 1.0 : 0.0)
            }
            Text(badge.title)
                .font(tier == .starter
                      ? .system(size: 12, weight: .semibold, design: .rounded)
                      : .system(size: 11, weight: .regular))
                .foregroundStyle(badge.earned ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(minHeight: tier.minTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title). \(badge.description). \(badge.earned ? "Earned!" : "Not yet earned.")")
    }
}

// MARK: - DEBUG Tier helpers

#if DEBUG
private extension Tier {
    /// Human-readable label used by the DEBUG tier switcher banner.
    var debugLabel: String {
        switch self {
        case .starter:  "Starter"
        case .standard: "Standard"
        case .advanced: "Advanced"
        }
    }

    /// Cycles Starter → Standard → Advanced → Starter.
    var nextDebugTier: Tier {
        switch self {
        case .starter:  .standard
        case .standard: .advanced
        case .advanced: .starter
        }
    }
}
#endif

// MARK: - Preview

#Preview("MeView — Standard (Kai)") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let kai = MockAPIClient.seedUsers.first(where: { $0.id == MockAPIClient.SeedID.kai })!
    ledger.setBalance(kai.cachedBalance, for: kai.id)
    return MeView(kid: kai, choreRepository: chore, ledgerRepository: ledger)
        .tierTheme(.standard)
}

#Preview("MeView — Starter (Ava)") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let ava = MockAPIClient.seedUsers.first(where: { $0.id == MockAPIClient.SeedID.ava })!
    ledger.setBalance(ava.cachedBalance, for: ava.id)
    return MeView(kid: ava, choreRepository: chore, ledgerRepository: ledger)
        .tierTheme(.starter)
}

#Preview("MeView — Advanced (Zara)") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let ledger = LedgerRepository(apiClient: api)
    let zara = MockAPIClient.seedUsers.first(where: { $0.id == MockAPIClient.SeedID.zara })!
    ledger.setBalance(zara.cachedBalance, for: zara.id)
    return MeView(kid: zara, choreRepository: chore, ledgerRepository: ledger)
        .tierTheme(.advanced)
}
