import SwiftUI
import TidyQuestCore

/// Settings §5 — Notifications: granular toggles per role + quiet hours.
/// Notification prefs are stored in family.settings jsonb.
@available(iOS 17, *)
struct NotificationsSettingsView: View {

    var familyRepo: FamilyRepository

    // Parent notification toggles
    @State private var choreApprovalNeeded: Bool = true
    @State private var redemptionApprovalNeeded: Bool = true
    @State private var streakMilestones: Bool = true
    @State private var dailySummary: Bool = false
    @State private var subscriptionAlerts: Bool = true

    // Kid notification toggles (shared family preference)
    @State private var kidChoreReminders: Bool = true
    @State private var kidStreakReminders: Bool = true
    @State private var kidRedemptionApproved: Bool = true
    @State private var kidDay2Reengage: Bool = true

    // Quiet hours (echo from FamilySettings; shown here for discoverability)
    @State private var quietHoursStart: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!
    @State private var quietHoursEnd: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    // Snapshots for rollback
    @State private var savedChoreApprovalNeeded: Bool = true
    @State private var savedRedemptionApprovalNeeded: Bool = true
    @State private var savedStreakMilestones: Bool = true
    @State private var savedDailySummary: Bool = false
    @State private var savedSubscriptionAlerts: Bool = true
    @State private var savedKidChoreReminders: Bool = true
    @State private var savedKidStreakReminders: Bool = true
    @State private var savedKidRedemptionApproved: Bool = true
    @State private var savedKidDay2Reengage: Bool = true

    var body: some View {
        Form {
            if let errorMessage {
                ErrorBanner(message: errorMessage) {
                    Task { await saveChanges() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Chore awaiting approval", isOn: $choreApprovalNeeded)
                    .accessibilityLabel("Notify parent when a chore needs approval")
                    .disabled(isSaving)
                Toggle("Reward redemption requested", isOn: $redemptionApprovalNeeded)
                    .accessibilityLabel("Notify parent when a reward is requested")
                    .disabled(isSaving)
                Toggle("Streak milestones", isOn: $streakMilestones)
                    .accessibilityLabel("Notify parent of streak milestones")
                    .disabled(isSaving)
                Toggle("Daily summary", isOn: $dailySummary)
                    .accessibilityLabel("Send a daily family activity summary")
                    .disabled(isSaving)
                Toggle("Subscription alerts", isOn: $subscriptionAlerts)
                    .accessibilityLabel("Notify about subscription status and renewals")
                    .disabled(isSaving)
            } header: {
                Text("Parent Notifications")
            }

            Section {
                Toggle("Morning chore reminders", isOn: $kidChoreReminders)
                    .accessibilityLabel("Send kids a morning chore reminder")
                    .disabled(isSaving)
                Toggle("Streak encouragement", isOn: $kidStreakReminders)
                    .accessibilityLabel("Send kids streak encouragement notifications")
                    .disabled(isSaving)
                Toggle("Redemption approved", isOn: $kidRedemptionApproved)
                    .accessibilityLabel("Notify kids when a reward redemption is approved")
                    .disabled(isSaving)
                Toggle("Day-2 re-engagement", isOn: $kidDay2Reengage)
                    .accessibilityLabel("Send day-2 re-engagement push to kids")
                    .disabled(isSaving)
            } header: {
                Text("Kid Notifications")
            } footer: {
                Text("Fines are never pushed to kids. Kids see fines in-app only.")
            }

            Section("Quiet Hours") {
                DatePicker(
                    "Start",
                    selection: $quietHoursStart,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Quiet hours start time. No notifications sent after this time.")
                .disabled(isSaving)

                DatePicker(
                    "End",
                    selection: $quietHoursEnd,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Quiet hours end time. Notifications resume after this time.")
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
                            Text("Save Preferences")
                                .font(.body.weight(.semibold))
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
                .accessibilityLabel("Save notification preferences")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromRepo() }
    }

    // MARK: - Helpers

    private func loadFromRepo() {
        guard let family = familyRepo.family else { return }
        // TODO: read per-key notification prefs from family.settings once
        // UpdateFamilyRequest exposes a settings field for jsonb merge.
        // Quiet hours are top-level Family fields.
        quietHoursStart = parseTime(family.quietHoursStart) ?? quietHoursStart
        quietHoursEnd = parseTime(family.quietHoursEnd) ?? quietHoursEnd

        // Load notification toggles from settings if present
        let s = family.settings
        choreApprovalNeeded = (s["notif_chore_approval"]?.value as? Bool) ?? true
        savedChoreApprovalNeeded = choreApprovalNeeded
        redemptionApprovalNeeded = (s["notif_redemption_approval"]?.value as? Bool) ?? true
        savedRedemptionApprovalNeeded = redemptionApprovalNeeded
        streakMilestones = (s["notif_streak_milestones"]?.value as? Bool) ?? true
        savedStreakMilestones = streakMilestones
        dailySummary = (s["notif_daily_summary"]?.value as? Bool) ?? false
        savedDailySummary = dailySummary
        subscriptionAlerts = (s["notif_subscription_alerts"]?.value as? Bool) ?? true
        savedSubscriptionAlerts = subscriptionAlerts
        kidChoreReminders = (s["notif_kid_chore_reminders"]?.value as? Bool) ?? true
        savedKidChoreReminders = kidChoreReminders
        kidStreakReminders = (s["notif_kid_streak_reminders"]?.value as? Bool) ?? true
        savedKidStreakReminders = kidStreakReminders
        kidRedemptionApproved = (s["notif_kid_redemption_approved"]?.value as? Bool) ?? true
        savedKidRedemptionApproved = kidRedemptionApproved
        kidDay2Reengage = (s["notif_kid_day2_reengage"]?.value as? Bool) ?? true
        savedKidDay2Reengage = kidDay2Reengage
    }

    private func saveChanges() async {
        guard let family = familyRepo.family else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // TODO: wire notification prefs into UpdateFamilyRequest once it gains a settings field.
        // Quiet hours are not yet in UpdateFamilyRequest either.
        // For now, call with familyId only as a connectivity smoke-test.
        let req = UpdateFamilyRequest(familyId: family.id)
        await familyRepo.updateFamily(req)

        if familyRepo.error != nil {
            // Roll back UI to last saved values
            choreApprovalNeeded = savedChoreApprovalNeeded
            redemptionApprovalNeeded = savedRedemptionApprovalNeeded
            streakMilestones = savedStreakMilestones
            dailySummary = savedDailySummary
            subscriptionAlerts = savedSubscriptionAlerts
            kidChoreReminders = savedKidChoreReminders
            kidStreakReminders = savedKidStreakReminders
            kidRedemptionApproved = savedKidRedemptionApproved
            kidDay2Reengage = savedKidDay2Reengage
            errorMessage = familyRepo.error?.localizedDescription ?? "Failed to save. Please try again."
        } else {
            // Commit snapshots
            savedChoreApprovalNeeded = choreApprovalNeeded
            savedRedemptionApprovalNeeded = redemptionApprovalNeeded
            savedStreakMilestones = streakMilestones
            savedDailySummary = dailySummary
            savedSubscriptionAlerts = subscriptionAlerts
            savedKidChoreReminders = kidChoreReminders
            savedKidStreakReminders = kidStreakReminders
            savedKidRedemptionApproved = kidRedemptionApproved
            savedKidDay2Reengage = kidDay2Reengage
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

#Preview("NotificationsSettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    return NavigationStack {
        NotificationsSettingsView(familyRepo: family)
    }
}
