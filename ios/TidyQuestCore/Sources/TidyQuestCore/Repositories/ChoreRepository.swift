import Foundation
import Observation

/// Observable repository for chore templates, today's instances, pending approvals, and streaks.
@available(iOS 17, macOS 14, *)
@Observable
public final class ChoreRepository: @unchecked Sendable {

    // MARK: - Published state

    public private(set) var templates: [ChoreTemplate] = []
    public private(set) var todayInstances: [ChoreInstance] = []
    public private(set) var pendingApprovals: [ChoreInstance] = []
    public private(set) var streaks: [Streak] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: (any Error)?

    // MARK: - Derived

    /// Today's instances for a specific user.
    public func instances(for userId: UUID) -> [ChoreInstance] {
        todayInstances.filter { $0.userId == userId }
    }

    /// Current streak length for a given user + template pair.
    public func currentStreak(userId: UUID, templateId: UUID) -> Int {
        streaks.first { $0.userId == userId && $0.choreTemplateId == templateId }?.currentLength ?? 0
    }

    // MARK: - Dependencies

    private let apiClient: any APIClient

    public init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Seed

    public func loadSeedInstances(_ instances: [ChoreInstance]) {
        todayInstances = instances
        pendingApprovals = instances.filter { $0.status == .completed }
    }

    /// Seed the templates list (used at DEBUG app launch).
    public func loadSeedTemplates(_ templates: [ChoreTemplate]) {
        self.templates = templates
    }

    /// Seed streaks. Used at DEBUG app launch for views that render streak flames.
    public func loadSeedStreaks(_ streaks: [Streak]) {
        self.streaks = streaks
    }

    // MARK: - Template mutations

    public func createTemplate(_ req: CreateChoreTemplateRequest) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let template = try await apiClient.createChoreTemplate(req)
            templates.append(template)
        } catch {
            self.error = error
        }
    }

    public func updateTemplate(_ req: UpdateChoreTemplateRequest) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let updated = try await apiClient.updateChoreTemplate(req)
            if let idx = templates.firstIndex(where: { $0.id == updated.id }) {
                templates[idx] = updated
            }
        } catch {
            self.error = error
        }
    }

    public func archiveTemplate(_ id: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await apiClient.archiveChoreTemplate(id)
            templates.removeAll { $0.id == id }
        } catch {
            self.error = error
        }
    }

    // MARK: - Instance mutations

    public func completeChore(_ req: CompleteChoreRequest) async throws -> CompleteChoreResponse {
        let response = try await apiClient.completeChoreInstance(req)
        applyInstanceUpdate(response.instance)
        return response
    }

    public func approveChore(_ id: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let updated = try await apiClient.approveChoreInstance(id)
            applyInstanceUpdate(updated)
        } catch {
            self.error = error
        }
    }

    public func rejectChore(_ id: UUID, reason: String?) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let updated = try await apiClient.rejectChoreInstance(id, reason: reason)
            applyInstanceUpdate(updated)
        } catch {
            self.error = error
        }
    }

    // MARK: - Realtime application

    public func applyInstanceUpdate(_ instance: ChoreInstance) {
        if let idx = todayInstances.firstIndex(where: { $0.id == instance.id }) {
            todayInstances[idx] = instance
        } else {
            todayInstances.append(instance)
        }
        // Rebuild pending approvals
        pendingApprovals = todayInstances.filter { $0.status == .completed }
    }
}
