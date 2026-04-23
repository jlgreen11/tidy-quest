import SwiftUI
import TidyQuestCore

/// Onboarding Step 7 — Review and edit prefilled chores.
@available(iOS 17, *)
struct ReviewChoresStep: View {

      var draft: CreateFamilyDraft
      var apiClient: any APIClient
      let onContinue: () -> Void

    @State private var editingChore: DraftChore? = nil
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showAlert: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if draft.chores.isEmpty {
                    emptyState
                } else {
                    choreList
                }

                Divider()

                Button {
                    Task { await createChoresAndContinue() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Looks good — continue")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .accessibilityLabel("Continue with these chores")
            }
            .navigationTitle("Review Chores")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingChore) { chore in
                ChoreEditSheet(chore: chore) { updated in
                    if let idx = draft.chores.firstIndex(where: { $0.id == updated.id }) {
                        draft.chores[idx] = updated
                    }
                    editingChore = nil
                }
            }
            .alert("Could Not Save Chores", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
        }
    }

    // MARK: - List

    private var choreList: some View {
        let chores: [DraftChore] = draft.chores
        return List {
            Section {
                ForEach(chores, id: \.id) { (chore: DraftChore) in
                    HStack {
                        Image(systemName: chore.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(chore.name)
                            .font(.body)
                        Spacer()
                        Text("\(chore.points) pts")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button {
                            editingChore = chore
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(chore.name)")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(chore.name), \(chore.points) points. Swipe left to delete.")
                }
                .onDelete { indices in
                    draft.chores.remove(atOffsets: indices)
                }
            } header: {
                Text("Swipe left to remove, tap pencil to edit.")
                    .font(.caption)
            }
        }
        .toolbar {
            EditButton()
                .accessibilityLabel("Edit chores list")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No chores yet")
                .font(.headline)
            Text("Go back and choose a preset pack, or you can add chores from the Family tab after setup.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private func createChoresAndContinue() async {
        // If no family or kid yet, or no chores to create, skip API and proceed
        guard let familyId = draft.createdFamily?.id, !draft.chores.isEmpty else {
            onContinue()
            return
        }

        let kidIds: [UUID] = draft.createdKid.map { [$0.id] } ?? []
        let choresToCreate = draft.chores
        let dailySchedule: [String: AnyCodable] = [
            "daysOfWeek": AnyCodable([AnyCodable(0), AnyCodable(1), AnyCodable(2),
                                      AnyCodable(3), AnyCodable(4), AnyCodable(5), AnyCodable(6)])
        ]

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for chore in choresToCreate {
                    group.addTask {
                        let req = CreateChoreTemplateRequest(
                            familyId: familyId,
                            name: chore.name,
                            icon: chore.icon,
                            type: .daily,
                            schedule: dailySchedule,
                            targetUserIds: kidIds,
                            basePoints: chore.points
                        )
                        _ = try await apiClient.createChoreTemplate(req)
                    }
                }
                try await group.waitForAll()
            }
            onContinue()
        } catch {
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - Chore edit sheet

private struct ChoreEditSheet: View {
    let chore: DraftChore
    let onSave: (DraftChore) -> Void

    @State private var name: String
    @State private var points: Int

    init(chore: DraftChore, onSave: @escaping (DraftChore) -> Void) {
        self.chore = chore
        self.onSave = onSave
        _name = State(initialValue: chore.name)
        _points = State(initialValue: chore.points)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chore Name") {
                    TextField("Name", text: $name)
                        .accessibilityLabel("Chore name")
                }
                Section("Points") {
                    Stepper("\(points) pts", value: $points, in: 1...500)
                        .accessibilityLabel("Points: \(points)")
                        .accessibilityValue("\(points)")
                }
            }
            .navigationTitle("Edit Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onSave(chore) }
                        .accessibilityLabel("Cancel edit")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(DraftChore(id: chore.id, name: name, icon: chore.icon, points: points))
                    }
                    .font(.body.weight(.semibold))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Save chore changes")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("ReviewChoresStep") {
    let draft = CreateFamilyDraft()
    draft.chores = PresetPack.standard810.prefillChores
    return ReviewChoresStep(draft: draft, apiClient: MockAPIClient(), onContinue: { })
}
