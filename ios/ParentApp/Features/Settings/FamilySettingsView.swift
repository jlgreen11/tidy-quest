import SwiftUI
import TidyQuestCore

/// Settings §1 — Family: name, timezone, daily reset time, quiet hours, toggles.
@available(iOS 17, *)
struct FamilySettingsView: View {

    var familyRepo: FamilyRepository

    @State private var familyName: String = ""
    @State private var timezone: String = "America/Los_Angeles"
    @State private var dailyResetTime: Date = Calendar.current.date(bySettingHour: 4, minute: 0, second: 0, of: Date())!
    @State private var quietHoursStart: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!
    @State private var quietHoursEnd: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
    @State private var leaderboardEnabled: Bool = false
    @State private var siblingLedgerVisible: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    // Snapshots for rollback on failure
    @State private var savedFamilyName: String = ""
    @State private var savedTimezone: String = "America/Los_Angeles"
    @State private var savedLeaderboardEnabled: Bool = false
    @State private var savedSiblingLedgerVisible: Bool = false

    private static let timezones: [String] = TimeZone.knownTimeZoneIdentifiers.sorted()

    var body: some View {
        Form {
            if let errorMessage {
                ErrorBanner(message: errorMessage) {
                    Task { await saveChanges() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Identity") {
                HStack {
                    Text("Family name")
                    Spacer()
                    TextField("Name", text: $familyName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Family name")
                        .disabled(isSaving)
                }

                Picker("Timezone", selection: $timezone) {
                    ForEach(Self.timezones, id: \.self) { tz in
                        Text(tz).tag(tz)
                    }
                }
                .accessibilityLabel("Timezone picker")
                .disabled(isSaving)
            }

            Section("Daily Schedule") {
                DatePicker(
                    "Daily reset time",
                    selection: $dailyResetTime,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Daily reset time picker")
                .disabled(isSaving)

                DatePicker(
                    "Quiet hours start",
                    selection: $quietHoursStart,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Quiet hours start time")
                .disabled(isSaving)

                DatePicker(
                    "Quiet hours end",
                    selection: $quietHoursEnd,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Quiet hours end time")
                .disabled(isSaving)
            }

            Section("Visibility") {
                Toggle("Leaderboard", isOn: $leaderboardEnabled)
                    .accessibilityLabel("Leaderboard enabled")
                    .accessibilityHint("Shows a ranking of kids by points earned.")
                    .disabled(isSaving)

                Toggle("Siblings see each other's ledger", isOn: $siblingLedgerVisible)
                    .accessibilityLabel("Sibling ledger visible")
                    .accessibilityHint("Kids can see each other's point totals and transactions.")
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
                                .accessibilityLabel("Saving")
                        } else {
                            Text("Save Changes")
                                .font(.body.weight(.semibold))
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
                .accessibilityLabel("Save family settings")
            }
        }
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromRepo() }
    }

    // MARK: - Helpers

    private func loadFromRepo() {
        guard let family = familyRepo.family else { return }
        familyName = family.name
        savedFamilyName = family.name
        timezone = family.timezone
        savedTimezone = family.timezone
        leaderboardEnabled = family.leaderboardEnabled
        savedLeaderboardEnabled = family.leaderboardEnabled
        siblingLedgerVisible = family.siblingLedgerVisible
        savedSiblingLedgerVisible = family.siblingLedgerVisible
        dailyResetTime = parseTime(family.dailyResetTime) ?? dailyResetTime
        quietHoursStart = parseTime(family.quietHoursStart) ?? quietHoursStart
        quietHoursEnd = parseTime(family.quietHoursEnd) ?? quietHoursEnd
    }

    private func saveChanges() async {
        guard let family = familyRepo.family else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let req = UpdateFamilyRequest(
            familyId: family.id,
            name: familyName,
            timezone: timezone,
            leaderboardEnabled: leaderboardEnabled,
            siblingLedgerVisible: siblingLedgerVisible
            // TODO: wire dailyResetTime, quietHoursStart, quietHoursEnd when
            // UpdateFamilyRequest gains those fields (currently not in the request model).
        )
        await familyRepo.updateFamily(req)

        if familyRepo.error != nil {
            // Roll back UI to last saved values
            familyName = savedFamilyName
            timezone = savedTimezone
            leaderboardEnabled = savedLeaderboardEnabled
            siblingLedgerVisible = savedSiblingLedgerVisible
            errorMessage = familyRepo.error?.localizedDescription ?? "Failed to save. Please try again."
        } else {
            // Commit snapshot
            savedFamilyName = familyName
            savedTimezone = timezone
            savedLeaderboardEnabled = leaderboardEnabled
            savedSiblingLedgerVisible = siblingLedgerVisible
        }
    }

    private func parseTime(_ str: String) -> Date? {
        let parts = str.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())
    }
}

// MARK: - Preview

#Preview("FamilySettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    return NavigationStack {
        FamilySettingsView(familyRepo: family)
    }
}
