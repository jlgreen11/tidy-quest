import SwiftUI
import TidyQuestCore

/// Settings §3 — Chore defaults: on_miss policy, requires_approval, cutoff time.
@available(iOS 17, *)
struct ChoreDefaultsSettingsView: View {

    var choreRepo: ChoreRepository

    @State private var defaultOnMiss: OnMissPolicy = .decay
    @State private var defaultRequiresApproval: Bool = false
    @State private var defaultCutoffTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
    @State private var hasCutoffTime: Bool = false

    var body: some View {
        Form {
            Section {
                Picker("On-miss policy", selection: $defaultOnMiss) {
                    Text("Skip (no points, no penalty)").tag(OnMissPolicy.skip)
                    Text("Decay (point multiplier drops)").tag(OnMissPolicy.decay)
                    Text("Deduct (points removed)").tag(OnMissPolicy.deduct)
                }
                .accessibilityLabel("Default on-miss policy for new chores")

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
            }

            Section("Cutoff Time") {
                Toggle("Set default cutoff time", isOn: $hasCutoffTime)
                    .accessibilityLabel("Enable default cutoff time for new chores")

                if hasCutoffTime {
                    DatePicker(
                        "Cutoff time",
                        selection: $defaultCutoffTime,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityLabel("Default chore cutoff time")
                }
            }

            Section {
                Button {
                    // Persist to family settings JSON (stub in v0.1)
                } label: {
                    HStack {
                        Spacer()
                        Text("Save Defaults")
                            .font(.body.weight(.semibold))
                        Spacer()
                    }
                }
                .accessibilityLabel("Save chore defaults")
            }
        }
        .navigationTitle("Chore Defaults")
        .navigationBarTitleDisplayMode(.inline)
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
    let chore = ChoreRepository(apiClient: client)
    return NavigationStack {
        ChoreDefaultsSettingsView(choreRepo: chore)
    }
}
