import SwiftUI
import TidyQuestCore

/// Modal form for creating or editing a ChoreTemplate.
/// Shows a live expected-weekly-earnings band check (MVP-required per PLAN §2.2).
@available(iOS 17, *)
struct ChoreEditorView: View {
    let family: Family?
    let kids: [AppUser]
    let editingTemplate: ChoreTemplate?
    var onSave: (CreateChoreTemplateRequest) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form state

    @State private var name: String = ""
    @State private var icon: String = "star.fill"
    @State private var description: String = ""
    @State private var choreType: ChoreType = .daily
    @State private var basePoints: Int = 10
    @State private var cutoffTime: String = ""
    @State private var requiresPhoto: Bool = false
    @State private var requiresApproval: Bool = false
    @State private var onMissPolicy: OnMissPolicy = .decay
    @State private var onMissAmount: Int = 0
    @State private var selectedKidIds: Set<UUID> = []
    @State private var showIconPicker = false

    // Economy band check
    private var weeklyEarnings: Int { basePoints * 7 }   // simplified: daily × 7
    private var bandStatus: BandStatus {
        guard let bandStr = family?.weeklyBandTarget else { return .ok }
        // Parse "[low,high)" format
        let clean = bandStr.trimmingCharacters(in: .init(charactersIn: "[()] "))
        let parts = clean.split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard let low = parts.first ?? nil, let high = parts.last ?? nil else { return .ok }
        if weeklyEarnings < low      { return .low }
        if weeklyEarnings > Int(Double(high) * 1.20) { return .high }
        return .ok
    }

    enum BandStatus { case ok, low, high }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedKidIds.isEmpty
    }

    // MARK: - Initializer (pre-fill if editing)

    init(
        family: Family?,
        kids: [AppUser],
        editingTemplate: ChoreTemplate?,
        onSave: @escaping (CreateChoreTemplateRequest) -> Void
    ) {
        self.family = family
        self.kids = kids
        self.editingTemplate = editingTemplate
        self.onSave = onSave

        if let t = editingTemplate {
            _name = State(initialValue: t.name)
            _icon = State(initialValue: t.icon)
            _description = State(initialValue: t.description ?? "")
            _choreType = State(initialValue: t.type)
            _basePoints = State(initialValue: t.basePoints)
            _cutoffTime = State(initialValue: t.cutoffTime ?? "")
            _requiresPhoto = State(initialValue: t.requiresPhoto)
            _requiresApproval = State(initialValue: t.requiresApproval)
            _onMissPolicy = State(initialValue: t.onMiss)
            _onMissAmount = State(initialValue: t.onMissAmount)
            _selectedKidIds = State(initialValue: Set(t.targetUserIds))
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Chore details") {
                    HStack {
                        Button {
                            showIconPicker = true
                        } label: {
                            HStack {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                                Text("Icon")
                                    .foregroundStyle(.primary)
                            }
                        }
                        .accessibilityLabel("Choose icon. Currently: \(icon)")
                        .accessibilityHint("Opens icon picker")

                        Spacer()
                    }

                    TextField("Chore name", text: $name)
                        .accessibilityLabel("Chore name")
                        .accessibilityHint("Required")

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                        .accessibilityLabel("Description")
                }

                // Target kids
                Section("Assign to") {
                    if kids.isEmpty {
                        Text("No kids found. Add kids in the Family tab first.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(kids) { kid in
                            Toggle(isOn: Binding(
                                get: { selectedKidIds.contains(kid.id) },
                                set: { on in
                                    if on { selectedKidIds.insert(kid.id) }
                                    else  { selectedKidIds.remove(kid.id) }
                                }
                            )) {
                                HStack(spacing: 10) {
                                    KidAvatar(user: kid, size: 28)
                                    Text(kid.displayName)
                                }
                            }
                            .accessibilityLabel("Assign to \(kid.displayName)")
                        }
                    }
                }

                // Schedule and type
                Section("Schedule") {
                    Picker("Type", selection: $choreType) {
                        Text("One-off").tag(ChoreType.oneOff)
                        Text("Daily").tag(ChoreType.daily)
                        Text("Weekly").tag(ChoreType.weekly)
                    }
                    .accessibilityLabel("Chore type picker")

                    if !cutoffTime.isEmpty || choreType == .daily || choreType == .weekly {
                        TextField("Cutoff time (HH:MM)", text: $cutoffTime)
                            .keyboardType(.numbersAndPunctuation)
                            .accessibilityLabel("Cutoff time")
                            .accessibilityHint("Optional. Format: HH:MM, for example 09:00")
                    }
                }

                // Points and economy
                Section {
                    Stepper("Points: \(basePoints)", value: $basePoints, in: 1...500, step: 1)
                        .accessibilityLabel("Base points: \(basePoints)")
                        .accessibilityHint("Adjust with stepper or enter manually")

                    // Economy band check — MVP required
                    if family?.weeklyBandTarget != nil {
                        HStack {
                            Image(systemName: bandStatus == .ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(bandBannerColor)
                                .accessibilityHidden(true)
                            Text(bandBannerText)
                                .font(.caption)
                                .foregroundStyle(bandBannerColor)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Economy check: \(bandBannerText)")
                    }
                } header: {
                    Text("Points")
                } footer: {
                    Text("Expected weekly earnings from this chore: \(weeklyEarnings) pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Requirements
                Section("Requirements") {
                    Toggle("Requires photo proof", isOn: $requiresPhoto)
                        .accessibilityLabel("Photo proof required")
                    Toggle("Requires parent approval", isOn: $requiresApproval)
                        .accessibilityLabel("Parent approval required")
                }

                // On-miss policy
                Section("If missed") {
                    Picker("On-miss policy", selection: $onMissPolicy) {
                        Text("No penalty (decay)").tag(OnMissPolicy.decay)
                        Text("Skip (no record)").tag(OnMissPolicy.skip)
                        Text("Deduct points").tag(OnMissPolicy.deduct)
                    }
                    .accessibilityLabel("On miss policy")

                    if onMissPolicy == .deduct {
                        Stepper("Deduct: \(onMissAmount) pts", value: $onMissAmount, in: 0...100)
                            .accessibilityLabel("Deduction amount: \(onMissAmount) points")
                    }
                }
            }
            .navigationTitle(editingTemplate == nil ? "New Chore" : "Edit Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel without saving")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!isFormValid)
                        .accessibilityLabel("Save chore")
                        .accessibilityHint(isFormValid ? "Saves the chore template" : "Disabled until name and at least one kid are set")
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selectedIcon: $icon)
            }
        }
    }

    // MARK: - Band banner

    private var bandBannerColor: Color {
        switch bandStatus {
        case .ok:   .green
        case .low:  .orange
        case .high: .red
        }
    }

    private var bandBannerText: String {
        switch bandStatus {
        case .ok:   "Weekly earnings look good for this kid"
        case .low:  "Expected earnings below family target band"
        case .high: "This will push weekly earnings above band by > 20%"
        }
    }

    // MARK: - Save

    private func save() {
        guard let familyId = family?.id else { return }
        let req = CreateChoreTemplateRequest(
            familyId: familyId,
            name: name.trimmingCharacters(in: .whitespaces),
            icon: icon,
            description: description.isEmpty ? nil : description,
            type: choreType,
            schedule: defaultSchedule,
            targetUserIds: Array(selectedKidIds),
            basePoints: basePoints,
            cutoffTime: cutoffTime.isEmpty ? nil : cutoffTime,
            requiresPhoto: requiresPhoto,
            requiresApproval: requiresApproval,
            onMiss: onMissPolicy,
            onMissAmount: onMissAmount
        )
        onSave(req)
        dismiss()
    }

    private var defaultSchedule: [String: AnyCodable] {
        // Daily: all days. Weekly: weekdays. One-off: empty.
        switch choreType {
        case .daily:
            return ["daysOfWeek": AnyCodable([0,1,2,3,4,5,6])]
        case .weekly:
            return ["daysOfWeek": AnyCodable([1,2,3,4,5])]
        default:
            return [:]
        }
    }
}

