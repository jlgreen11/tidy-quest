import SwiftUI
import TidyQuestCore

/// Parent Approvals tab — queue of pending chore and redemption items.
/// Grouped by kid. Swipe-to-approve. Batch "Approve all" per kid.
@available(iOS 17, *)
struct ApprovalsView: View {
    var choreRepo: ChoreRepository
    var rewardRepo: RewardRepository
    var familyRepo: FamilyRepository

    @State private var selectedItem: ApprovalItem? = nil
    @State private var rejectionTarget: ApprovalItem? = nil
    @State private var rejectionReason: String = ""

    // MARK: - Derived

    /// All pending approval items grouped per kid (kid id -> [ApprovalItem])
    private var itemsByKid: [(AppUser, [ApprovalItem])] {
        let kids = familyRepo.kids
        return kids.compactMap { kid in
            var items: [ApprovalItem] = []

            // Pending chore instances (status = .completed, requires approval)
            let choreItems = choreRepo.pendingApprovals
                .filter { $0.userId == kid.id }
                .map { instance -> ApprovalItem in
                    let template = choreRepo.templates.first { $0.id == instance.templateId }
                    return .choreInstance(instance, template, kid)
                }
            items.append(contentsOf: choreItems)

            // Pending redemption requests
            let redemptionItems = rewardRepo.allPendingRedemptions()
                .filter { $0.userId == kid.id }
                .map { req -> ApprovalItem in
                    let reward = rewardRepo.rewards.first { $0.id == req.rewardId }
                    return .redemptionRequest(req, reward, kid)
                }
            items.append(contentsOf: redemptionItems)

            guard !items.isEmpty else { return nil }
            return (kid, items.sorted { $0.createdAt < $1.createdAt })
        }
    }

