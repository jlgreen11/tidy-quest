import SwiftUI
import TidyQuestCore

// MARK: - LedgerView

/// Paginated transaction history. Sub-screen of MeView per PLAN §5.2.
/// Filter chips: All / Earned / Spent / Fines.
/// Long-press on fine → "Tell mom this isn't fair" sends an ApprovalRequest.
/// Advanced tier shows running balance per row.
@MainActor
struct LedgerView: View {
    let kid: AppUser
    let ledgerRepository: LedgerRepository

    @Environment(\.tierTheme) private var tier

    // MARK: - Filter

    enum Filter: String, CaseIterable, Identifiable {
        case all    = "All"
        case earned = "Earned"
        case spent  = "Spent"
        case fines  = "Fines"
        var id: String { rawValue }
    }

    // MARK: - State

    @State private var activeFilter: Filter = .all
    @State private var contestingFine: PointTransaction?
    @State private var showContestConfirmation = false
    @State private var displayedCount = 50

    // MARK: - Derived

    private var allTransactions: [PointTransaction] {
        ledgerRepository.transactions(for: kid.id)
    }

    private var filteredTransactions: [PointTransaction] {
        switch activeFilter {
        case .all:    return allTransactions
        case .earned: return allTransactions.filter { $0.amount > 0 }
        case .spent:  return allTransactions.filter { $0.amount < 0 && $0.kind != .fine }
        case .fines:  return allTransactions.filter { $0.kind == .fine }
        }
    }

    /// Transactions grouped by calendar day, newest first.
    private var groupedTransactions: [(day: String, items: [PointTransaction])] {
        let sorted = Array(filteredTransactions.prefix(displayedCount))
        var grouped: [String: [PointTransaction]] = [:]
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        for txn in sorted {
            let key = df.string(from: txn.createdAt)
            grouped[key, default: []].append(txn)
        }
        return grouped
            .sorted { a, b in
                let da = a.value.first?.createdAt ?? .distantPast
                let db = b.value.first?.createdAt ?? .distantPast
                return da > db
            }
            .map { (day: $0.key, items: $0.value) }
    }

