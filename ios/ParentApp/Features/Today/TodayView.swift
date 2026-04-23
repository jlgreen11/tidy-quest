import SwiftUI
import TidyQuestCore

/// Parent Today tab — default landing screen.
/// Sections: hero greeting, inline pending approvals, today's kid activity, recent ledger.
@available(iOS 17, *)
struct TodayView: View {
    var familyRepo: FamilyRepository
    var choreRepo: ChoreRepository
    var ledgerRepo: LedgerRepository
    var rewardRepo: RewardRepository

    /// Callback to navigate to the Approvals tab.
    var onSeeAllApprovals: () -> Void = {}

    @State private var isRefreshing = false

    // MARK: - Derived

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = familyRepo.parents.first?.displayName ?? "there"
        switch hour {
        case 5..<12:  return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        case 17..<21: return "Good evening, \(name)"
        default:      return "Good night, \(name)"
        }
    }

    /// Pending approvals = chore instances with status .completed (awaiting parent approval).
    private var pendingInstances: [ChoreInstance] {
        choreRepo.pendingApprovals
    }

    private var recentTransactions: [PointTransaction] {
        Array(
            ledgerRepo.transactions
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(5)
        )
    }

    // MARK: - Body

    var body: some View {
        Group {
            if familyRepo.isLoading && familyRepo.family == nil {
                loadingBody
            } else {
                contentBody
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Subscribe to parentToday realtime scope (stub; wired in Act 4)
            _ = RealtimeScope.parentToday
        }
    }

    // MARK: - Content

    private var contentBody: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Error banner
                if let error = familyRepo.error ?? choreRepo.error ?? ledgerRepo.error {
                    ErrorBanner(message: error.localizedDescription) {
                        Task { await refresh() }
                    }
                }

                // Hero greeting
                heroSection

                // Inline pending approvals (top 3)
                if !pendingInstances.isEmpty {
                    inlineApprovalsSection
                }

                // Today's kid activity
                kidActivitySection

                // Recent ledger
                if !recentTransactions.isEmpty {
                    recentLedgerSection
                } else if familyRepo.kids.isEmpty {
                    EmptyStateView(
                        systemImage: "moon.stars.fill",
                        title: "Quiet day",
                        message: "No activity yet. Check back after the kids get started."
                    )
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await refresh()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.title.bold())
                .foregroundStyle(.primary)

            if let family = familyRepo.family {
                Text(family.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Inline Approvals

    private var inlineApprovalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Needs approval", systemImage: "clock.badge.exclamationmark")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if pendingInstances.count > 3 {
                    Button("See all \(Image(systemName: "arrow.right"))") {
                        onSeeAllApprovals()
                    }
                    .font(.subheadline)
                    .accessibilityLabel("See all pending approvals")
                    .accessibilityHint("Navigates to the Approvals tab")
                }
            }
            .padding(.horizontal)

            ForEach(pendingInstances.prefix(3)) { instance in
                InlineApprovalCard(
                    instance: instance,
                    kid: familyRepo.users.first { $0.id == instance.userId },
                    template: choreRepo.templates.first { $0.id == instance.templateId }
                ) {
                    Task { await choreRepo.approveChore(instance.id) }
                }
            }
        }
    }

    // MARK: - Kid Activity

    private var kidActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's activity")
                .font(.headline)
                .padding(.horizontal)

            if familyRepo.kids.isEmpty {
                EmptyStateView(
                    systemImage: "person.2",
                    title: "No kids yet",
                    message: "Add a kid in the Family tab to get started."
                )
                .frame(height: 120)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(familyRepo.kids) { kid in
                            KidActivityCard(
                                kid: kid,
                                instances: choreRepo.instances(for: kid.id),
                                balance: ledgerRepo.balance(for: kid.id)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Recent Ledger

    private var recentLedgerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent ledger")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(recentTransactions) { txn in
                    LedgerRow(
                        transaction: txn,
                        kid: familyRepo.users.first { $0.id == txn.userId }
                    )
                    if txn.id != recentTransactions.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    // MARK: - Loading skeleton

    private var loadingBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Greeting skeleton
                VStack(alignment: .leading, spacing: 8) {
                    LoadingSkeleton(height: 28).frame(width: 200)
                    LoadingSkeleton(height: 16).frame(width: 120)
                }
                .padding(.horizontal)

                // Approvals skeleton
                VStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { _ in SkeletonCard(lineCount: 2) }
                }
                .padding(.horizontal)

                // Kids skeleton
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonCard(lineCount: 3)
                                .frame(width: 160, height: 120)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Actions

    private func refresh() async {
        isRefreshing = true
        // Repositories handle their own load; this triggers re-binding
        try? await Task.sleep(nanoseconds: 500_000_000)
        isRefreshing = false
    }
}

// MARK: - Inline Approval Card

private struct InlineApprovalCard: View {
    let instance: ChoreInstance
    let kid: AppUser?
    let template: ChoreTemplate?
    let onApprove: () -> Void

    private var elapsedLabel: String {
        guard let completedAt = instance.completedAt else { return "Just now" }
        let minutes = Int(-completedAt.timeIntervalSinceNow / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }

    var body: some View {
        HStack(spacing: 12) {
            if let kid {
                KidAvatar(user: kid, size: 40)
            } else {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(template?.name ?? "Chore")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(kid?.displayName ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(elapsedLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if instance.proofPhotoId != nil {
                        Label("Photo", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            Button(action: onApprove) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Approve \(template?.name ?? "chore") for \(kid?.displayName ?? "kid")")
            .accessibilityHint("Marks this chore as approved")
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Kid Activity Card

private struct KidActivityCard: View {
    let kid: AppUser
    let instances: [ChoreInstance]
    let balance: Int

    private var tier: Tier {
        switch kid.complexityTier {
        case .starter:  .starter
        case .standard: .standard
        case .advanced: .advanced
        }
    }

    private var kidColor: Color {
        Color(hex: kid.color.trimmingCharacters(in: .init(charactersIn: "#")))
    }

    private var completedCount: Int {
        instances.filter { $0.status == .approved || $0.status == .completed }.count
    }

    private var totalCount: Int { instances.count }

    private var nextChore: String? {
        instances.first { $0.status == .pending }.map { _ in "Next chore pending" }
    }

    private var progress: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                KidAvatar(user: kid, size: 36)

                Text(kid.displayName)
                    .font(tier.bodyFont.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                ProgressRing(progress: progress, color: kidColor, lineWidth: 5, size: 40)
                    .accessibilityLabel("\(kid.displayName): \(completedCount) of \(totalCount) chores done")

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completedCount)/\(totalCount)")
                        .font(tier.captionFont.weight(.semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text("done today")
                        .font(tier.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            BalancePill(balance: balance, tier: tier, color: kidColor)

            if let next = nextChore {
                Text(next)
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(width: 160, alignment: .leading)
        .background(kidColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(kidColor.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kid.displayName): \(completedCount) of \(totalCount) chores done. Balance: \(balance) points.")
    }
}

// MARK: - Ledger Row

private struct LedgerRow: View {
    let transaction: PointTransaction
    let kid: AppUser?

    private var kidColor: Color {
        Color(hex: (kid?.color ?? "#6C757D").trimmingCharacters(in: .init(charactersIn: "#")))
    }

    private var amountColor: Color {
        transaction.amount >= 0 ? .green : .red
    }

    private var kindIcon: String {
        switch transaction.kind {
        case .choreCompletion, .choreBonus: "checkmark.circle"
        case .streakBonus, .comboBonus:     "flame.fill"
        case .redemption:                   "gift.fill"
        case .fine:                         "exclamationmark.triangle.fill"
        case .adjustment, .correction:      "pencil.circle"
        default:                            "circle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kindIcon)
                .font(.body)
                .foregroundStyle(amountColor)
                .frame(width: 28, height: 28)
                .background(amountColor.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(kid?.displayName ?? "Unknown")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if let reason = transaction.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.amount >= 0 ? "+\(transaction.amount)" : "\(transaction.amount)")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(amountColor)

                Text(transaction.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kid?.displayName ?? "Unknown"): \(transaction.amount > 0 ? "plus" : "minus") \(abs(transaction.amount)) points")
    }
}

// MARK: - Preview

#Preview("TodayView — seeded") {
    let client = MockAPIClient()
    let familyRepo = FamilyRepository(apiClient: client)
    let choreRepo = ChoreRepository(apiClient: client)
    let ledgerRepo = LedgerRepository(apiClient: client)
    let rewardRepo = RewardRepository(apiClient: client)
    familyRepo.loadSeedData()
    choreRepo.loadSeedInstances(Array(MockAPIClient.seedTemplates.prefix(4)).map { template in
        ChoreInstance(
            id: UUID(),
            templateId: template.id,
            userId: template.targetUserIds.first ?? MockAPIClient.SeedID.ava,
            scheduledFor: "2026-04-22",
            windowStart: nil,
            windowEnd: nil,
            status: .completed,
            completedAt: Date().addingTimeInterval(-1800),
            approvedAt: nil,
            proofPhotoId: template.requiresPhoto ? UUID() : nil,
            awardedPoints: nil,
            completedByDevice: nil,
            completedAsUser: nil,
            createdAt: Date()
        )
    })
    return NavigationStack {
        TodayView(
            familyRepo: familyRepo,
            choreRepo: choreRepo,
            ledgerRepo: ledgerRepo,
            rewardRepo: rewardRepo
        )
    }
}
