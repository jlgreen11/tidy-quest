import SwiftUI
import TidyQuestCore

/// Modal form for creating or editing a Reward.
@available(iOS 17, *)
struct RewardEditorView: View {
    let family: Family?
    let editingReward: Reward?
    var onSave: (RewardEditorForm) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form model

    struct RewardEditorForm {
        var name: String
        var icon: String
        var category: RewardCategory
        var price: Int
        var cooldownDays: Int           // 0 = no cooldown
        var autoApproveUnder: Int?      // nil = never auto-approve
        var enableAutoApprove: Bool
    }

    @State private var form: RewardEditorForm
    @State private var showIconPicker = false

    init(
        family: Family?,
        editingReward: Reward?,
        onSave: @escaping (RewardEditorForm) -> Void
    ) {
        self.family = family
        self.editingReward = editingReward
        self.onSave = onSave

        let initial: RewardEditorForm
        if let r = editingReward {
            let cooldownDays = r.cooldown.map { $0 / 86400 } ?? 0
            initial = RewardEditorForm(
                name: r.name,
                icon: r.icon,
                category: r.category,
                price: r.price,
                cooldownDays: cooldownDays,
                autoApproveUnder: r.autoApproveUnder,
                enableAutoApprove: r.autoApproveUnder != nil
            )
        } else {
            initial = RewardEditorForm(
                name: "",
                icon: "gift.fill",
                category: .privilege,
                price: 50,
                cooldownDays: 0,
                autoApproveUnder: nil,
                enableAutoApprove: false
            )
        }
        _form = State(initialValue: initial)
    }

    private var isFormValid: Bool {
        !form.name.trimmingCharacters(in: .whitespaces).isEmpty && form.price > 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Reward details") {
                    HStack {
                        Button {
                            showIconPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: form.icon)
                                    .font(.title2)
                                    .frame(width: 36, height: 36)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(.primary)
                                Text("Icon")
                                    .foregroundStyle(.primary)
                            }
                        }
                        .accessibilityLabel("Choose icon. Currently: \(form.icon)")
                    }

                    TextField("Reward name", text: $form.name)
                        .accessibilityLabel("Reward name")
                        .accessibilityHint("Required")

                    Picker("Category", selection: $form.category) {
                        Text("Screen Time").tag(RewardCategory.screenTime)
                        Text("Treat").tag(RewardCategory.treat)
                        Text("Privilege").tag(RewardCategory.privilege)
                        Text("Cash Out").tag(RewardCategory.cashOut)
                        Text("Saving Goal").tag(RewardCategory.savingGoal)
                        Text("Other").tag(RewardCategory.other)
                    }
                    .accessibilityLabel("Category picker")
                }

                // Pricing
                Section {
                    Stepper("Price: \(form.price) pts", value: $form.price, in: 1...2000, step: 5)
                        .accessibilityLabel("Price: \(form.price) points")
                } header: {
                    Text("Price")
                } footer: {
                    Text("Kids need this many points to request this reward.")
                }

                // Cooldown
                Section {
                    Stepper(cooldownLabel, value: $form.cooldownDays, in: 0...365)
                        .accessibilityLabel("Cooldown: \(cooldownLabel)")
                        .accessibilityHint("Days between redemptions. 0 = no cooldown.")
                } header: {
                    Text("Cooldown")
                } footer: {
                    Text("How many days before this reward can be redeemed again. 0 = no limit.")
                }

                // Auto-approve
                Section {
                    Toggle("Enable auto-approve", isOn: $form.enableAutoApprove)
                        .accessibilityLabel("Enable auto-approve for this reward")
                        .onChange(of: form.enableAutoApprove) { _, newValue in
                            if !newValue { form.autoApproveUnder = nil }
                            else { form.autoApproveUnder = form.price }
                        }

                    if form.enableAutoApprove {
                        Stepper(
                            "Auto-approve under \(form.autoApproveUnder ?? 0) pts",
                            value: Binding(
                                get: { form.autoApproveUnder ?? form.price },
                                set: { form.autoApproveUnder = $0 }
                            ),
                            in: 1...2000, step: 5
                        )
                        .accessibilityLabel("Auto-approve threshold: \(form.autoApproveUnder ?? 0) points")
                        .accessibilityHint("Redemptions below this price auto-approve without parent action")
                    }
                } header: {
                    Text("Auto-approve")
                } footer: {
                    Text("Redemption requests below the threshold approve automatically, subject to cooldown.")
                }
            }
            .navigationTitle(editingReward == nil ? "New Reward" : "Edit Reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel without saving")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(form)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                    .accessibilityLabel("Save reward")
                }
            }
            .sheet(isPresented: $showIconPicker) {
                RewardIconPickerView(selectedIcon: $form.icon)
            }
        }
    }

    private var cooldownLabel: String {
        form.cooldownDays == 0 ? "No cooldown" : "Cooldown: \(form.cooldownDays) day\(form.cooldownDays == 1 ? "" : "s")"
    }
}

// MARK: - Reward Icon Picker

private struct RewardIconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss

    let icons = [
        "gift.fill", "star.fill", "moon.stars.fill", "heart.fill",
        "film.fill", "fork.knife", "ipad", "gamecontroller.fill",
        "book.closed.fill", "car.fill", "bicycle", "house.fill",
        "music.note", "paintbrush.fill", "dollarsign.circle.fill", "cart.fill"
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

#Preview("RewardEditorView — new") {
    RewardEditorView(
        family: MockAPIClient.seedFamily,
        editingReward: nil
    ) { _ in }
}

#Preview("RewardEditorView — edit") {
    RewardEditorView(
        family: MockAPIClient.seedFamily,
        editingReward: MockAPIClient.seedRewards.first
    ) { _ in }
}
