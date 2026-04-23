import SwiftUI
import TidyQuestCore

// MARK: - ApprovalItem union type

/// Unified enum bridging the three approval kinds so views don't fork on type.
public enum ApprovalItem: Identifiable, Sendable {
    case choreInstance(ChoreInstance, ChoreTemplate?, AppUser?)
    case redemptionRequest(RedemptionRequest, Reward?, AppUser?)
    case approvalRequest(ApprovalRequest, AppUser?)

    public var id: UUID {
        switch self {
        case .choreInstance(let i, _, _):    i.id
        case .redemptionRequest(let r, _, _): r.id
        case .approvalRequest(let a, _):     a.id
        }
    }

    public var kid: AppUser? {
        switch self {
        case .choreInstance(_, _, let u):    u
        case .redemptionRequest(_, _, let u): u
        case .approvalRequest(_, let u):     u
        }
    }

    public var title: String {
        switch self {
        case .choreInstance(_, let t, _):    t?.name ?? "Chore"
        case .redemptionRequest(_, let r, _): r?.name ?? "Reward"
        case .approvalRequest(let a, _):
            switch a.kind {
            case .choreInstance:     "Chore approval"
            case .redemptionRequest: "Reward request"
            case .transactionContest: "Transaction contest"
            }
        }
    }

    public var subtitle: String {
        switch self {
        case .choreInstance(let i, let t, _):
            let pts = t.map { "\($0.basePoints) pts" } ?? ""
            let photo = i.proofPhotoId != nil ? " · Photo proof" : ""
            return pts + photo
        case .redemptionRequest(_, let r, _):
            return r.map { "\($0.price) pts" } ?? ""
        case .approvalRequest(_, _):
            return "Requested by kid"
        }
    }

    public var hasPhotoProof: Bool {
        if case .choreInstance(let i, _, _) = self { return i.proofPhotoId != nil }
        return false
    }

    public var createdAt: Date {
        switch self {
        case .choreInstance(let i, _, _):    i.completedAt ?? i.createdAt
        case .redemptionRequest(let r, _, _): r.requestedAt
        case .approvalRequest(let a, _):     a.createdAt
        }
    }

    public var kindIcon: String {
        switch self {
        case .choreInstance:       "checkmark.circle"
        case .redemptionRequest:   "gift.fill"
        case .approvalRequest:     "questionmark.circle"
        }
    }
}

// MARK: - ApprovalRowCard

/// Row card for a single approval item. Used in ApprovalsView list.
struct ApprovalRowCard: View {
    let item: ApprovalItem
    var onApprove: () -> Void
    var onReject: () -> Void
    var onTap: () -> Void

    private var elapsedLabel: String {
        let minutes = Int(-item.createdAt.timeIntervalSinceNow / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h \(minutes % 60)m ago"
    }

    private var kidColor: Color {
        Color(hex: (item.kid?.color ?? "#6C757D").trimmingCharacters(in: .init(charactersIn: "#")))
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                if let kid = item.kid {
                    KidAvatar(user: kid, size: 42)
                } else {
                    Circle()
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 42, height: 42)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: item.kindIcon)
                            .font(.caption)
                            .foregroundStyle(kidColor)
                            .accessibilityHidden(true)

                        Text(item.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Text(item.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if item.hasPhotoProof {
                            Label("Photo", systemImage: "photo")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .labelStyle(.iconOnly)
                        }
                    }

                    Text(elapsedLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Quick approve
                Button(action: onApprove) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Approve \(item.title)")
                .accessibilityHint("Approves this item immediately")
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kid?.displayName ?? "Kid"): \(item.title), \(item.subtitle), \(elapsedLabel)")
        .accessibilityHint("Tap to view details, approve, or reject")
        // Swipe to approve
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onApprove) {
                Label("Approve", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onReject) {
                Label("Reject", systemImage: "xmark")
            }
            .tint(.red)
        }
    }
}

#Preview("ApprovalRowCard") {
    let users = MockAPIClient.seedUsers
    let templates = MockAPIClient.seedTemplates
    let kid = users.first { $0.role == .child }!
    let template = templates.first!
    let instance = ChoreInstance(
        id: UUID(), templateId: template.id, userId: kid.id,
        scheduledFor: "2026-04-22", windowStart: nil, windowEnd: nil,
        status: .completed, completedAt: Date().addingTimeInterval(-900),
        approvedAt: nil, proofPhotoId: UUID(), awardedPoints: nil,
        completedByDevice: nil, completedAsUser: nil, createdAt: Date()
    )
    return List {
        ApprovalRowCard(
            item: .choreInstance(instance, template, kid),
            onApprove: {},
            onReject: {},
            onTap: {}
        )
    }
    .listStyle(.insetGrouped)
}
