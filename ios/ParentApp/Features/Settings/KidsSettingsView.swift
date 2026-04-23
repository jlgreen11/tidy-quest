import SwiftUI
import TidyQuestCore

/// Settings §2 — Kids roster with per-kid editing and add-kid flow.
@available(iOS 17, *)
struct KidsSettingsView: View {

    var familyRepo: FamilyRepository

    @State private var showAddKid: Bool = false
    @State private var isAdding: Bool = false
    @State private var addErrorMessage: String? = nil

    var body: some View {
        List {
            if let addErrorMessage {
                ErrorBanner(message: addErrorMessage)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if familyRepo.kids.isEmpty {
                ContentUnavailableView(
                    "No kids yet",
                    systemImage: "person.2",
                    description: Text("Tap + to add a kid.")
                )
            } else {
                ForEach(familyRepo.kids) { kid in
                    NavigationLink {
                        KidSettingsDetailView(kid: kid, familyRepo: familyRepo)
                    } label: {
                        KidSettingsRow(kid: kid)
                    }
                    .accessibilityLabel("\(kid.displayName), \(kid.complexityTier.rawValue) tier. Tap to edit.")
                }
            }
        }
        .navigationTitle("Kids")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddKid = true
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add kid")
                }
                .disabled(isAdding)
            }
        }
        .sheet(isPresented: $showAddKid) {
            AddKidSheet(familyRepo: familyRepo, isPresented: $showAddKid)
        }
    }
}

// MARK: - Add Kid Sheet

@available(iOS 17, *)
private struct AddKidSheet: View {

    var familyRepo: FamilyRepository
    @Binding var isPresented: Bool

    @State private var displayName: String = ""
    @State private var selectedColor: KidColor = .sky
    @State private var complexityTier: ComplexityTier = .standard
    @State private var isAdding: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    ErrorBanner(message: errorMessage) {
                        Task { await addKid() }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("Kid's name", text: $displayName)
                        .accessibilityLabel("Kid's display name")
                        .disabled(isAdding)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(KidColor.allCases, id: \.rawValue) { color in
                            let isSelected = selectedColor == color
                            Circle()
                                .fill(Color(hex: "#\(color.hex)") ?? .gray)
                                .frame(width: 44, height: 44)
                                .overlay(Circle().strokeBorder(isSelected ? .white : .clear, lineWidth: 3))
                                .overlay(
                                    isSelected ? Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.weight(.bold)) : nil
                                )
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
                    .disabled(isAdding)
                }
            }
            .navigationTitle("Add Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .disabled(isAdding)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                            .accessibilityLabel("Adding kid")
                    } else {
                        Button("Add") {
                            Task { await addKid() }
                        }
                        .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func addKid() async {
        guard let family = familyRepo.family else { return }
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isAdding = true
        errorMessage = nil
        defer { isAdding = false }

        let req = AddKidRequest(
            familyId: family.id,
            displayName: name,
            avatar: selectedColor.icon,
            color: selectedColor.hex,
            complexityTier: complexityTier,
            birthdate: nil
        )
        await familyRepo.addKid(req)

        if familyRepo.error != nil {
            errorMessage = familyRepo.error?.localizedDescription ?? "Failed to add kid. Please try again."
        } else {
            isPresented = false
        }
    }
}

// MARK: - Row

private struct KidSettingsRow: View {
    let kid: AppUser

    private var kidColor: Color {
        Color(hex: kid.color) ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(kidColor)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(kid.displayName.prefix(1)))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(kid.displayName)
                    .font(.body.weight(.medium))
                Text(kid.complexityTier.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

#Preview("KidsSettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    return NavigationStack {
        KidsSettingsView(familyRepo: family)
    }
}
