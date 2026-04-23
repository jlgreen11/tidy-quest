import SwiftUI
import TidyQuestCore

/// Settings §5 — Notifications: granular toggles per role + quiet hours.
@available(iOS 17, *)
struct NotificationsSettingsView: View {

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

    var body: some View {
        Form {
            Section {
                Toggle("Chore awaiting approval", isOn: $choreApprovalNeeded)
                    .accessibilityLabel("Notify parent when a chore needs approval")
                Toggle("Reward redemption requested", isOn: $redemptionApprovalNeeded)
                    .accessibilityLabel("Notify parent when a reward is requested")
                Toggle("Streak milestones", isOn: $streakMilestones)
                    .accessibilityLabel("Notify parent of streak milestones")
                Toggle("Daily summary", isOn: $dailySummary)
                    .accessibilityLabel("Send a daily family activity summary")
                Toggle("Subscription alerts", isOn: $subscriptionAlerts)
                    .accessibilityLabel("Notify about subscription status and renewals")
            } header: {
                Text("Parent Notifications")
            }

            Section {
                Toggle("Morning chore reminders", isOn: $kidChoreReminders)
                    .accessibilityLabel("Send kids a morning chore reminder")
                Toggle("Streak encouragement", isOn: $kidStreakReminders)
                    .accessibilityLabel("Send kids streak encouragement notifications")
                Toggle("Redemption approved", isOn: $kidRedemptionApproved)
                    .accessibilityLabel("Notify kids when a reward redemption is approved")
                Toggle("Day-2 re-engagement", isOn: $kidDay2Reengage)
                    .accessibilityLabel("Send day-2 re-engagement push to kids")
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

                DatePicker(
                    "End",
                    selection: $quietHoursEnd,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Quiet hours end time. Notifications resume after this time.")
            }

            Section {
                Button {
                    // Persist to UNUserNotificationCenter + family settings (stub in v0.1)
                } label: {
                    HStack {
                        Spacer()
                        Text("Save Preferences")
                            .font(.body.weight(.semibold))
                        Spacer()
                    }
                }
                .accessibilityLabel("Save notification preferences")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("NotificationsSettingsView") {
    NavigationStack {
        NotificationsSettingsView()
    }
}
