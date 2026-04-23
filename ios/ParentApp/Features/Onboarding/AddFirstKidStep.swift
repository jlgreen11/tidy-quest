import SwiftUI
import TidyQuestCore

/// Onboarding Step 4 — Add first kid: name, age, avatar, color, tier.
@available(iOS 17, *)
struct AddFirstKidStep: View {

      @Bindable var draft: CreateFamilyDraft
      var familyRepo: FamilyRepository
      let onContinue: () -> Void

    // 24 avatar stub identifiers (illustrated in production)
    private static let avatarOptions: [String] = (1...24).map { "kid-\($0)" }
    private static let avatarIcons: [String] = [
        "star.fill", "heart.fill", "moon.stars.fill", "sun.max.fill",
        "leaf.fill", "flame.fill", "cloud.fill", "snowflake",
        "fish.fill", "tortoise.fill", "hare.fill", "pawprint.fill",
        "airplane", "bicycle", "car.fill", "train.fill",
        "paintbrush.fill", "music.note", "gamecontroller.fill", "books.vertical.fill",
        "magnifyingglass", "hammer.fill", "sportscourt.fill", "figure.run"
    ]

    @State private var showNameError: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showAlert: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Text("Add your first kid")
                        .font(.largeTitle.weight(.bold))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                        .accessibilityAddTraits(.isHeader)
                    Text("You can add more kids after setup.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
                .padding(.top, 24)

                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name").font(.subheadline.weight(.semibold))
                    TextField("Kid's name", text: $draft.kidName)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .disabled(isSubmitting)
                        .accessibilityLabel("Kid's name")
                }
                .padding(.horizontal, 24)

                // Age
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age").font(.subheadline.weight(.semibold))
                    HStack {
                        Stepper(value: $draft.kidAge, in: 3...17, onEditingChanged: { _ in }) {
                            Text("\(draft.kidAge) years old")
                                .font(.body)
                                .monospacedDigit()
                        }
                        .onChange(of: draft.kidAge) { _, _ in
                            draft.kidTier = draft.inferredTier
                        }
                    }
                    Text("Tier inferred: \(draft.kidTier.rawValue.capitalized) — you can change this.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .accessibilityElement(children: .contain)

                // Avatar picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Avatar").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 24)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
                        spacing: 12
                    ) {
                        ForEach(Array(Self.avatarOptions.enumerated()), id: \.element) { idx, av in
                            let iconName = Self.avatarIcons[idx % Self.avatarIcons.count]
                            let isSelected = draft.kidAvatar == av
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.accentColor : Color(.systemFill))
                                    .frame(width: 48, height: 48)
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .onTapGesture { draft.kidAvatar = av }
                            .accessibilityLabel("\(iconName) avatar\(isSelected ? ", selected" : "")")
                            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Color picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 24)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                        spacing: 12
                    ) {
                        ForEach(KidColor.allCases, id: \.rawValue) { color in
                            let hexStr = "#\(color.hex)"
                            let swiftColor = Color(hex: hexStr) ?? .gray
                            let isSelected = draft.kidColor == color
                            ZStack {
                                Circle()
                                    .fill(swiftColor)
                                    .frame(width: 44, height: 44)
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { draft.kidColor = color }
                            .accessibilityLabel("\(color.rawValue)\(isSelected ? ", selected" : "")")
                            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Tier override
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complexity Tier").font(.subheadline.weight(.semibold))
                    Picker("Tier", selection: $draft.kidTier) {
                        ForEach(ComplexityTier.allCases, id: \.self) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Complexity tier picker")
                }
                .padding(.horizontal, 24)

                // Continue
                Button {
                    guard !draft.kidName.trimmingCharacters(in: .whitespaces).isEmpty else {
                        showNameError = true
                        return
                    }
                    showNameError = false
                    Task { await addKidAndContinue() }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .accessibilityLabel("Continue with kid setup")

                if showNameError {
                    Text("Please enter your kid's name before continuing.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Error: kid name is required.")
                }
            }
        }
        .alert("Could Not Add Kid", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred.")
        }
    }

    // MARK: - Helpers

    private func addKidAndContinue() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        guard let familyId = draft.createdFamily?.id else {
            // Family not yet created — skip kid creation and proceed
            onContinue()
            return
        }

        let req = AddKidRequest(
            familyId: familyId,
            displayName: draft.kidName.trimmingCharacters(in: .whitespaces),
            avatar: draft.kidAvatar,
            color: "#\(draft.kidColor.hex)",
            complexityTier: draft.kidTier,
            birthdate: nil
        )
        await familyRepo.addKid(req)

        if let err = familyRepo.error {
            errorMessage = err.localizedDescription
            showAlert = true
            return
        }

        draft.createdKid = familyRepo.kids.last
        onContinue()
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

#Preview("AddFirstKidStep") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    return AddFirstKidStep(draft: CreateFamilyDraft(), familyRepo: family, onContinue: { })
}
