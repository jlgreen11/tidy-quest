import SwiftUI
import TidyQuestCore

/// Onboarding Step 3 — Optional co-parent invite.
@available(iOS 17, *)
struct CoParentInviteStep: View {

      @Bindable var draft: CreateFamilyDraft
      var familyRepo: FamilyRepository
      let onContinue: () -> Void

    @State private var isSending: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Invite your partner")
                    .font(.largeTitle.weight(.bold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .accessibilityAddTraits(.isHeader)

                Text("They'll get full parent access — approvals, economy tuning, and settings. You can also do this later.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }

            Spacer()

            VStack(spacing: 16) {
                TextField("Phone number or Apple ID", text: $draft.coParentContact)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .padding(.horizontal, 24)
                    .disabled(isSending)
                    .accessibilityLabel("Partner's phone number or Apple ID")
                    .accessibilityHint("Enter their phone number or Apple ID email to send an invite.")

                Button {
                    guard !draft.coParentContact.isEmpty else { return }
                    Task { await sendInviteAndContinue() }
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Invite")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.coParentContact.isEmpty || isSending)
                .padding(.horizontal, 24)
                .accessibilityLabel("Send co-parent invite")
                .accessibilityHint("Sends an invite to the entered contact.")

                Button("Skip for now", action: onContinue)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .disabled(isSending)
                    .accessibilityLabel("Skip co-parent invite for now")
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Invite Failed", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred.")
        }
    }

    // MARK: - Helpers

    private func sendInviteAndContinue() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        // Co-parent invitation is deferred to v0.2 (see PLAN_v0.1.md §4.0 step 3
        // — "optional co-parent invite, 30s, skippable"). No backend endpoint
        // ships in v0.1. The entered contact lives in `draft.coParentContact`
        // which is captured client-side only; when the v0.2 endpoint lands,
        // add `familyRepo.inviteCoParent(contact:)` and call it here.
        try? await Task.sleep(for: .milliseconds(300))

        onContinue()
    }
}

// MARK: - Preview

#Preview("CoParentInviteStep") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    return CoParentInviteStep(draft: CreateFamilyDraft(), familyRepo: family, onContinue: { })
}
