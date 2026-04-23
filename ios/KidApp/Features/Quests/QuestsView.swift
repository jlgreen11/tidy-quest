import SwiftUI
import TidyQuestCore

// MARK: - QuestsView

/// Quests tab — displays active quest hero card, constituent chores, completed and upcoming quests.
/// Tier-aware: Zara (advanced, 12y) gets challenge-y styling; Ava (starter, 6y) gets friendly gold-star styling.
@MainActor
struct QuestsView: View {
    let kid: AppUser
    let questRepository: QuestRepository
    let choreRepository: ChoreRepository

    @Environment(\.tierTheme) private var tier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: tier == .starter ? 20 : 16) {
                    if questRepository.activeQuests.isEmpty
                        && questRepository.upcomingQuests.isEmpty
                        && questRepository.completedQuests.isEmpty {
                        emptyStateView
                            .padding(.horizontal, 16)
                            .padding(.top, 40)
                    } else {
                        // Active quest hero card
                        if let activeQuest = questRepository.activeQuests.first {
                            activeQuestHeroCard(activeQuest)
                                .padding(.horizontal, 16)
                        }

                        // Upcoming quests
                        if !questRepository.upcomingQuests.isEmpty {
                            upcomingSection
                                .padding(.horizontal, 16)
                        }

                        // Completed quests
                        if !questRepository.completedQuests.isEmpty {
                            completedSection
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle(tier == .starter ? "Your Quests" : "Quests")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            // Subscribe to kidHome scope to get realtime chore completions within quest
            // In production: RealtimeSubscription.scope(for: .kidHome(kidId: kid.id))
        }
    }

    // MARK: - Active quest hero card

    @ViewBuilder
    private func activeQuestHeroCard(_ quest: Challenge) -> some View {
        let prog = questRepository.progress(
            for: quest,
            userId: kid.id,
            instances: choreRepository.instances(for: kid.id)
        )
        NavigationLink(destination: QuestDetailView(
            quest: quest,
            kid: kid,
            questRepository: questRepository,
            choreRepository: choreRepository
        )) {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier == .starter ? "Active Quest" : "Active Challenge")
                            .font(tier.captionFont)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(quest.name)
                            .font(tier.headlineFont)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    // Countdown
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(countdownString(to: quest.endAt))
                            .font(tier.captionFont)
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                        Text("left")
                            .font(tier.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }

                // Tier-aware progress ring
                HStack(spacing: 16) {
                    questProgressRing(completed: prog.completed, total: prog.total)
                    VStack(alignment: .leading, spacing: 4) {
                        if tier == .starter {
                            Text("\(prog.completed) of \(prog.total) done!")
                                .font(tier.bodyFont)
                                .foregroundStyle(.primary)
                        } else {
                            Text("\(prog.completed) / \(prog.total) chores")
                                .font(tier.bodyFont)
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                            Text("+\(quest.bonusPoints) bonus")
                                .font(tier.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                // Description
                if let desc = quest.description, tier != .starter {
                    Text(desc)
                        .font(tier.captionFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Constituent chores for this kid
                let kidTemplateIds = Set(quest.constituentChoreTemplateIds)
                let kidInstances = choreRepository.instances(for: kid.id)
                    .filter { kidTemplateIds.contains($0.templateId) }
                if !kidInstances.isEmpty {
                    Divider()
                    Text(tier == .starter ? "Your chores:" : "Your quest chores")
                        .font(tier.captionFont)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 8) {
                        ForEach(kidInstances) { inst in
                            if let tmpl = choreRepository.templates.first(where: { $0.id == inst.templateId }) {
                                QuestChoreTileRow(instance: inst, template: tmpl, tier: tier)
                            }
                        }
                    }
                }
            }
            .padding(tier == .starter ? 20 : 16)
            .background(questHeroBackground)
            .clipShape(RoundedRectangle(cornerRadius: tier.tileCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: tier.tileCornerRadius)
                    .stroke(questHeroBorder, lineWidth: tier == .advanced ? 1 : 2)
            )
            .shadow(
                color: questShadowColor.opacity(0.15),
                radius: tier == .starter ? 8 : 4,
                x: 0, y: 2
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(quest.name). \(prog.completed) of \(prog.total) chores done. \(countdownString(to: quest.endAt)) left. Tap for details."
        )
    }

    // MARK: - Progress ring (tier-aware)

    @ViewBuilder
    private func questProgressRing(completed: Int, total: Int) -> some View {
        let fraction: CGFloat = total > 0 ? CGFloat(completed) / CGFloat(total) : 0
        let size: CGFloat = tier == .starter ? 72 : (tier == .standard ? 60 : 48)
        let strokeWidth: CGFloat = tier == .starter ? 10 : 7

        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(questRingColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .spring(duration: 0.6), value: completed)

            if tier == .starter {
                Image(systemName: fraction >= 1.0 ? "star.fill" : "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(fraction >= 1.0 ? Color.yellow : questRingColor)
            } else {
                Text("\(Int(fraction * 100))%")
                    .font(.system(size: tier == .advanced ? 11 : 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - Upcoming section

    @ViewBuilder
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)
            ForEach(questRepository.upcomingQuests) { quest in
                upcomingQuestCard(quest)
            }
        }
    }

    private func upcomingQuestCard(_ quest: Challenge) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.fill")
                .font(.title2)
                .foregroundStyle(.blue.opacity(0.7))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.name)
                    .font(tier.bodyFont)
                    .foregroundStyle(.primary)
                Text("Starts \(quest.startAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("+\(quest.bonusPoints)")
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: tier.tileCornerRadius - 4))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quest.name). Starts \(quest.startAt.formatted(date: .abbreviated, time: .omitted)). Bonus \(quest.bonusPoints) points.")
    }

    // MARK: - Completed section

    @ViewBuilder
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Completed")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)
            ForEach(questRepository.completedQuests) { quest in
                completedQuestCard(quest)
            }
        }
    }

    private func completedQuestCard(_ quest: Challenge) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(quest.name)
                .font(tier.bodyFont)
                .foregroundStyle(.primary)
            Spacer()
            Text("You earned +\(quest.bonusPoints)!")
                .font(tier.captionFont)
                .foregroundStyle(.green)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: tier.tileCornerRadius - 4))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quest.name). Completed. You earned \(quest.bonusPoints) bonus points.")
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if tier == .starter {
                Text("🗺️")
                    .font(.system(size: 72))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "map.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Text("No quests right now.")
                .font(tier.headlineFont)
                .foregroundStyle(.primary)
            Text("Check back soon!")
                .font(tier.bodyFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No quests right now. Check back soon!")
    }

    // MARK: - Tier-aware colors

    private var questRingColor: Color {
        switch tier {
        case .starter: .yellow
        case .standard: Color(hex: "4D96FF") ?? .blue
        case .advanced: Color(hex: "B983FF") ?? .purple
        }
    }

    private var questHeroBackground: some ShapeStyle {
        switch tier {
        case .starter:
            return AnyShapeStyle(LinearGradient(
                colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .standard:
            return AnyShapeStyle((Color(hex: "4D96FF") ?? .blue).opacity(0.07))
        case .advanced:
            return AnyShapeStyle((Color(hex: "B983FF") ?? .purple).opacity(0.06))
        }
    }

    private var questHeroBorder: Color {
        switch tier {
        case .starter: .yellow.opacity(0.5)
        case .standard: (Color(hex: "4D96FF") ?? .blue).opacity(0.3)
        case .advanced: (Color(hex: "B983FF") ?? .purple).opacity(0.3)
        }
    }

    private var questShadowColor: Color {
        switch tier {
        case .starter: .yellow
        case .standard: Color(hex: "4D96FF") ?? .blue
        case .advanced: Color(hex: "B983FF") ?? .purple
        }
    }

    // MARK: - Countdown helper

    private func countdownString(to date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        guard interval > 0 else { return "Ended" }
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let mins = (Int(interval) % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}

// MARK: - QuestChoreTileRow

/// Compact chore row used inside the quest hero card (quest-tinted, not full ChoreTile).
struct QuestChoreTileRow: View {
    let instance: ChoreInstance
    let template: ChoreTemplate
    let tier: Tier

    private var isDone: Bool {
        instance.status == .completed || instance.status == .approved
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: tier == .starter ? 22 : 18))
                .foregroundStyle(isDone ? Color.green : Color.secondary.opacity(0.4))
                .accessibilityHidden(true)
            Text(template.name)
                .font(tier.bodyFont)
                .foregroundStyle(isDone ? .secondary : .primary)
                .strikethrough(isDone)
            Spacer()
            Text("+\(template.basePoints)")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(template.name), \(template.basePoints) points, \(isDone ? "done" : "pending")")
    }
}

// MARK: - Preview

#Preview("QuestsView — Active quest (Zara, Advanced)") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let quest = QuestRepository(apiClient: api)
    quest.loadSeedData()
    let zara = MockAPIClient.seedUsers.first(where: { $0.id == MockAPIClient.SeedID.zara })!
    return QuestsView(kid: zara, questRepository: quest, choreRepository: chore)
        .tierTheme(.advanced)
}

#Preview("QuestsView — Active quest (Ava, Starter)") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let quest = QuestRepository(apiClient: api)
    quest.loadSeedData()
    let ava = MockAPIClient.seedUsers.first(where: { $0.id == MockAPIClient.SeedID.ava })!
    return QuestsView(kid: ava, questRepository: quest, choreRepository: chore)
        .tierTheme(.starter)
}

#Preview("QuestsView — Empty state (Standard)") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let quest = QuestRepository(apiClient: api)
    // No seed — empty state
    let kai = MockAPIClient.seedUsers.first(where: { $0.id == MockAPIClient.SeedID.kai })!
    return QuestsView(kid: kai, questRepository: quest, choreRepository: chore)
        .tierTheme(.standard)
}
