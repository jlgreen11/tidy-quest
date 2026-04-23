import SwiftUI
import TidyQuestCore

/// Onboarding Step 5 — Pair kid's device or skip.
@available(iOS 17, *)
struct PairKidDeviceStep: View {

      var draft: CreateFamilyDraft
      var familyRepo: FamilyRepository
      let onContinue: () -> Void
    @State private var pairingCode: String = ""
    @State private var isGenerating: Bool = false
    @State private var expiresAt: Date? = nil
    @State private var copyConfirmed: Bool = false

    private var kidName: String {
        draft.kidName.isEmpty ? "your kid" : draft.kidName
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "iphone.badge.play")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Pair \(kidName)'s device")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .accessibilityAddTraits(.isHeader)

                Text("Give \(kidName) a device with TidyQuest Kid installed. They'll enter this code to link their account.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }

            Spacer()

            VStack(spacing: 20) {
                if isGenerating {
                    ProgressView("Generating code…")
                        .accessibilityLabel("Generating pairing code")
                } else if !pairingCode.isEmpty {
                    // Code display
                    VStack(spacing: 8) {
                        Text(pairingCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .tracking(8)
                            .foregroundStyle(.primary)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityLabel("Pairing code: \(pairingCode.map { String($0) }.joined(separator: ", "))")

                        if let expires = expiresAt {
                            Text("Expires at \(expires, style: .time)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = pairingCode
                            copyConfirmed = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copyConfirmed = false
                            }
                        } label: {
                            Label(
                                copyConfirmed ? "Copied!" : "Copy code",
                                systemImage: copyConfirmed ? "checkmark" : "doc.on.doc.fill"
                            )
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(copyConfirmed ? .green : .accentColor)
                        .accessibilityLabel(copyConfirmed ? "Code copied to clipboard" : "Copy pairing code to clipboard")
                    }
                } else {
                    Button {
                        Task { await generateCode() }
                    } label: {
                        Text("Generate pairing code")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Generate a pairing code for \(kidName)'s device")
                }

                if !pairingCode.isEmpty {
                    Button("Done — device is paired", action: onContinue)
                        .font(.body.weight(.semibold))
                        .accessibilityLabel("Confirm device is paired and continue")
                }

                Button("Skip — use this device", action: onContinue)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Skip device pairing — use a shared device instead")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func generateCode() async {
        isGenerating = true
        defer { isGenerating = false }

        // Use a stub kid ID — in production this would be draft.createdKid?.id
        let kidId = UUID()
        do {
            let pairing = try await familyRepo.pairDevice(for: kidId)
            pairingCode = pairing.code
            expiresAt = pairing.expiresAt
            draft.pairingCode = pairing.code
        } catch {
            pairingCode = "ERROR"
        }
    }
}

// MARK: - Preview

#Preview("PairKidDeviceStep") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    let draft = CreateFamilyDraft()
    draft.kidName = "Maya"
    return PairKidDeviceStep(draft: draft, familyRepo: family, onContinue: { })
}
