import Foundation
import Observation

/// Observable repository for point transactions and per-user balances.
@available(iOS 17, macOS 14, *)
@Observable
public final class LedgerRepository: @unchecked Sendable {

    // MARK: - Published state

    public private(set) var transactions: [PointTransaction] = []
    public private(set) var balances: [UUID: Int] = [:]    // userId -> balance
    public private(set) var isLoading: Bool = false
    public private(set) var error: (any Error)?

    // MARK: - Derived

    public func transactions(for userId: UUID) -> [PointTransaction] {
        transactions.filter { $0.userId == userId }.sorted { $0.createdAt > $1.createdAt }
    }

    public func balance(for userId: UUID) -> Int {
        balances[userId] ?? 0
    }

    // MARK: - Dependencies

    private let apiClient: any APIClient

    public init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Cloud load

    /// Fetch recent transactions and derive balances for all kids in a family.
    /// Requires the caller to supply the list of kid user IDs (from FamilyRepository).
    public func load(familyId: UUID, kidIds: [UUID], transactionLimit: Int = 50) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await withThrowingTaskGroup(of: [PointTransaction].self) { group in
                for kidId in kidIds {
                    group.addTask { [apiClient] in
                        try await apiClient.listTransactions(userId: kidId, limit: transactionLimit)
                    }
                }
                for try await txns in group {
                    for txn in txns {
                        if !transactions.contains(where: { $0.id == txn.id }) {
                            transactions.append(txn)
                        }
                    }
                }
            }
            // Recompute balances from loaded transactions
            for kidId in kidIds {
                let total = transactions
                    .filter { $0.userId == kidId && $0.reversedByTransactionId == nil }
                    .reduce(0) { $0 + $1.amount }
                balances[kidId] = total
            }
        } catch {
            self.error = error
        }
    }

    /// Fetch transactions for a single user (e.g., drill-down ledger view).
    public func loadTransactions(userId: UUID, limit: Int = 50) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let txns = try await apiClient.listTransactions(userId: userId, limit: limit)
            setTransactions(txns, for: userId)
        } catch {
            self.error = error
        }
    }

    // MARK: - Mutations

    public func issueFine(_ req: IssueFineRequest) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let txn = try await apiClient.issueFine(req)
            applyTransaction(txn)
        } catch {
            self.error = error
        }
    }

    public func reverseTransaction(_ id: UUID, reason: String, appAttestToken: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let txn = try await apiClient.reverseTransaction(id, reason: reason, appAttestToken: appAttestToken)
            applyTransaction(txn)
        } catch {
            self.error = error
        }
    }

    // MARK: - Realtime application

    public func applyTransaction(_ txn: PointTransaction) {
        transactions.append(txn)
        balances[txn.userId, default: 0] += txn.amount
    }

    public func setBalance(_ balance: Int, for userId: UUID) {
        balances[userId] = balance
    }

    public func setTransactions(_ txns: [PointTransaction], for userId: UUID) {
        transactions.removeAll { $0.userId == userId }
        transactions.append(contentsOf: txns)
        // Recalculate balance from non-reversed transactions
        let userTotal = txns.filter { $0.reversedByTransactionId == nil }
                            .reduce(0) { $0 + $1.amount }
        balances[userId] = userTotal
    }
}
