import SwiftUI
import TidyQuestCore

/// Settings §8 — Account: Apple identity, subscription status, sign out.
@available(iOS 17, *)
struct AccountSettingsView: View {

    var authController: AuthController
    var familyRepo: FamilyRepository

    @State private var showSignOutConfirm: Bool = false

    private var family: Family? { familyRepo.family }

    var body: some View {
        Form {
            // Identity card
            Section("Apple Account") {
                HStack(spacing: 12) {
                    Image(systemName: "applelogo")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        if let user = authController.currentUser {
                            Text(user.displayName)
                                .font(.body.weight(.medium))
                            if let sub = user.appleSub {
                                Text(sub.prefix(20) + "…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Not signed in")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    authController.currentUser.map { "Signed in as \($0.displayName)" }
                    ?? "Not signed in"
                )
            }

            // Subscription status
            Section("Subscription") {
                subscriptionStatusView
            }

            // Sign out
            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
                .accessibilityLabel("Sign out of TidyQuest")
                .accessibilityHint("Removes your session from this device.")
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                authController.signOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will need to sign in again to access your family's account.")
        }
    }

    // MARK: - Subscription view

    @ViewBuilder
    private var subscriptionStatusView: some View {
        if let family = family {
            switch family.subscriptionTier {
            case .trial:
                let daysLeft = daysUntil(family.subscriptionExpiresAt)
                VStack(alignment: .leading, spacing: 4) {
                    Label("Free Trial", systemImage: "clock.badge")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.orange)
                    if let days = daysLeft {
                        Text("Day \(14 - days) of 14 — trial ends in \(days) day\(days == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Free trial, \(daysLeft.map { "\($0) days remaining" } ?? "expired")")

                Button {
                    // Open StoreKit purchase sheet (stub in v0.1)
                } label: {
                    Label("Upgrade to Full Access", systemImage: "sparkles")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Upgrade to full TidyQuest subscription")
                .accessibilityHint("Opens subscription options: \u{24}5.99 per month or \u{24}39.99 per year.")

            case .monthly:
                Label("Monthly — $5.99/month", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Active monthly subscription at 5.99 per month")

                Link("Manage subscription in App Store", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(.body)
                    .accessibilityLabel("Manage subscription in App Store")

            case .yearly:
                Label("Yearly — $39.99/year", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Active yearly subscription at 39.99 per year")

                Link("Manage subscription in App Store", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(.body)
                    .accessibilityLabel("Manage subscription in App Store")

            case .expired:
                VStack(alignment: .leading, spacing: 4) {
                    Label("Subscription Expired", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Renew to restore full access.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    // Open StoreKit (stub in v0.1)
                } label: {
                    Label("Renew Subscription", systemImage: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Renew TidyQuest subscription")

            case .grace:
                Label("Grace Period", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Subscription in grace period. Please update billing.")
            }
        } else {
            ProgressView("Loading…")
                .accessibilityLabel("Loading subscription status")
        }
    }

    // MARK: - Helpers

    private func daysUntil(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: date)
        return max(0, diff.day ?? 0)
    }
}

// MARK: - Preview

#Preview("AccountSettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    let auth = AuthController(
        apiClient: client,
        keychain: KeychainStore(service: "com.jlgreen11.tidyquest.parent.preview")
    )
    family.loadSeedData()
    auth.setCurrentUser(MockAPIClient.seedUsers[0])
    return NavigationStack {
        AccountSettingsView(authController: auth, familyRepo: family)
    }
}
