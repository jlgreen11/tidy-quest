import SwiftUI
import TidyQuestCore

/// Onboarding Step 10 — Completion celebration.
@available(iOS 17, *)
struct OnboardingCompleteStep: View {

      var draft: CreateFamilyDraft
      let onComplete: () -> Void
    @State private var appeared: Bool = false

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

            Button(action: onComplete) {
                Text("Go to Today")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
            .accessibilityLabel("Go to Today tab — you're all set!")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appeared = true }
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
    let draft = CreateFamilyDraft()
    draft.kidName = "Maya"
    draft.chores = PresetPack.standard810.prefillChores
    return OnboardingCompleteStep(draft: draft, onComplete: { })
}
