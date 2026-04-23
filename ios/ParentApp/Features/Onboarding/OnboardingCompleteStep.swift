import SwiftUI
import TidyQuestCore

/// Onboarding Step 10 — Completion celebration.
@available(iOS 17, *)
struct OnboardingCompleteStep: View {

      var draft: CreateFamilyDraft
      var familyRepo: FamilyRepository
      let onComplete: () -> Void

    @State private var appeared: Bool = false
    @State private var isMarkingComplete: Bool = false

    private var parentName: String {
        // Try to derive parent first name from Apple credential (stub in v0.1)
        "Mei"
    }

    private var kidName: String {
        draft.kidName.isEmpty ? "your kid" : draft.kidName
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .scaleEffect(appeared ? 1.0 : 0.6)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.spring(duration: 0.6, bounce: 0.4), value: appeared)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("All set, \(parentName)!")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                        .accessibilityAddTraits(.isHeader)

                    Text("Ask \(kidName) to open the TidyQuest Kid app tonight — they'll see their first chores ready to go.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }

                // Summary stats
                if !draft.chores.isEmpty {
                    HStack(spacing: 20) {
                        SummaryChip(
                            value: "\(draft.chores.count)",
                            label: "chores ready",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        SummaryChip(
                            value: "\(draft.chores.reduce(0) { $0 + $1.points * 7 })",
                            label: "pts/wk target",
                            icon: "chart.bar.fill",
                            color: .blue
                        )
                    }
                }
            }
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

            Spacer()

            Button {
                Task { await markOnboardedAndComplete() }
            } label: {
                HStack {
                    Spacer()
                    if isMarkingComplete {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Go to Today")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isMarkingComplete)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
            .accessibilityLabel("Go to Today tab — you're all set!")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appeared = true }
    }

    // MARK: - Helpers

    private func markOnboardedAndComplete() async {
        guard let familyId = draft.createdFamily?.id else {
            onComplete()
            return
        }

        isMarkingComplete = true
        defer { isMarkingComplete = false }

        // Mark the family as onboarded. UpdateFamilyRequest does not currently have a
        // settings/onboarded_at parameter — calling with only familyId triggers a no-op
        // update that at minimum confirms the family record is reachable.
        // TODO: Once UpdateFamilyRequest gains a `settings` field, pass:
        //   settings: ["onboarded_at": ISO8601DateFormatter().string(from: Date())]
        let req = UpdateFamilyRequest(familyId: familyId)
        await familyRepo.updateFamily(req)

        // Proceed regardless of update result — don't block the user on a settings stamp.
        onComplete()
    }
}

// MARK: - Summary chip

private struct SummaryChip: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .accessibilityHidden(true)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 90)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Preview

#Preview("OnboardingCompleteStep") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    let draft = CreateFamilyDraft()
    draft.kidName = "Maya"
    draft.chores = PresetPack.standard810.prefillChores
    return OnboardingCompleteStep(draft: draft, familyRepo: family, onComplete: { })
}