// MARK: - Icon Picker (mini)

private struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss

    let icons: [String] = [
        "star.fill", "bed.double.fill", "heart.fill", "book.fill",
        "pawprint.fill", "house.fill", "fork.knife", "trash.fill",
        "cart.fill", "leaf.fill", "car.fill", "bicycle",
        "music.note", "film.fill", "paintbrush.fill", "hammer.fill",
        "wrench.fill", "tray.fill", "bag.fill", "cup.and.saucer.fill",
        "phone.fill", "laptopcomputer", "gamecontroller.fill", "book.closed.fill"
    ]

    private let columns = [GridItem(.adaptive(minimum: 56))]

    private func iconBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
    }

    private func iconBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(icons, id: \.self) { icon in
                        let isSelected = selectedIcon == icon
                        Button {
                            selectedIcon = icon
                            dismiss()
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 52, height: 52)
                                .background(iconBackground(isSelected: isSelected))
                                .overlay(iconBorder(isSelected: isSelected))
                                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        }
                        .accessibilityLabel("Icon: \(icon)")
                        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select")
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("ChoreEditorView — new") {
    ChoreEditorView(
        family: MockAPIClient.seedFamily,
        kids: MockAPIClient.seedUsers.filter { $0.role == .child },
        editingTemplate: nil
    ) { _ in }
}

#Preview("ChoreEditorView — edit") {
    ChoreEditorView(
        family: MockAPIClient.seedFamily,
        kids: MockAPIClient.seedUsers.filter { $0.role == .child },
        editingTemplate: MockAPIClient.seedTemplates.first
    ) { _ in }
}
