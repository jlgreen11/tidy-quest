import SwiftUI
import TidyQuestCore

/// Per-kid settings: name, color, tier, photo-proof defaults, reward categories.
@available(iOS 17, *)
struct KidSettingsDetailView: View {

    let kid: AppUser
    var familyRepo: FamilyRepository

    @State private var displayName: String = ""
    @State private var selectedColor: KidColor = .sky
    @State private var complexityTier: ComplexityTier = .standard
    @State private var defaultRequiresPhoto: Bool = false
    @State private var showScreenTime: Bool = true
    @State private var showCashOut: Bool = false
    @State private var isSaving: Bool = false

    private var kidSwiftColor: Color {
        Color(hex: kid.color) ?? .accentColor
    }

    var body: some View {
        Form {
            Section("Identity") {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Kid's name", text: $displayName)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Kid's display name")
                        .disabled(isSaving)
                }
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(KidColor.allCases, id: \.rawValue) { color in
                        let hex = "#\(color.hex)"
                        let isSelected = selectedColor == color
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .strokeBorder(isSelected ? .white : .clear, lineWidth: 3)
                            )
                            .overlay(
                                isSelected ? Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.weight(.bold)) : nil
                            )
                            .shadow(color: isSelected ? (Color(hex: hex) ?? .gray).opacity(0.5) : .clear, radius: 4)
                            .onTapGesture { selectedColor = color }
                            .accessibilityLabel("\(color.rawValue) color\(isSelected ? ", selected" : "")")
                            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Complexity Tier") {
                Picker("Tier", selection: $complexityTier) {
                    ForEach(ComplexityTier.allCases, id: \.self) { tier in
                        Text(tier.rawValue.capitalized).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isSaving)
                .accessibilityLabel("Complexity tier picker")

                tierDescription
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Photo Proof Defaults") {
                Toggle("Require photo by default", isOn: $defaultRequiresPhoto)
                    .accessibilityLabel("Require photo proof by default for new chores")
                    .disabled(isSaving)
            }

            Section("Reward Categories") {
                Toggle("Screen time rewards", isOn: $showScreenTime)
                    .accessibilityLabel("Show screen time rewards")
                    .disabled(isSaving)
                Toggle("Cash-out rewards", isOn: $showCashOut)
                    .accessibilityLabel("Show cash-out rewards")
                    .disabled(isSaving)
            }

            Section {
                Button {
                    Task { await saveChanges() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Changes")
                                .font(.body.weight(.semibold))
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
                .accessibilityLabel("Save kid settings")
            }
        }
        .navigationTitle(kid.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromKid() }
    }

    // MARK: - Tier description

    private var tierDescription: Text {
        switch complexityTier {
        case .starter:
            return Text("Starter: Large icons, jar balance, no streaks shown. Best for ages 5–7.")
        case .standard:
            return Text("Standard: SF Symbols, numeric balance, streaks visible. Best for ages 8–11.")
        case .advanced:
            return Text("Advanced: Minimal icons, full ledger visible. Best for ages 12+.")
        }
    }

    // MARK: - Helpers

    private func loadFromKid() {
        displayName = kid.displayName
        complexityTier = kid.complexityTier
        // Map hex to KidColor
        let bare = kid.color.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        selectedColor = KidColor.allCases.first { $0.hex.uppercased() == bare } ?? .sky
    }

    private func saveChanges() async {
        // TODO: wire to API when updateKid is added (no updateKid endpoint exists yet).
        // Changes are held in local @State so the UI reflects edits within the session.
        isSaving = true
        defer { isSaving = false }
        try? await Task.sleep(for: .milliseconds(300))
    }
}

// MARK: - Color helper

private extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        self.init(
            red:   Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue:  Double( rgbValue & 0x0000FF) / 255.0
        )
    }
}

// MARK: - Preview

#Preview("KidSettingsDetailView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    let kid = MockAPIClient.seedUsers.first { $0.role == .child }!
    return NavigationStack {
        KidSettingsDetailView(kid: kid, familyRepo: family)
    }
}
