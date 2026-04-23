import Foundation
import AuthenticationServices
import Observation

/// Manages authentication for both the Parent app (Sign in with Apple)
/// and the Kid app (device pairing token).
///
/// Conforms to `@Observable` so SwiftUI views bind directly to `currentUser`.
@available(iOS 17, macOS 14, *)
@Observable
public final class AuthController: NSObject, @unchecked Sendable {

    // MARK: - Published state

    /// The currently authenticated user, or nil if not signed in.
    public private(set) var currentUser: AppUser?

    /// True while an auth operation is in flight.
    public private(set) var isLoading: Bool = false

    /// Set if sign-in or token load fails.
    public private(set) var authError: (any Error)?

    // MARK: - Dependencies

    private let apiClient: any APIClient
    private let keychain: KeychainStore

    // MARK: - Init

    public init(apiClient: any APIClient, keychain: KeychainStore) {
        self.apiClient = apiClient
        self.keychain = keychain
    }

    // MARK: - Startup

    /// Called at app launch to restore persisted session.
    /// For kid app: restores from stored device token.
    /// For parent app: Supabase SDK manages JWT session; call `setCurrentUser` after validation.
    public func restoreSession() async {
        isLoading = true
        defer { isLoading = false }
        guard let storedToken = try? keychain.get(forKey: KeychainStore.Keys.deviceToken),
              !storedToken.isEmpty else { return }
        do {
            let bundle = Bundle.main.bundleIdentifier ?? "com.jlgreen11.tidyquest.kid"
            let result = try await apiClient.claimPairing(
                ClaimPairingRequest(pairingCode: storedToken, appBundle: bundle)
            )
            currentUser = result.user
        } catch {
            // Token expired or revoked — clear it
            try? keychain.delete(forKey: KeychainStore.Keys.deviceToken)
            currentUser = nil
        }
    }

    // MARK: - Parent: Sign in with Apple

    /// Initiates Sign in with Apple for the parent app.
    /// On success, persists the JWT and sets `currentUser`.
    @MainActor
    public func signInWithApple() {
        isLoading = true
        authError = nil

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    /// Called internally after successful Apple auth credential is received.
    func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async {
        defer { isLoading = false }
        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            authError = AuthError.missingIdentityToken
            return
        }
        do {
            try keychain.set(token, forKey: KeychainStore.Keys.parentJWT)
            try keychain.set(credential.user, forKey: KeychainStore.Keys.currentUserId)
        } catch {
            authError = error
        }
    }

    // MARK: - Kid: Device pairing

    /// Claim a pairing code from the parent app.
    /// Persists the device token in Keychain and sets `currentUser`.
    public func claimPairing(code: String) async {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        do {
            let bundle = Bundle.main.bundleIdentifier ?? "com.jlgreen11.tidyquest.kid"
            let result = try await apiClient.claimPairing(
                ClaimPairingRequest(pairingCode: code, appBundle: bundle)
            )
            try keychain.set(result.deviceToken, forKey: KeychainStore.Keys.deviceToken)
            try keychain.set(result.user.id.uuidString, forKey: KeychainStore.Keys.currentUserId)
            currentUser = result.user
        } catch {
            authError = error
        }
    }

    // MARK: - Set current user (external injection post-Supabase auth)

    public func setCurrentUser(_ user: AppUser) {
        currentUser = user
    }

    // MARK: - Sign out

    public func signOut() {
        currentUser = nil
        try? keychain.delete(forKey: KeychainStore.Keys.parentJWT)
        try? keychain.delete(forKey: KeychainStore.Keys.deviceToken)
        try? keychain.delete(forKey: KeychainStore.Keys.currentUserId)
    }
}

// MARK: - ASAuthorizationControllerDelegate

@available(iOS 17, macOS 14, *)
extension AuthController: ASAuthorizationControllerDelegate {
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            isLoading = false
            return
        }
        Task { await handleAppleCredential(credential) }
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        isLoading = false
        authError = error
    }
}

// MARK: - Auth errors

public enum AuthError: Error, Sendable, LocalizedError {
    case missingIdentityToken
    case sessionExpired

    public var errorDescription: String? {
        switch self {
        case .missingIdentityToken: "Apple identity token was missing."
        case .sessionExpired:       "Your session has expired. Please sign in again."
        }
    }
}
