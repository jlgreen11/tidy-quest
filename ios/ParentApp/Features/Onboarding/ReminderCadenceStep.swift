import SwiftUI
import TidyQuestCore

/// Onboarding Step 8 — Set morning and afternoon reminder times.
@available(iOS 17, *)
struct ReminderCadenceStep: View {

      var draft: CreateFamilyDraft
      let onContinue: () -> Void
    @State private var morningReminder: Date
    @State private var afternoonReminder: Date

    init(draft: CreateFamilyDraft, onContinue: @escaping () -> Void) {
        self.draft = draft
        self.onContinue = onContinue
        _morningReminder = State(initialValue: Self.makeDate(hour: draft.morningReminderHour, minute: draft.morningReminderMinute))
        _afternoonReminder = State(initialValue: Self.makeDate(hour: draft.afternoonReminderHour, minute: draft.afternoonReminderMinute))
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("When should we remind the kids?")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .accessibilityAddTraits(.isHeader)

                Text("Reminders nudge kids when there are incomplete chores. You can change this anytime in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }

            Spacer()

            VStack(spacing: 16) {
                Form {
                    Section("Morning Reminder") {
                        DatePicker(
                            "Morning reminder",
                            selection: $morningReminder,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: morningReminder) { _, new in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: new)
                            draft.morningReminderHour = comps.hour ?? 7
                            draft.morningReminderMinute = comps.minute ?? 0
                        }
                        .accessibilityLabel("Morning reminder time, currently \(morningReminder, style: .time)")
                    }

                    Section("Afternoon Reminder") {
                        DatePicker(
                            "Afternoon reminder",
                            selection: $afternoonReminder,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: afternoonReminder) { _, new in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: new)
                            draft.afternoonReminderHour = comps.hour ?? 15
                            draft.afternoonReminderMinute = comps.minute ?? 30
                        }
                        .accessibilityLabel("Afternoon reminder time, currently \(afternoonReminder, style: .time)")
                    }
                }
                .frame(maxHeight: 200)
                .scrollDisabled(true)

                Button(action: onContinue) {
                    Text("Set reminders")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .accessibilityLabel("Set reminders and continue")

                Button("Skip reminders", action: onContinue)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Skip setting reminders for now")
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("ReminderCadenceStep") {
    ReminderCadenceStep(draft: CreateFamilyDraft(), onContinue: { })
}
