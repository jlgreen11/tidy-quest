import SwiftUI
import TidyQuestCore

/// Detail view for a single kid — balance, today's chore status, streaks summary.
@available(iOS 17, *)
struct KidDetailView: View {
    let kid: AppUser
    var choreRepo: ChoreRepository
    var ledgerRepo: LedgerRepository?   // optional until Act 4 injects via environment
    var familyRepo: FamilyRepository

    private var tier: Tier {
        switch kid.complexityTier {
        case .starter:  .starter
        case .standard: .standard
        case .advanced: .advanced
        }
    }

    private var kidColor: Color {
        Color(hex: kid.color.trimmingCharacters(in: .init(charactersIn: "#"))) ?? .accentColor
    }

    private var todayInstances: [ChoreInstance] {
        choreRepo.instances(for: kid.id)
    }

    private var completedCount: Int {
        todayInstances.filter { $0.status == .approved || $0.status == .completed }.count
    }

    private var progress: Double {
        todayInstances.isEmpty ? 0 : Double(completedCount) / Double(todayInstances.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Kid header
                HStack(spacing: 16) {
                    KidAvatar(user: kid, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(kid.displayName)
                            .font(tier.headlineFont)
                            .foregroundStyle(.primary)

                        Text(kid.complexityTier.rawValue.capitalized + " tier")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    BalancePill(
                        balance: kid.cachedBalance,
                        tier: tier,
                        color: kidColor
                    )
                }
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(kid.displayName), \(kid.complexityTier.rawValue) tier, \(kid.cachedBalance) points")

                // Today's progress
                TierAwareTile(tier: tier, color: kidColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today")
                            .font(.headline)

                        HStack(spacing: 16) {
                            ProgressRing(
                                progress: progress,
                                color: kidColor,
                                lineWidth: 7,
                                size: 56
                            )
                            .accessibilityLabel("\(completedCount) of \(todayInstances.count) chores done")

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(completedCount) of \(todayInstances.count) done")
                                    .font(tier.bodyFont.weight(.semibold))

                                Text(progressLabel)
                                    .font(tier.captionFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Chore list for today
                if !todayInstances.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's chores")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(todayInstances) { instance in
                                KidChoreStatusRow(
                                    instance: instance,
                                    template: choreRepo.templates.first { $0.id == instance.templateId }
                                )
                                if instance.id != todayInstances.last?.id {
                                    Divider().padding(.leading, 44)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                    }
                }

                // Streak summary (from repo)
                let streaks = choreRepo.streaks.filter { $0.userId == kid.id }
                if !streaks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Streaks")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(streaks) { streak in
                                StreakRow(
                                    streak: streak,
                                    template: choreRepo.templates.first { $0.id == streak.choreTemplateId }
                                )
                                if streak.id != streaks.last?.id {
                                    Divider().padding(.leading, 44)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .navigationTitle(kid.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressLabel: String {
        if completedCount == todayInstances.count && !todayInstances.isEmpty {
            return "All done for today!"
        } else if completedCount == 0 {
            return "Not started yet"
        } else {
            return "\(todayInstances.count - completedCount) left"
        }
    }
}

// MARK: - KidChoreStatusRow

private struct KidChoreStatusRow: View {
    let instance: ChoreInstance
    let template: ChoreTemplate?

    private var statusIcon: String {
        switch instance.status {
        case .approved:   "checkmark.circle.fill"
        case .completed:  "clock.badge.checkmark"
        case .pending:    "circle"
        case .missed:     "exclamationmark.circle"
        case .rejected:   "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch instance.status {
        case .approved:   .green
        case .completed:  .orange
        case .pending:    .secondary
        case .missed:     .red
        case .rejected:   .red
        }
    }

    private var statusLabel: String {
        switch instance.status {
        case .approved:   "Approved"
        case .completed:  "Waiting for approval"
        case .pending:    "Pending"
        case .missed:     "Missed"
        case .rejected:   "Rejected"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.title3)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(template?.name ?? "Chore")
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            if let points = instance.awardedPoints {
                Text("+\(points)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.green)
            } else if let base = template?.basePoints {
                Text("\(base) pts")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template?.name ?? "Chore"): \(statusLabel)")
    }
}

// MARK: - StreakRow

private struct StreakRow: View {
    let streak: Streak
    let template: ChoreTemplate?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
                .font(.title3)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(template?.name ?? "Chore")
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("Longest: \(streak.longestLength)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(streak.currentLength) days")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template?.name ?? "Chore") streak: \(streak.currentLength) days. Longest: \(streak.longestLength) days.")
    }
}

// MARK: - Preview

#Preview("KidDetailView") {
    let client = MockAPIClient()
    let choreRepo = ChoreRepository(apiClient: client)
    let familyRepo = FamilyRepository(apiClient: client)
    familyRepo.loadSeedData()
    let instances = [
        ChoreInstance(
            id: UUID(),
            templateId: MockAPIClient.SeedID.templateKaiMakeBed,
            userId: MockAPIClient.SeedID.kai,
            scheduledFor: "2026-04-22", windowStart: nil, windowEnd: nil,
            status: .approved, completedAt: Date().addingTimeInterval(-7200),
            approvedAt: Date().addingTimeInterval(-7000), proofPhotoId: nil,
            awardedPoints: 5, completedByDevice: nil, completedAsUser: nil, createdAt: Date()
        ),
        ChoreInstance(
            id: UUID(),
            templateId: MockAPIClient.SeedID.templateKaiHomework,
            userId: MockAPIClient.SeedID.kai,
            scheduledFor: "2026-04-22", windowStart: nil, windowEnd: nil,
            status: .pending, completedAt: nil, approvedAt: nil, proofPhotoId: nil,
            awardedPoints: nil, completedByDevice: nil, completedAsUser: nil, createdAt: Date()
        )
    ]
    choreRepo.loadSeedInstances(instances)
    let kai = MockAPIClient.seedUsers.first { $0.displayName == "Kai" }!
    return NavigationStack {
        KidDetailView(
            kid: kai,
            choreRepo: choreRepo,
            ledgerRepo: nil,
            familyRepo: familyRepo
        )
    }
}
