import SwiftUI
import TidyQuestCore

/// Onboarding Step 3 — Optional co-parent invite.
@available(iOS 17, *)
struct CoParentInviteStep: View {

      @Bindable var draft: CreateFamilyDraft
      let onContinue: () -> Void
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
                    .accessibilityLabel("Partner's phone number or Apple ID")
                    .accessibilityHint("Enter their phone number or Apple ID email to send an invite.")

                Button {
                    if !draft.coParentContact.isEmpty {
                        // Invite logic wired in Act 4
                    }
                    onContinue()
                } label: {
                    Text("Send Invite")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.coParentContact.isEmpty)
                .padding(.horizontal, 24)
                .accessibilityLabel("Send co-parent invite")
                .accessibilityHint("Sends an invite to the entered contact.")

                Button("Skip for now", action: onContinue)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Skip co-parent invite for now")
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("CoParentInviteStep") {
    CoParentInviteStep(draft: CreateFamilyDraft(), onContinue: { })
}
