import SwiftUI
import TidyQuestCore

/// Per-kid streak drill-down. Shows each active streak on a card with a
/// 28-day heatmap grid, longest count, last completed date, and freeze count.
@available(iOS 17, *)
struct StreakDetailView: View {

    let kid: AppUser
    var choreRepo: ChoreRepository

    private var kidColor: Color {
        Color(hex: kid.color) ?? .accentColor
    }

    private var kidStreaks: [Streak] {
        choreRepo.streaks.filter { $0.userId == kid.id }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if kidStreaks.isEmpty {
                    emptyState
                } else {
                    ForEach(kidStreaks) { streak in
                        streakCard(streak)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("\(kid.displayName)'s Streaks")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flame")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No active streaks yet")
                .font(.headline)
            Text("\(kid.displayName) will build streaks by completing chores on consecutive days.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Streak Card

    private func streakCard(_ streak: Streak) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(streakTitle(streak))
                        .font(.subheadline.weight(.semibold))
                    Text(streakSubtitle(streak))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(kidColor)
                            .accessibilityHidden(true)
                        Text("\(streak.currentLength)")
                            .font(.title3.weight(.bold).monospacedDigit())
                    }
                    Text("Longest: \(streak.longestLength)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(streakTitle(streak)). Current streak: \(streak.currentLength) days. Longest: \(streak.longestLength)."
            )

            // 28-day heatmap
            HeatmapGrid(streak: streak, kidColor: kidColor)

            // Freeze indicator (v1.0 preview)
            HStack(spacing: 4) {
                Image(systemName: "snowflake")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text("Streak freezes: \(streak.freezesRemaining) (v1.0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Streak freezes available: \(streak.freezesRemaining). Streak freeze feature coming in version 1.0.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers

    private func streakTitle(_ streak: Streak) -> String {
        if let templateId = streak.choreTemplateId,
           let template = choreRepo.templates.first(where: { $0.id == templateId }) {
            return template.name
        }
        return "Routine streak"
    }

    private func streakSubtitle(_ streak: Streak) -> String {
        guard let last = streak.lastCompletedDate else { return "No completions yet" }
        return "Last completed: \(last)"
    }
}

// MARK: - HeatmapGrid

@available(iOS 17, *)
private struct HeatmapGrid: View {

    let streak: Streak
    let kidColor: Color

    /// Generate the 28-day window ending today, in order oldest→newest.
    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<28).reversed().map { offset in
            cal.date(byAdding: .day, value: -offset, to: today)!
        }
    }

    /// Columns of 7 days each (4 columns of 7).
    private var columns: [[Date]] {
        stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
    }

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func isCompleted(_ date: Date) -> Bool {
        // We only have lastCompletedDate from the streak; use currentLength and longestLength
        // to reconstruct which days were likely completed (approximation for v0.1).
        // In production, the backend should return a completion bitmap.
        guard let lastStr = streak.lastCompletedDate,
              let lastDate = dayFormatter.date(from: lastStr) else { return false }
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: date, to: lastDate).day ?? Int.max
        return diff >= 0 && diff < streak.currentLength
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(columns.indices, id: \.self) { colIdx in
                VStack(spacing: 4) {
                    ForEach(columns[colIdx].indices, id: \.self) { rowIdx in
                        let date = columns[colIdx][rowIdx]
                        let filled = isCompleted(date)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(filled ? kidColor : Color(.systemFill))
                            .frame(width: 18, height: 18)
                            .accessibilityLabel(
                                filled
                                    ? "Completed on \(dayFormatter.string(from: date))"
                                    : "Not completed on \(dayFormatter.string(from: date))"
                            )
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("28-day completion heatmap")
    }
}

// MARK: - Color helper (local extension)

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

#Preview("StreakDetailView") {
    let client = MockAPIClient()
    let chore = ChoreRepository(apiClient: client)

    let sampleKid = AppUser(
        id: MockAPIClient.SeedID.kai,
        familyId: MockAPIClient.SeedID.family,
        role: .child,
        displayName: "Kai",
        avatar: "kid-rocket",
        color: "#4D96FF",
        complexityTier: .standard,
        birthdate: "2016-04-22",
        appleSub: nil,
        devicePairingCode: nil,
        devicePairingExpiresAt: nil,
        cachedBalance: 340,
        cachedBalanceAsOfTxnId: nil,
        createdAt: Date(),
        deletedAt: nil
    )

    return NavigationStack {
        StreakDetailView(kid: sampleKid, choreRepo: chore)
    }
}
