import SwiftUI
import TidyQuestCore

/// Onboarding Step 6 — Choose a preset chore pack.
@available(iOS 17, *)
struct PresetPackStep: View {

      var draft: CreateFamilyDraft
      let onContinue: () -> Void
    @State private var previewingPack: PresetPack? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose a chore pack")
                        .font(.largeTitle.weight(.bold))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pre-filled with age-appropriate chores and point values. You can edit anything after.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Pack cards
                ForEach(PresetPack.allCases) { pack in
                    PresetPackCard(
                        pack: pack,
                        isSelected: draft.selectedPack == pack,
                        onSelect: {
                            draft.selectedPack = pack
                            draft.chores = pack.prefillChores
                        },
                        onPreview: { previewingPack = pack }
                    )
                    .padding(.horizontal, 20)
                }

                // Continue
                Button {
                    if draft.selectedPack == nil {
                        // Default to age-appropriate pack
                        let pack: PresetPack = {
                            switch draft.kidAge {
                            case ..<8:   return .starter57
                            case 8..<11: return .standard810
                            case 11..<14: return .standard1114
                            default:     return .teenCash
                            }
                        }()
                        draft.selectedPack = pack
                        draft.chores = pack.prefillChores
                    }
                    onContinue()
                } label: {
                    Text(draft.selectedPack == nil ? "Use recommended pack" : "Continue with \(draft.selectedPack!.rawValue)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .accessibilityLabel("Continue with selected chore pack")
            }
        }
        .sheet(item: $previewingPack) { pack in
            PresetPackPreviewView(pack: pack) {
                draft.selectedPack = pack
                draft.chores = pack.prefillChores
                previewingPack = nil
                onContinue()
            }
        }
    }
}

// MARK: - Pack card

private struct PresetPackCard: View {
    let pack: PresetPack
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: pack.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .accentColor)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.accentColor : Color(.systemFill))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.rawValue)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(pack.ageRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(pack.prefillChores.count) chores pre-filled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Browse", action: onPreview)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Preview \(pack.rawValue) chores")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pack.rawValue), \(pack.ageRange), \(pack.prefillChores.count) chores\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview sheet

@available(iOS 17, *)
struct PresetPackPreviewView: View {
    let pack: PresetPack
    let onUseThisPack: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(pack.prefillChores) { chore in
                        HStack {
                            Image(systemName: chore.icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            Text(chore.name)
                                .font(.body)
                            Spacer()
                            Text("\(chore.points) pts")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("\(chore.name), \(chore.points) points")
                    }
                } header: {
                    Text("\(pack.rawValue) — \(pack.ageRange)")
                }
            }
            .navigationTitle("Pack Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel pack preview")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this pack") { onUseThisPack() }
                        .font(.body.weight(.semibold))
                        .accessibilityLabel("Use \(pack.rawValue) pack")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("PresetPackStep") {
    PresetPackStep(draft: CreateFamilyDraft(), onContinue: { })
}
