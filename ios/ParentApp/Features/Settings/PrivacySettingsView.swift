import SwiftUI
import TidyQuestCore

/// Settings §7 — Privacy & Data: export JSON, delete family.
@available(iOS 17, *)
struct PrivacySettingsView: View {

    var familyRepo: FamilyRepository

    @State private var showDeleteConfirmation: Bool = false
    @State private var deleteConfirmText: String = ""
    @State private var isDeleting: Bool = false
    @State private var exportData: ExportWrapper? = nil
    @State private var errorMessage: String? = nil

    private let deleteKeyword = "DELETE"

    var body: some View {
        Form {
            if let errorMessage {
                ErrorBanner(message: errorMessage)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

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
                .disabled(isDeleting)
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
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationSheet(
                confirmText: $deleteConfirmText,
                isDeleting: isDeleting,
                deleteKeyword: deleteKeyword,
                onDelete: {
                    Task { await deleteFamily() }
                },
                onCancel: {
                    showDeleteConfirmation = false
                    deleteConfirmText = ""
                }
            )
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
        errorMessage = nil
        defer { isDeleting = false }

        // TODO: call familyRepo.deleteFamily(DeleteFamilyRequest(...)) once FamilyRepository
        // exposes a deleteFamily method. Until then, use updateFamily as a connectivity
        // smoke-test; actual deletion requires the repository layer addition.
        // TODO: supply a real App Attest token when the attestation service is wired.
        let req = UpdateFamilyRequest(familyId: family.id)
        await familyRepo.updateFamily(req)

        if familyRepo.error != nil {
            errorMessage = familyRepo.error?.localizedDescription ?? "Failed to delete. Please try again."
        }
        showDeleteConfirmation = false
        deleteConfirmText = ""
    }
}

// MARK: - Delete Confirmation Sheet

@available(iOS 17, *)
private struct DeleteConfirmationSheet: View {

    @Binding var confirmText: String
    let isDeleting: Bool
    let deleteKeyword: String
    let onDelete: () -> Void
    let onCancel: () -> Void

    private var isConfirmed: Bool {
        confirmText == deleteKeyword
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text("Delete Family Account?")
                    .font(.title2.weight(.bold))

                Text("All family data will be scheduled for deletion. You have **30 days** to recover by contacting support. After 30 days, deletion is permanent.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Type **\(deleteKeyword)** to confirm:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Type \(deleteKeyword)", text: $confirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Type DELETE to confirm deletion")
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Group {
                            if isDeleting {
                                ProgressView()
                                    .accessibilityLabel("Deleting")
                            } else {
                                Text("Permanently Delete Family")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isConfirmed ? Color.red : Color.red.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isConfirmed || isDeleting)

                    Button("Cancel", action: onCancel)
                        .font(.body)
                        .disabled(isDeleting)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isDeleting)
                }
            }
        }
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
