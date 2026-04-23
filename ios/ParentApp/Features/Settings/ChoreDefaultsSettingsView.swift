import SwiftUI
import TidyQuestCore

/// Settings §3 — Chore defaults: on_miss policy, requires_approval, cutoff time.
/// Values are stored in family.settings jsonb under keys:
///   "default_on_miss", "default_requires_approval", "default_cutoff_time"
@available(iOS 17, *)
struct ChoreDefaultsSettingsView: View {

    var familyRepo: FamilyRepository

    @State private var defaultOnMiss: OnMissPolicy = .decay
    @State private var defaultRequiresApproval: Bool = false
    @State private var defaultCutoffTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
    @State private var hasCutoffTime: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    // Snapshots for rollback
    @State private var savedOnMiss: OnMissPolicy = .decay
    @State private var savedRequiresApproval: Bool = false
    @State private var savedHasCutoffTime: Bool = false

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
                Picker("On-miss policy", selection: $defaultOnMiss) {
                    Text("Skip (no points, no penalty)").tag(OnMissPolicy.skip)
                    Text("Decay (point multiplier drops)").tag(OnMissPolicy.decay)
                    Text("Deduct (points removed)").tag(OnMissPolicy.deduct)
                }
                .accessibilityLabel("Default on-miss policy for new chores")
                .disabled(isSaving)

                Text(onMissPolicyDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("On-Miss Policy")
            } footer: {
                Text("This default applies to new chores. You can override per chore.")
            }

            Section("Approval") {
                Toggle("Require approval by default", isOn: $defaultRequiresApproval)
                    .accessibilityLabel("Require parent approval for new chores by default")
                    .disabled(isSaving)
            }

            Section("Cutoff Time") {
                Toggle("Set default cutoff time", isOn: $hasCutoffTime)
                    .accessibilityLabel("Enable default cutoff time for new chores")
                    .disabled(isSaving)

                if hasCutoffTime {
                    DatePicker(
                        "Cutoff time",
                        selection: $defaultCutoffTime,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityLabel("Default chore cutoff time")
                    .disabled(isSaving)
                }
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
                .accessibilityLabel("Save chore defaults")
            }
        }
        .navigationTitle("Chore Defaults")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromRepo() }
    }

    // MARK: - Helpers

    private func loadFromRepo() {
        guard let family = familyRepo.family else { return }
        if let raw = family.settings["default_on_miss"]?.value as? String,
           let policy = OnMissPolicy(rawValue: raw) {
            defaultOnMiss = policy
            savedOnMiss = policy
        }
        if let val = family.settings["default_requires_approval"]?.value as? Bool {
            defaultRequiresApproval = val
            savedRequiresApproval = val
        }
        if let cutoff = family.settings["default_cutoff_time"]?.value as? String,
           let parsed = parseTime(cutoff) {
            defaultCutoffTime = parsed
            hasCutoffTime = true
            savedHasCutoffTime = true
        }
    }

    private func saveChanges() async {
        guard let family = familyRepo.family else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        var settingsPayload: [String: AnyCodable] = [
            "default_on_miss": AnyCodable(defaultOnMiss.rawValue),
            "default_requires_approval": AnyCodable(defaultRequiresApproval),
        ]
        if hasCutoffTime {
            settingsPayload["default_cutoff_time"] = AnyCodable(formatTime(defaultCutoffTime))
        } else {
            settingsPayload["default_cutoff_time"] = AnyCodable(nil as String?)
        }
        let req = UpdateFamilyRequest(familyId: family.id, settings: settingsPayload)
        await familyRepo.updateFamily(req)

        if familyRepo.error != nil {
            // Roll back UI to last saved values
            defaultOnMiss = savedOnMiss
            defaultRequiresApproval = savedRequiresApproval
            hasCutoffTime = savedHasCutoffTime
            errorMessage = familyRepo.error?.localizedDescription ?? "Failed to save. Please try again."
        } else {
            // Commit snapshot
            savedOnMiss = defaultOnMiss
            savedRequiresApproval = defaultRequiresApproval
            savedHasCutoffTime = hasCutoffTime
        }
    }

    private func parseTime(_ str: String) -> Date? {
        let parts = str.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())
    }

    private func formatTime(_ date: Date) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return String(format: "%02d:%02d", h, m)
    }

    private var onMissPolicyDescription: String {
        switch defaultOnMiss {
        case .skip:
            return "Missed chores are silently skipped. No penalty."
        case .decay:
            return "Streak multiplier reduces. Points for future completions are lower."
        case .deduct:
            return "Points are deducted when a chore is missed. Use with caution."
        }
    }
}

// MARK: - Preview

#Preview("ChoreDefaultsSettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    return NavigationStack {
        ChoreDefaultsSettingsView(familyRepo: family)
    }
}
