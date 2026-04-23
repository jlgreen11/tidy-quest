import SwiftUI
import AuthenticationServices
import TidyQuestCore

/// Onboarding Step 2 — Sign in with Apple, then create the family record.
@available(iOS 17, *)
struct SignInAppleStep: View {

    var authController: AuthController
    var familyRepo: FamilyRepository
      var draft: CreateFamilyDraft
      let onContinue: () -> Void
    @State private var errorMessage: String? = nil
    @State private var isCreatingFamily: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "applelogo")
                    .font(.system(size: 56))
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)

                Text("Sign in with Apple")
                    .font(.largeTitle.weight(.bold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .accessibilityAddTraits(.isHeader)

                Text("Your data stays private. TidyQuest only receives your name and email the first time you sign in.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }

            Spacer()

            VStack(spacing: 16) {
                if authController.isLoading || isCreatingFamily {
                    ProgressView(isCreatingFamily ? "Creating family…" : "Signing in…")
                        .accessibilityLabel(isCreatingFamily ? "Creating family" : "Signing in with Apple")
                } else {
                    SignInWithAppleButton(.signIn, onRequest: configureRequest, onCompletion: handleResult)
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .accessibilityLabel("Sign in with Apple")

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("Error: \(err)")
                    }
                }

                // Skip for simulator/debug
                #if DEBUG
                Button("Skip (dev only)") {
                    Task { await createFamilyAndContinue(displayName: "Dev Parent") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .disabled(isCreatingFamily)
                .accessibilityLabel("Skip sign in (development only)")
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Apple Sign-In handlers

    private func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleResult(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let name = [
                credential.fullName?.givenName,
                credential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")
            Task { await createFamilyAndContinue(displayName: name.isEmpty ? "Parent" : name) }
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }

    private func createFamilyAndContinue(displayName: String) async {
        isCreatingFamily = true
        errorMessage = nil
        defer { isCreatingFamily = false }
        let req = CreateFamilyRequest(
            name: draft.familyName.isEmpty ? "\(displayName)'s Family" : draft.familyName,
            timezone: draft.timezone
        )
        await familyRepo.createFamily(req)
        if let err = familyRepo.error {
            errorMessage = err.localizedDescription
            return
        }
        draft.createdFamily = familyRepo.family
        onContinue()
    }
}

// MARK: - Preview

#Preview("SignInAppleStep") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    let auth = AuthController(
        apiClient: client,
        keychain: KeychainStore(service: "com.jlgreen11.tidyquest.parent.preview")
    )
    return SignInAppleStep(
        authController: auth,
        familyRepo: family,
        draft: CreateFamilyDraft(),
        onContinue: { }
    )
}
