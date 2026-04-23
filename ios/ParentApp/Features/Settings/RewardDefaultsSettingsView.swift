import SwiftUI
import TidyQuestCore

/// Settings §4 — Reward defaults: cooldown, auto-approve threshold.
@available(iOS 17, *)
struct RewardDefaultsSettingsView: View {

    var rewardRepo: RewardRepository

    @State private var defaultCooldownDays: Double = 1
    @State private var hasCooldown: Bool = true
    @State private var autoApproveThreshold: Double = 30
    @State private var hasAutoApprove: Bool = false

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
            Section {
                Toggle("Enable cooldown", isOn: $hasCooldown)
                    .accessibilityLabel("Enable reward cooldown by default")

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
                    }
                }
            } header: {
                Text("Auto-Approval")
            } footer: {
                Text("Redemptions below this point cost are automatically approved. Saves approval friction for small rewards.")
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
                .accessibilityLabel("Save reward defaults")
            }
        }
        .navigationTitle("Reward Defaults")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("RewardDefaultsSettingsView") {
    let client = MockAPIClient()
    let reward = RewardRepository(apiClient: client)
    return NavigationStack {
        RewardDefaultsSettingsView(rewardRepo: reward)
    }
}