    /// Running balance per transaction (advanced tier only).
    private func runningBalance(after txn: PointTransaction) -> Int {
        let idx = allTransactions.firstIndex(where: { $0.id == txn.id }) ?? 0
        return allTransactions
            .suffix(from: idx)
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            filterChips
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            if groupedTransactions.isEmpty {
                emptyState
            } else {
                transactionList
            }
        }
        .navigationTitle("Point History")
        .navigationBarTitleDisplayMode(tier == .advanced ? .inline : .large)
        .alert("Sent!", isPresented: $showContestConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            let parentLabel = "mom"
            Text("Your message has been sent — \(parentLabel) will see this.")
        }
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { activeFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(tier.captionFont)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                activeFilter == filter
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.secondary.opacity(0.1),
                                in: Capsule()
                            )
                            .foregroundStyle(activeFilter == filter ? Color.accentColor : Color.secondary)
                    }
                    .accessibilityLabel("\(filter.rawValue) filter\(activeFilter == filter ? ", selected" : "")")
                }
            }
        }
    }

    // MARK: - Transaction list

    @ViewBuilder private var transactionList: some View {
        let list = List {
            ForEach(groupedTransactions, id: \.day) { group in
                Section(header: Text(group.day)
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
                ) {
                    ForEach(group.items) { txn in
                        transactionRow(txn)
                            .listRowSeparator(tier == .starter ? .hidden : .automatic)
                            .listRowBackground(
                                tier == .starter
                                    ? Color(.systemGroupedBackground)
                                    : nil
                            )
                    }
                }
            }

            // Load-more trigger
            if filteredTransactions.count > displayedCount {
                Button {
                    displayedCount += 50
                } label: {
                    Text("Load more…")
                        .font(tier.captionFont)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(minHeight: tier.minTapTarget)
            }
        }
        if tier == .starter {
            list.listStyle(.insetGrouped)
        } else {
            list.listStyle(.plain)
        }
    }

    // MARK: - Transaction row

    @ViewBuilder
    private func transactionRow(_ txn: PointTransaction) -> some View {
        let isFine = txn.kind == .fine
        let isEarned = txn.amount > 0
        let amountColor: Color = isEarned ? .green : .red

        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackground(for: txn))
                    .frame(
                        width: tier == .starter ? 44 : 36,
                        height: tier == .starter ? 44 : 36
                    )
                Image(systemName: txnIcon(for: txn))
                    .font(.system(size: tier == .starter ? 18 : 14))
                    .foregroundStyle(iconForeground(for: txn))
            }
            .accessibilityHidden(true)

            // Reason + timestamp
            VStack(alignment: .leading, spacing: 2) {
                Text(txn.reason ?? friendlyKind(txn.kind))
                    .font(tier.bodyFont)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(txn.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(tier.captionFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount + running balance (advanced)
            VStack(alignment: .trailing, spacing: 2) {
                Text(isEarned ? "+\(txn.amount)" : "\(txn.amount)")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(amountColor)
                    .monospacedDigit()
                if tier == .advanced {
                    Text("bal: \(runningBalance(after: txn))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        .frame(minHeight: tier.minTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel(for: txn))
        .contextMenu {
            if isFine {
                Button {
                    contestingFine = txn
                    sendContest(txn)
                } label: {
                    Label("Tell mom this isn't fair", systemImage: "hand.raised.fill")
                }
            }
        }
        // Fine: left-border pill (red left border indicating fine category)
        .overlay(alignment: .leading) {
            if isFine {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.red)
                    .frame(width: 3)
                    .padding(.vertical, 6)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Contest fine

    private func sendContest(_ txn: PointTransaction) {
        // Creates an ApprovalRequest back to the parent.
        // In production: call APIClient with an ApprovalRequest for kind = .transactionContest.
        // For MVP, fire-and-forget via Task and show confirmation.
        Task { @MainActor in
            // Simulate network call
            try? await Task.sleep(for: .milliseconds(300))
            showContestConfirmation = true
        }
    }

    // MARK: - Icon helpers

    private func txnIcon(for txn: PointTransaction) -> String {
        switch txn.kind {
        case .choreCompletion:    return "checkmark.circle.fill"
        case .choreBonus:         return "plus.circle.fill"
        case .streakBonus:        return "flame.fill"
        case .comboBonus:         return "bolt.fill"
        case .surpriseMultiplier: return "sparkles"
        case .questCompletion:    return "map.fill"
        case .redemption:         return "cart.fill"
        case .fine:               return "scale.3d"
        case .adjustment:         return "slider.horizontal.3"
        case .correction:         return "arrow.counterclockwise"
        case .systemGrant:        return "gift.fill"
        }
    }

    private func iconBackground(for txn: PointTransaction) -> Color {
        switch txn.kind {
        case .fine:       return .red.opacity(0.1)
        case .redemption: return .purple.opacity(0.1)
        default:          return txn.amount > 0 ? .green.opacity(0.1) : .orange.opacity(0.1)
        }
    }

    private func iconForeground(for txn: PointTransaction) -> Color {
        switch txn.kind {
        case .fine:       return .red
        case .redemption: return .purple
        case .streakBonus: return .orange
        default:          return txn.amount > 0 ? .green : .secondary
        }
    }

    private func friendlyKind(_ kind: PointTxnKind) -> String {
        switch kind {
        case .choreCompletion:    return "Chore completed"
        case .choreBonus:         return "Chore bonus"
        case .streakBonus:        return "Streak bonus"
        case .comboBonus:         return "Combo bonus"
        case .surpriseMultiplier: return "Surprise multiplier"
        case .questCompletion:    return "Quest completed"
        case .redemption:         return "Reward redeemed"
        case .fine:               return "Fine"
        case .adjustment:         return "Adjustment"
        case .correction:         return "Correction"
        case .systemGrant:        return "Bonus points"
        }
    }

    private func voiceOverLabel(for txn: PointTransaction) -> String {
        let amtStr = txn.amount > 0 ? "Earned \(txn.amount) points" : "Lost \(abs(txn.amount)) points"
        let reasonStr = txn.reason ?? friendlyKind(txn.kind)
        return "\(amtStr). \(reasonStr). \(txn.createdAt.formatted(date: .abbreviated, time: .shortened))."
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: tier == .starter ? 56 : 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No transactions yet!")
                .font(tier.headlineFont)
                .foregroundStyle(.primary)
            Text("Complete chores to earn points and see your history here.")
                .font(tier.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No transactions yet. Complete chores to earn points.")
    }
}

// MARK: - Preview

#Preview("LedgerView — Advanced (Zara)") {
    let api = MockAPIClient()
    let ledger = LedgerRepository(apiClient: api)
    let zara = MockAPIClient.seedUsers.first(where: { $0.id == MockAPIClient.SeedID.zara })!
    // Seed some transactions
    ledger.setBalance(zara.cachedBalance, for: zara.id)
    ledger.applyTransaction(PointTransaction(
        id: UUID(), userId: zara.id, familyId: MockAPIClient.SeedID.family,
        amount: 12, kind: .choreCompletion, referenceId: nil,
        reason: "Emptied dishwasher", createdByUserId: MockAPIClient.SeedID.system,
        idempotencyKey: UUID(), choreInstanceId: nil,
        createdAt: Date().addingTimeInterval(-3600), reversedByTransactionId: nil
    ))
    ledger.applyTransaction(PointTransaction(
        id: UUID(), userId: zara.id, familyId: MockAPIClient.SeedID.family,
        amount: -5, kind: .fine, referenceId: nil,
        reason: "Rude to sibling", createdByUserId: MockAPIClient.SeedID.mei,
        idempotencyKey: UUID(), choreInstanceId: nil,
        createdAt: Date().addingTimeInterval(-7200), reversedByTransactionId: nil
    ))
    return NavigationStack {
        LedgerView(kid: zara, ledgerRepository: ledger)
    }
    .tierTheme(.advanced)
}

#Preview("LedgerView — Starter (Ava, empty)") {
    let api = MockAPIClient()
    let ledger = LedgerRepository(apiClient: api)
    let ava = MockAPIClient.seedUsers.first(where: { $0.id == MockAPIClient.SeedID.ava })!
    return NavigationStack {
        LedgerView(kid: ava, ledgerRepository: ledger)
    }
    .tierTheme(.starter)
}
