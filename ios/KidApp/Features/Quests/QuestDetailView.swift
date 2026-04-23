import SwiftUI
import TidyQuestCore

// MARK: - QuestDetailView

/// Full quest breakdown — all participants, all constituent chores, rules, and reward.
/// Presented as a NavigationLink destination from QuestsView.
@MainActor
struct QuestDetailView: View {
    let quest: Challenge
    let kid: AppUser
    let questRepository: QuestRepository
    let choreRepository: ChoreRepository

    @Environment(\.tierTheme) private var tier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    // MARK: - Derived

    private var isFamilyWide: Bool { quest.participantUserIds.count > 1 }

    private var myProgress: (completed: Int, total: Int) {
        questRepository.progress(
            for: quest,
            userId: kid.id,
            instances: choreRepository.instances(for: kid.id)
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero header
                heroHeader
                    .padding(.horizontal, 16)

                // Description
                if let desc = quest.description {
                    Text(desc)
                        .font(tier.bodyFont)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .accessibilityLabel("Quest description: \(desc)")
                }

                // Family cooperation hint
                if isFamilyWide {
                    cooperationBanner
                        .padding(.horizontal, 16)
                }

                Divider()
                    .padding(.horizontal, 16)

                // My chores section
                myChoresSection
                    .padding(.horizontal, 16)

                // Rules / bonus section
                rulesSection
                    .padding(.horizontal, 16)

                // Deadline
                deadlineRow
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(quest.name)
        .navigationBarTitleDisplayMode(tier == .starter ? .large : .inline)
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        HStack(spacing: 16) {
            questRing
            VStack(alignment: .leading, spacing: 6) {
                Text(tier == .starter ? "Quest Progress" : "Your progress")
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
                Text("\(myProgress.completed) of \(myProgress.total) done")
                    .font(tier.headlineFont)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                if myProgress.completed == myProgress.total && myProgress.total > 0 {
                    Text("All done — waiting for Sunday!")
                        .font(tier.captionFont)
                        .foregroundStyle(.green)
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your quest progress: \(myProgress.completed) of \(myProgress.total) chores done.")
    }

    @ViewBuilder
    private var questRing: some View {
        let fraction: CGFloat = myProgress.total > 0
            ? CGFloat(myProgress.completed) / CGFloat(myProgress.total) : 0
        let size: CGFloat = tier == .starter ? 80 : 64
        let stroke: CGFloat = tier == .starter ? 10 : 7

        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: stroke)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .spring(duration: 0.6), value: myProgress.completed)
            if tier == .starter {
                Image(systemName: fraction >= 1.0 ? "star.fill" : "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(fraction >= 1.0 ? Color.yellow : ringColor)
            } else {
                Text("\(Int(fraction * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - Cooperation banner

    private var cooperationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.3.fill")
                .font(tier == .starter ? .title2 : .title3)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("All kids together!")
                    .font(tier.bodyFont)
                    .foregroundStyle(.primary)
                Text("Everyone earns the bonus when the quest is complete.")
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: tier.tileCornerRadius - 4))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All kids together! Everyone earns the bonus when the quest is complete.")
    }

    // MARK: - My chores

    @ViewBuilder
    private var myChoresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tier == .starter ? "Your chores" : "Quest chores")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)

            let kidTemplateIds = Set(quest.constituentChoreTemplateIds)
            let kidInstances = choreRepository.instances(for: kid.id)
                .filter { kidTemplateIds.contains($0.templateId) }

            if kidInstances.isEmpty {
                Text("No chores assigned to you for this quest.")
                    .font(tier.bodyFont)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(kidInstances) { inst in
                    if let tmpl = choreRepository.templates.first(where: { $0.id == inst.templateId }) {
                        detailChoreRow(inst, tmpl)
                    }
                }
            }
        }
    }

    private func detailChoreRow(_ instance: ChoreInstance, _ template: ChoreTemplate) -> some View {
        let isDone = instance.status == .completed || instance.status == .approved
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green.opacity(0.15) : Color.secondary.opacity(0.08))
                    .frame(width: tier == .starter ? 48 : 40, height: tier == .starter ? 48 : 40)
                Image(systemName: isDone ? "checkmark" : template.icon)
                    .font(.system(size: tier == .starter ? 20 : 16, weight: isDone ? .bold : .regular))
                    .foregroundStyle(isDone ? Color.green : Color.secondary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(tier.bodyFont)
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .strikethrough(isDone)
                if isDone {
                    Text("Done!")
                        .font(tier.captionFont)
                        .foregroundStyle(.green)
                } else {
                    Text("+\(template.basePoints) pts")
                        .font(tier.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .frame(minHeight: tier.minTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(template.name), \(template.basePoints) points, \(isDone ? "done" : "not done yet")")
    }

    // MARK: - Rules / bonus

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tier == .starter ? "Reward" : "Quest reward")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "gift.fill")
                    .font(tier == .starter ? .title2 : .title3)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("+\(quest.bonusPoints) bonus points for completing the quest!")
                    .font(tier.bodyFont)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: tier.tileCornerRadius - 4))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quest reward: \(quest.bonusPoints) bonus points for completing the quest.")
        }
    }

    // MARK: - Deadline

    private var deadlineRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.body)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Ends \(quest.endAt.formatted(date: .abbreviated, time: .shortened))")
                .font(tier.captionFont)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quest ends \(quest.endAt.formatted(date: .abbreviated, time: .shortened))")
    }

    // MARK: - Colors

    private var ringColor: Color {
        switch tier {
        case .starter: .yellow
        case .standard: Color(hex: "4D96FF") ?? .blue
        case .advanced: Color(hex: "B983FF") ?? .purple
        }
    }
}

// MARK: - Preview

#Preview("QuestDetailView — Zara (Advanced)") {
    let api = MockAPIClient()
    let chore = ChoreRepository(apiClient: api)
    let quest = QuestRepository(apiClient: api)
    quest.loadSeedData()
    let zara = MockAPIClient.seedUsers.first(where: { $0.id == MockAPIClient.SeedID.zara })!
    if let activeQuest = quest.activeQuests.first {
        return NavigationStack {
            QuestDetailView(
                quest: activeQuest,
                kid: zara,
                questRepository: quest,
                choreRepository: chore
            )
        }
        .tierTheme(.advanced)
    } else {
        return Text("No active quest in seed data")
    }
}
