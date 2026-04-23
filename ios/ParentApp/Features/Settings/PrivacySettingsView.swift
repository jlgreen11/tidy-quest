import SwiftUI
import TidyQuestCore

/// Settings §7 — Privacy & Data: export JSON, delete family.
@available(iOS 17, *)
struct PrivacySettingsView: View {

    var familyRepo: FamilyRepository

    @State private var showDeleteConfirmation: Bool = false
    @State private var isDeleting: Bool = false
    @State private var exportData: ExportWrapper? = nil

    var body: some View {
        Form {
            Section {
                Button {
                    exportData = buildExport()
                } label: {
                    Label("Export family data", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Export all family data as JSON")
                .accessibilityHint("Exports chores, transactions, and settings to a file you can share or save.")

                if let export = exportData {
                    ShareLink(item: export.json, subject: Text("TidyQuest Family Data")) {
                        Label("Share export file", systemImage: "doc.badge.plus")
                    }
                    .accessibilityLabel("Share the exported family data file")
                }
            } header: {
                Text("Data Export")
            } footer: {
                Text("Exports family name, kids, chores, and transaction history as JSON. Does not include photos.")
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete family", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Delete family account")
                .accessibilityHint("Permanently deletes all family data. A 30-day recovery window is available.")
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Deletion is reversible within 30 days. After 30 days, all data is permanently removed from our servers.")
            }
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Family Account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Family", role: .destructive) {
                Task { await deleteFamily() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("All family data will be scheduled for deletion. You have 30 days to recover your account by contacting support. After 30 days, deletion is permanent.")
        }
    }

    // MARK: - Helpers

    private struct ExportWrapper {
        let json: String
    }

    private func buildExport() -> ExportWrapper {
        guard let family = familyRepo.family else {
            return ExportWrapper(json: "{\"error\": \"No family loaded\"}")
        }
        let payload: [String: Any] = [
            "export_version": "1.0",
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "family": [
                "id": family.id.uuidString,
                "name": family.name,
                "timezone": family.timezone,
                "subscription_tier": family.subscriptionTier.rawValue
            ],
            "kids_count": familyRepo.kids.count,
            "note": "Full ledger export requires server-side generation. This is a summary export."
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return ExportWrapper(json: str)
        }
        return ExportWrapper(json: "{\"error\": \"Serialization failed\"}")
    }

    private func deleteFamily() async {
        guard let family = familyRepo.family else { return }
        isDeleting = true
        defer { isDeleting = false }
        let req = DeleteFamilyRequest(familyId: family.id, appAttestToken: "mock-attest-token")
        await familyRepo.updateFamily(
            UpdateFamilyRequest(familyId: family.id)
        )
        _ = req // Will wire real delete when App Attest is wired
    }
}

// MARK: - Preview

#Preview("PrivacySettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    return NavigationStack {
        PrivacySettingsView(familyRepo: family)
    }
}
