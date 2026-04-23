import SwiftUI
import TidyQuestCore

/// Settings §4 — Reward defaults: cooldown, auto-approve threshold.
/// Values are stored in family.settings jsonb under keys:
///   "default_cooldown_seconds", "default_auto_approve_threshold"
@available(iOS 17, *)
struct RewardDefaultsSettingsView: View {

    var familyRepo: FamilyRepository

    @State private var defaultCooldownDays: Double = 1
    @State private var hasCooldown: Bool = true
    @State private var autoApproveThreshold: Double = 30
    @State private var hasAutoApprove: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    // Snapshots for rollback
    @State private var savedCooldownDays: Double = 1
    @State private var savedHasCooldown: Bool = true
    @State private var savedAutoApproveThreshold: Double = 30
    @State private var savedHasAutoApprove: Bool = false

    private var cooldownSeconds: Int { Int(defaultCooldownDays) * 86400 }
    private var cooldownLabel: String {
        let days = Int(defaultCooldownDays)
        return days == 1 ? "1 day" : "\(days) days"
    }

    private var autoApproveLabel: String {
        let threshold = Int(autoApproveThreshold)
        return threshold == 0 ? "Never auto-approve" : "Auto-approve under \(threshold) pts"
    }

    var body: some View {
        Form {
            if let errorMessage {
                ErrorBanner(message: errorMessage) {
                    Task { await saveChanges() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Enable cooldown", isOn: $hasCooldown)
                    .accessibilityLabel("Enable reward cooldown by default")
                    .disabled(isSaving)

                if hasCooldown {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Default cooldown")
                            Spacer()
                            Text(cooldownLabel)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $defaultCooldownDays, in: 1...30, step: 1)
                            .accessibilityLabel("Default cooldown duration: \(cooldownLabel)")
                            .accessibilityValue(cooldownLabel)
                            .disabled(isSaving)
                    }
                }
            } header: {
                Text("Cooldown")
            } footer: {
                Text("Prevents kids from redeeming the same reward too frequently.")
            }

            Section {
                Toggle("Enable auto-approve", isOn: $hasAutoApprove)
                    .accessibilityLabel("Enable auto-approval threshold")
                    .disabled(isSaving)

                if hasAutoApprove {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Auto-approve threshold")
                            Spacer()
                            Text(autoApproveLabel)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $autoApproveThreshold, in: 10...200, step: 10)
                            .accessibilityLabel("Auto-approve threshold")
                            .accessibilityValue(autoApproveLabel)
                            .disabled(isSaving)
                    }
                }
            } header: {
                Text("Auto-Approval")
            } footer: {
                Text("Redemptions below this point cost are automatically approved. Saves approval friction for small rewards.")
            }

            Section {
                Button {
                    Task { await saveChanges() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .accessibilityLabel("Saving")
                        } else {
                            Text("Save Defaults")
                                .font(.body.weight(.semibold))
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
                .accessibilityLabel("Save reward defaults")
            }
        }
        .navigationTitle("Reward Defaults")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromRepo() }
    }

    // MARK: - Helpers

    private func loadFromRepo() {
        guard let family = familyRepo.family else { return }
        // TODO: read from family.settings["default_cooldown_seconds"] and
        // ["default_auto_approve_threshold"] once UpdateFamilyRequest exposes a settings field.
        if let secs = family.settings["default_cooldown_seconds"]?.value as? Int {
            let days = max(1, secs / 86400)
            defaultCooldownDays = Double(days)
            savedCooldownDays = Double(days)
            hasCooldown = true
            savedHasCooldown = true
        }
        if let threshold = family.settings["default_auto_approve_threshold"]?.value as? Int {
            autoApproveThreshold = Double(threshold)
            savedAutoApproveThreshold = Double(threshold)
            hasAutoApprove = threshold > 0
            savedHasAutoApprove = threshold > 0
        }
    }

    private func saveChanges() async {
        guard let family = familyRepo.family else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // TODO: wire full settings merge when UpdateFamilyRequest gains a settings field.
        // Actual cooldown/auto-approve values cannot be persisted until that field is added.
        let req = UpdateFamilyRequest(familyId: family.id)
        await familyRepo.updateFamily(req)

        if familyRepo.error != nil {
            // Roll back UI to last saved values
            defaultCooldownDays = savedCooldownDays
            hasCooldown = savedHasCooldown
            autoApproveThreshold = savedAutoApproveThreshold
            hasAutoApprove = savedHasAutoApprove
            errorMessage = familyRepo.error?.localizedDescription ?? "Failed to save. Please try again."
        } else {
            // Commit snapshot
            savedCooldownDays = defaultCooldownDays
            savedHasCooldown = hasCooldown
            savedAutoApproveThreshold = autoApproveThreshold
            savedHasAutoApprove = hasAutoApprove
        }
    }
}

// MARK: - Preview

#Preview("RewardDefaultsSettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    return NavigationStack {
        RewardDefaultsSettingsView(familyRepo: family)
    }
}
