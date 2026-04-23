import Foundation
import Observation

/// Observable repository for challenges (quests).
/// Views bind to `activeQuests` and `upcomingQuests` directly.
@available(iOS 17, macOS 14, *)
@Observable
public final class QuestRepository: @unchecked Sendable {

    // MARK: - Published state

    public private(set) var activeQuests: [Challenge] = []
    public private(set) var upcomingQuests: [Challenge] = []
    public private(set) var completedQuests: [Challenge] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: (any Error)?

    // MARK: - Dependencies

    @ObservationIgnored private let api: any APIClient

    public init(apiClient: any APIClient) {
        self.api = apiClient
    }

    // MARK: - Load

    /// Fetch all challenges for the given family and partition by status.
    public func loadForFamily(_ familyId: UUID) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let all = try await api.fetchChallenges(familyId: familyId)
            let now = Date()
            activeQuests = all.filter { $0.status == .active && $0.endAt > now }
            upcomingQuests = all.filter { $0.status == .upcoming || ($0.status == .draft && $0.startAt > now) }
            completedQuests = all.filter { $0.status == .completed }
        } catch {
            self.error = error
            throw error
        }
    }

    /// Seed for mock / preview environments.
    public func loadSeedData() {
        let all = MockAPIClient.seedChallenges
        let now = Date()
        activeQuests = all.filter { $0.status == .active && $0.endAt > now }
        upcomingQuests = all.filter { $0.status == .upcoming || ($0.status == .draft && $0.startAt > now) }
        completedQuests = all.filter { $0.status == .completed }
    }

    // MARK: - Progress

    /// Computes completion progress for a specific quest and kid.
    /// "Completed" = the kid has a non-pending instance for each constituent template today.
    /// Since ChoreInstance data lives in ChoreRepository, callers supply the instances.
    public func progress(
        for quest: Challenge,
        userId: UUID,
        instances: [ChoreInstance]
    ) -> (completed: Int, total: Int) {
        let questTemplateIds = Set(quest.constituentChoreTemplateIds)
        let userInstances = instances.filter { $0.userId == userId && questTemplateIds.contains($0.templateId) }
        let doneCount = userInstances.filter { $0.status == .completed || $0.status == .approved }.count
        return (completed: doneCount, total: quest.constituentChoreTemplateIds.count)
    }

    // MARK: - Realtime application

    public func applyQuestUpdate(_ quest: Challenge) {
        let now = Date()
        func removeFromAll(_ id: UUID) {
            activeQuests.removeAll { $0.id == id }
            upcomingQuests.removeAll { $0.id == id }
            completedQuests.removeAll { $0.id == id }
        }
        removeFromAll(quest.id)
        switch quest.status {
        case .active where quest.endAt > now:
            activeQuests.append(quest)
        case .upcoming, .draft:
            upcomingQuests.append(quest)
        case .completed:
            completedQuests.append(quest)
        default:
            break   // expired / cancelled — drop from all lists
        }
    }
}
