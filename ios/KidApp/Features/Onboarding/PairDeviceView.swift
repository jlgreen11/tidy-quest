import SwiftUI
import TidyQuestCore

// MARK: - PairDeviceView

/// Shown when no keychain device token exists.
/// Kid enters the 10-character pairing code shown on the parent's phone.
/// Calls AuthController.claimPairing. On success, transitions to home.
struct PairDeviceView: View {
    @Bindable var authController: AuthController

    // MARK: - State

    @State private var code = ""
    @FocusState private var isCodeFocused: Bool

    private let codeLength = 10
    private let allowedChars = CharacterSet.alphanumerics

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo / hero
            VStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.bounce, options: .repeating.speed(0.5))

                Text("TidyQuest")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Enter the code from your parent's phone")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("TidyQuest. Enter the code from your parent's phone.")

            // Code input
            VStack(spacing: 16) {
                codeInput
                    .focused($isCodeFocused)

                if let error = authController.authError {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .accessibilityLabel("Error: \(error.localizedDescription)")
                }
            }

            // Connect button
            Button {
                Task { await authController.claimPairing(code: normalizedCode) }
            } label: {
                Group {
                    if authController.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Connect to Family")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isCodeValid ? Color.blue : Color.secondary.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!isCodeValid || authController.isLoading)
            .padding(.horizontal, 32)
            .animation(.spring(duration: 0.25), value: isCodeValid)
            .accessibilityLabel(authController.isLoading ? "Connecting…" : "Connect to Family")
            .accessibilityHint(isCodeValid ? "" : "Enter all \(codeLength) characters first")

            // Help text
            VStack(spacing: 4) {
                Text("Having trouble?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Ask your parent to open TidyQuest and tap 'Pair device' to get a fresh code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear { isCodeFocused = true }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Code input

    @ViewBuilder
    private var codeInput: some View {
        VStack(spacing: 12) {
            // Visual segmented code display
            HStack(spacing: 6) {
                ForEach(0..<codeLength, id: \.self) { i in
                    let char = charAt(i)
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        i < normalizedCode.count ? Color.blue : Color.secondary.opacity(0.3),
                                        lineWidth: i < normalizedCode.count ? 2 : 1
                                    )
                            }
                        if let char {
                            Text(String(char).uppercased())
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                        } else if i == normalizedCode.count {
                            // Cursor indicator
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 2, height: 20)
                        }
                    }
                    .frame(width: 30, height: 44)
                }
            }
            .accessibilityHidden(true) // Screen reader uses the hidden text field

            // Hidden text field — receives keyboard input
            TextField("Enter pairing code", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.default)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .onChange(of: code) { _, new in
                    // Filter to alphanumeric, uppercase, max length
                    let filtered = new.uppercased()
                        .filter { $0.isLetter || $0.isNumber }
                        .prefix(codeLength)
                    if code != String(filtered) { code = String(filtered) }
                }
                .accessibilityLabel("Pairing code, \(normalizedCode.count) of \(codeLength) characters entered")
        }
        .onTapGesture { isCodeFocused = true }
    }

    // MARK: - Helpers

    private var normalizedCode: String {
        String(code.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(codeLength))
    }

    private var isCodeValid: Bool { normalizedCode.count == codeLength }

    private func charAt(_ i: Int) -> Character? {
        let s = normalizedCode
        guard i < s.count else { return nil }
        return s[s.index(s.startIndex, offsetBy: i)]
    }
}

// MARK: - Preview
#Preview("PairDeviceView") {
    @Previewable @State var auth = AuthController(apiClient: MockAPIClient(), keychain: KeychainStore(service: "com.jlgreen11.tidyquest.kid"))
    return PairDeviceView(authController: auth)
}