    private var totalPending: Int {
        itemsByKid.map(\.1.count).reduce(0, +)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if choreRepo.isLoading && choreRepo.pendingApprovals.isEmpty {
                loadingBody
            } else if itemsByKid.isEmpty {
                emptyBody
            } else {
                listBody
            }
        }
        .navigationTitle("Approvals")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedItem) { item in
            ApprovalDetailSheet(
                item: item,
                onApprove: {
                    selectedItem = nil
                    handleApprove(item)
                },
                onReject: { reason in
                    selectedItem = nil
                    handleReject(item, reason: reason)
                }
            )
        }
        .task {
            // Subscribe to parentApprovals realtime scope (stub; wired in Act 4)
            _ = RealtimeScope.parentApprovals
        }
    }

    // MARK: - List body

    private var listBody: some View {
        List {
            if let error = choreRepo.error ?? rewardRepo.error {
                Section {
                    ErrorBanner(message: error.localizedDescription) {
                        // reload handled by realtime
                    }
                }
            }

            ForEach(itemsByKid, id: \.0.id) { kid, items in
                Section {
                    ForEach(items) { item in
                        ApprovalRowCard(
                            item: item,
                            onApprove: { handleApprove(item) },
                            onReject: { rejectionTarget = item },
                            onTap: { selectedItem = item }
                        )
                    }
                } header: {
                    kidSectionHeader(kid: kid, items: items)
                }
            }
        }
        .listStyle(.insetGrouped)
        .alert("Reject — add a note?", isPresented: Binding(
            get: { rejectionTarget != nil },
            set: { if !$0 { rejectionTarget = nil; rejectionReason = "" } }
        )) {
            TextField("Optional reason", text: $rejectionReason)
            Button("Reject", role: .destructive) {
                if let target = rejectionTarget {
                    handleReject(target, reason: rejectionReason.isEmpty ? nil : rejectionReason)
                }
                rejectionTarget = nil
                rejectionReason = ""
            }
            Button("Cancel", role: .cancel) {
                rejectionTarget = nil
                rejectionReason = ""
            }
        } message: {
            Text("You can leave a note for \(rejectionTarget?.kid?.displayName ?? "the kid").")
        }
    }

    // MARK: - Section header with batch approve

    private func kidSectionHeader(kid: AppUser, items: [ApprovalItem]) -> some View {
        HStack(spacing: 8) {
            KidAvatar(user: kid, size: 28)
                .accessibilityHidden(true)

            Text(kid.displayName)
                .font(.headline)
                .foregroundStyle(.primary)

            Text("(\(items.count))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                for item in items { handleApprove(item) }
            } label: {
                Text("Approve all")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            }
            .accessibilityLabel("Approve all items from \(kid.displayName) today")
            .accessibilityHint("Approves \(items.count) items at once")
        }
    }

    // MARK: - Empty state

    private var emptyBody: some View {
        EmptyStateView(
            systemImage: "checkmark.seal.fill",
            title: "All caught up",
            message: "No pending approvals right now. You'll hear from the kids when they're done with their chores."
        )
        .navigationTitle("Approvals")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Loading skeleton

    private var loadingBody: some View {
        List {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonCard(lineCount: 2)
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func handleApprove(_ item: ApprovalItem) {
        switch item {
        case .choreInstance(let inst, _, _):
            Task { await choreRepo.approveChore(inst.id) }
        case .redemptionRequest(let req, _, _):
            Task {
                // App Attest token is mocked — real wiring in Act 4
                _ = try? await rewardRepo.approveRedemption(req.id, appAttestToken: "mock-attest")
            }
        case .approvalRequest:
            // ApprovalRequest handling wired in future act
            break
        }
    }

    private func handleReject(_ item: ApprovalItem, reason: String?) {
        switch item {
        case .choreInstance(let inst, _, _):
            Task { await choreRepo.rejectChore(inst.id, reason: reason) }
        case .redemptionRequest(let req, _, _):
            Task { await rewardRepo.denyRedemption(req.id, reason: reason) }
        case .approvalRequest:
            break
        }
    }
}

// MARK: - Approval Detail Sheet

@available(iOS 17, *)
struct ApprovalDetailSheet: View {
    let item: ApprovalItem
    var onApprove: () -> Void
    var onReject: (String?) -> Void

    @State private var rejectionReason: String = ""
    @State private var showRejectField = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Kid header
                    if let kid = item.kid {
                        HStack(spacing: 12) {
                            KidAvatar(user: kid, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kid.displayName)
                                    .font(.title2.bold())
                                Text(item.title)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Photo proof placeholder (real photo URL loaded in Act 4)
                    if item.hasPhotoProof {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.tertiarySystemFill))
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .overlay(
                                Label("Photo proof", systemImage: "photo")
                                    .foregroundStyle(.secondary)
                            )
                            .padding(.horizontal)
                            .accessibilityLabel("Photo proof placeholder — image loading in Act 4")
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Type", value: item.title)
                        DetailRow(label: "Details", value: item.subtitle)
                        if item.hasPhotoProof {
                            DetailRow(label: "Proof", value: "Photo attached")
                        }
                    }
                    .padding(.horizontal)

                    // Rejection reason field
                    if showRejectField {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reason for rejection (optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Tell \(item.kid?.displayName ?? "them") why", text: $rejectionReason, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal)
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: onApprove) {
                            Label("Approve", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .font(.body.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                        .accessibilityLabel("Approve \(item.title)")
                        .accessibilityHint("Approves this item and awards points")

                        if showRejectField {
                            Button(role: .destructive) {
                                onReject(rejectionReason.isEmpty ? nil : rejectionReason)
                            } label: {
                                Label("Confirm Rejection", systemImage: "xmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .font(.body.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.large)
                            .accessibilityLabel("Confirm rejection of \(item.title)")
                        } else {
                            Button(role: .destructive) {
                                withAnimation { showRejectField = true }
                            } label: {
                                Label("Reject", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                                    .font(.body.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityLabel("Reject \(item.title)")
                            .accessibilityHint("Shows optional reason field before confirming")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel and dismiss")
                }
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Preview

#Preview("ApprovalsView — with items") {
    let client = MockAPIClient()
    let choreRepo = ChoreRepository(apiClient: client)
    let rewardRepo = RewardRepository(apiClient: client)
    let familyRepo = FamilyRepository(apiClient: client)
    familyRepo.loadSeedData()
    // Seed a pending chore instance for each kid
    let instances: [ChoreInstance] = MockAPIClient.seedTemplates.prefix(3).map { template in
        ChoreInstance(
            id: UUID(),
            templateId: template.id,
            userId: template.targetUserIds.first ?? MockAPIClient.SeedID.ava,
            scheduledFor: "2026-04-22",
            windowStart: nil, windowEnd: nil,
            status: .completed,
            completedAt: Date().addingTimeInterval(-600),
            approvedAt: nil,
            proofPhotoId: template.requiresPhoto ? UUID() : nil,
            awardedPoints: nil,
            completedByDevice: nil, completedAsUser: nil,
            createdAt: Date()
        )
    }
    choreRepo.loadSeedInstances(instances)
    return NavigationStack {
        ApprovalsView(
            choreRepo: choreRepo,
            rewardRepo: rewardRepo,
            familyRepo: familyRepo
        )
    }
}

#Preview("ApprovalsView — empty") {
    let client = MockAPIClient()
    let choreRepo = ChoreRepository(apiClient: client)
    let rewardRepo = RewardRepository(apiClient: client)
    let familyRepo = FamilyRepository(apiClient: client)
    familyRepo.loadSeedData()
    return NavigationStack {
        ApprovalsView(
            choreRepo: choreRepo,
            rewardRepo: rewardRepo,
            familyRepo: familyRepo
        )
    }
}
