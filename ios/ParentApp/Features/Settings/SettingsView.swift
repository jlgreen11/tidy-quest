import SwiftUI
import TidyQuestCore

/// Root Settings view. 8-section IA per PLAN §5.1.
@available(iOS 17, *)
struct SettingsView: View {

    var familyRepo: FamilyRepository
    var choreRepo: ChoreRepository
    var rewardRepo: RewardRepository
    var authController: AuthController

    var body: some View {
        NavigationStack {
            List {
                Section("Family") {
                    NavigationLink {
                        FamilySettingsView(familyRepo: familyRepo)
                    } label: {
                        SettingsRow(icon: "house.fill", color: .blue, label: "Family")
                    }
                }

                Section("Members") {
                    NavigationLink {
                        KidsSettingsView(familyRepo: familyRepo)
                    } label: {
                        SettingsRow(icon: "person.2.fill", color: .orange, label: "Kids")
                    }
                }

                Section("Chores & Rewards") {
                    NavigationLink {
                        ChoreDefaultsSettingsView(choreRepo: choreRepo)
                    } label: {
                        SettingsRow(icon: "checkmark.circle.fill", color: .green, label: "Chore defaults")
                    }

                    NavigationLink {
                        RewardDefaultsSettingsView(rewardRepo: rewardRepo)
                    } label: {
                        SettingsRow(icon: "gift.fill", color: .pink, label: "Reward defaults")
                    }
                }

                Section("Communication") {
                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        SettingsRow(icon: "bell.fill", color: .red, label: "Notifications")
                    }
                }

                Section("Economy") {
                    NavigationLink {
                        EconomySettingsView(familyRepo: familyRepo)
                    } label: {
                        SettingsRow(icon: "chart.bar.fill", color: .purple, label: "Economy")
                    }
                }

                Section("Data & Privacy") {
                    NavigationLink {
                        PrivacySettingsView(familyRepo: familyRepo)
                    } label: {
                        SettingsRow(icon: "lock.shield.fill", color: .teal, label: "Privacy & Data")
                    }
                }

                Section("Account") {
                    NavigationLink {
                        AccountSettingsView(
                            authController: authController,
                            familyRepo: familyRepo
                        )
                    } label: {
                        SettingsRow(icon: "person.crop.circle.fill", color: .gray, label: "Account")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Row helper

private struct SettingsRow: View {
    let icon: String
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)

            Text(label)
                .font(.body)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview("SettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    let chore = ChoreRepository(apiClient: client)
    let reward = RewardRepository(apiClient: client)
    let auth = AuthController(
        apiClient: client,
        keychain: KeychainStore(service: "com.jlgreen11.tidyquest.parent.preview")
    )
    family.loadSeedData()
    return SettingsView(
        familyRepo: family,
        choreRepo: chore,
        rewardRepo: reward,
        authController: auth
    )
}
