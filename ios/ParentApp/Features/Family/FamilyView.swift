import SwiftUI
import TidyQuestCore

// MARK: - Family tab segment

enum FamilySegment: String, CaseIterable {
    case kids    = "Kids"
    case chores  = "Chores"
    case rewards = "Rewards"
}

/// Parent Family tab — segmented Kids | Chores | Rewards.
@available(iOS 17, *)
struct FamilyView: View {
    var familyRepo: FamilyRepository
    var choreRepo: ChoreRepository
    var rewardRepo: RewardRepository

    @State private var segment: FamilySegment = .kids
    @State private var navigationPath = NavigationPath()
    @State private var showChoreEditor = false
    @State private var showRewardEditor = false
    @State private var editingTemplate: ChoreTemplate? = nil
    @State private var editingReward: Reward? = nil

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Family section", selection: $segment) {
                    ForEach(FamilySegment.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .accessibilityLabel("Family section picker")
                .accessibilityHint("Switch between Kids, Chores, and Rewards")

                // Segment content
                switch segment {
                case .kids:    kidsSegment
                case .chores:  choresSegment
                case .rewards: rewardsSegment
                }
            }
            .navigationTitle("Family")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarItems }
            .navigationDestination(for: AppUser.self) { kid in
                KidDetailView(
                    kid: kid,
                    choreRepo: choreRepo,
                    ledgerRepo: nil,   // injected via environment in Act 4
                    familyRepo: familyRepo
                )
            }
            .sheet(isPresented: $showChoreEditor) {
                ChoreEditorView(
                    family: familyRepo.family,
                    kids: familyRepo.kids,
                    editingTemplate: editingTemplate
                ) { req in
                    editingTemplate = nil
                    Task { await choreRepo.createTemplate(req) }
                }
                .onDisappear { editingTemplate = nil }
            }
            .sheet(isPresented: $showRewardEditor) {
                RewardEditorView(
                    family: familyRepo.family,
                    editingReward: editingReward
                ) { _ in
                    editingReward = nil
                    // Reward creation wired in Act 4 (no createReward on RewardRepository yet)
                }
                .onDisappear { editingReward = nil }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if segment == .chores {
                Button {
                    editingTemplate = nil
                    showChoreEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add chore")
                .accessibilityHint("Opens the chore editor form")
            } else if segment == .rewards {
                Button {
                    editingReward = nil
                    showRewardEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add reward")
                .accessibilityHint("Opens the reward editor form")
            }
        }
    }

    // MARK: - Kids segment

    private var kidsSegment: some View {
        Group {
            if familyRepo.kids.isEmpty {
                EmptyStateView(
                    systemImage: "person.badge.plus",
                    title: "No kids yet",
                    message: "Add your first kid in Settings → Kids to get started."
                )
            } else {
                List {
                    ForEach(familyRepo.kids) { kid in
                        NavigationLink(value: kid) {
                            KidListRow(kid: kid, choreRepo: choreRepo)
                        }
                        .accessibilityLabel("\(kid.displayName) — tap to view details")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Chores segment

    private var choresSegment: some View {
        Group {
            if choreRepo.templates.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: "No chores yet",
                    message: "Tap + to add your first chore template.",
                    action: { showChoreEditor = true },
                    actionLabel: "Add chore"
                )
            } else {
                List {
                    let active = choreRepo.templates.filter { $0.active }
                    let archived = choreRepo.templates.filter { !$0.active }

                    if !active.isEmpty {
                        Section("Active") {
                            ForEach(active) { template in
                                ChoreTemplateRow(template: template, kids: familyRepo.kids)
                                    .contextMenu {
                                        Button {
                                            editingTemplate = template
                                            showChoreEditor = true
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            Task { await choreRepo.archiveTemplate(template.id) }
                                        } label: {
                                            Label("Archive", systemImage: "archivebox")
                                        }
                                    }
                            }
                        }
                    }

                    if !archived.isEmpty {
                        Section("Archived") {
                            ForEach(archived) { template in
                                ChoreTemplateRow(template: template, kids: familyRepo.kids)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Rewards segment

    private var rewardsSegment: some View {
        Group {
            if rewardRepo.activeRewards.isEmpty {
                EmptyStateView(
                    systemImage: "gift",
                    title: "No rewards yet",
                    message: "Tap + to add rewards your kids can redeem.",
                    action: { showRewardEditor = true },
                    actionLabel: "Add reward"
                )
            } else {
                List {
                    ForEach(rewardRepo.activeRewards) { reward in
                        RewardCatalogRow(reward: reward)
                            .contextMenu {
                                Button {
                                    editingReward = reward
                                    showRewardEditor = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    // Archive wired in Act 4
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - KidListRow

private struct KidListRow: View {
    let kid: AppUser
    let choreRepo: ChoreRepository

    private var todayDone: Int {
        choreRepo.instances(for: kid.id).filter {
            $0.status == .approved || $0.status == .completed
        }.count
    }

    private var todayTotal: Int {
        choreRepo.instances(for: kid.id).count
    }

    private var kidColor: Color {
        Color(hex: kid.color.trimmingCharacters(in: .init(charactersIn: "#"))) ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            KidAvatar(user: kid, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(kid.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(kid.complexityTier.rawValue.capitalized + " tier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(todayDone)/\(todayTotal)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.primary)
                Text("today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kid.displayName), \(kid.complexityTier.rawValue) tier, \(todayDone) of \(todayTotal) chores done today")
    }
}

// MARK: - ChoreTemplateRow

private struct ChoreTemplateRow: View {
    let template: ChoreTemplate
    let kids: [AppUser]

    private var targetNames: String {
        template.targetUserIds
            .compactMap { id in kids.first { $0.id == id }?.displayName }
            .joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.icon)
                .font(.body)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(targetNames)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text("\(template.basePoints) pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if template.requiresApproval {
                        Label("Approval", systemImage: "checkmark.shield")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .labelStyle(.iconOnly)
                    }
                    if template.requiresPhoto {
                        Label("Photo", systemImage: "camera")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .labelStyle(.iconOnly)
                    }
                }
            }

            Spacer()

            Text(template.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.quaternarySystemFill), in: Capsule())
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.name), \(template.basePoints) points, for \(targetNames), \(template.type.rawValue)")
    }
}

// MARK: - RewardCatalogRow

private struct RewardCatalogRow: View {
    let reward: Reward

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reward.icon)
                .font(.body)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(reward.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(reward.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let threshold = reward.autoApproveUnder {
                        Label("Auto-approve under \(threshold) pts", systemImage: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            Text("\(reward.price) pts")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reward.name), \(reward.price) points, \(reward.category.rawValue) category")
    }
}

// MARK: - Preview

#Preview("FamilyView") {
    let client = MockAPIClient()
    let familyRepo = FamilyRepository(apiClient: client)
    let choreRepo = ChoreRepository(apiClient: client)
    let rewardRepo = RewardRepository(apiClient: client)
    familyRepo.loadSeedData()
    choreRepo.loadSeedInstances([])
    return FamilyView(
        familyRepo: familyRepo,
        choreRepo: choreRepo,
        rewardRepo: rewardRepo
    )
}
