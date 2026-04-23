import SwiftUI
import TidyQuestCore

/// Onboarding Step 1 — Value prop + primary CTA.
@available(iOS 17, *)
struct WelcomeStep: View {

    let onContinue: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero illustration area
            Image(systemName: "house.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .padding(.bottom, 32)
                .accessibilityHidden(true)

            // Headlines
            VStack(spacing: 12) {
                Text("Turn chores into a game\nyour kids will actually play.")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .accessibilityAddTraits(.isHeader)

                Text("Works for ages 5–14. Takes about 10 minutes to set up.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
            .padding(.horizontal, 24)

            Spacer()

            // CTAs
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Get started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Get started setting up TidyQuest")
                .accessibilityHint("Creates a new family account.")

                Button(action: onSignIn) {
                    Text("Already have an account? Sign in")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Sign in to existing account")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#Preview("WelcomeStep") {
    WelcomeStep(onContinue: { }, onSignIn: { })
}
