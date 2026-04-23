import SwiftUI
import TidyQuestCore

/// Onboarding Step 8 — Set morning and afternoon reminder times.
@available(iOS 17, *)
struct ReminderCadenceStep: View {

      var draft: CreateFamilyDraft
      var familyRepo: FamilyRepository
      let onContinue: () -> Void

    @State private var morningReminder: Date
    @State private var afternoonReminder: Date
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showAlert: Bool = false

    init(draft: CreateFamilyDraft, familyRepo: FamilyRepository, onContinue: @escaping () -> Void) {
        self.draft = draft
        self.familyRepo = familyRepo
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

                Button {
                    Task { await saveRemindersAndContinue() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Set reminders")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
                .padding(.horizontal, 24)
                .accessibilityLabel("Set reminders and continue")

                Button("Skip reminders", action: onContinue)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .disabled(isSaving)
                    .accessibilityLabel("Skip setting reminders for now")
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Could Not Save Reminders", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred.")
        }
    }

    // MARK: - Helpers

    private func saveRemindersAndContinue() async {
        guard let familyId = draft.createdFamily?.id else {
            // No family yet — proceed without saving
            onContinue()
            return
        }

        isSaving = true
        defer { isSaving = false }

        // Persist the reminder times into the family.settings jsonb column.
        // The backend merges these keys with any existing settings.
        let morning = "\(String(format: "%02d", draft.morningReminderHour)):\(String(format: "%02d", draft.morningReminderMinute))"
        let afternoon = "\(String(format: "%02d", draft.afternoonReminderHour)):\(String(format: "%02d", draft.afternoonReminderMinute))"
        let req = UpdateFamilyRequest(
            familyId: familyId,
            settings: [
                "morning_reminder": AnyCodable(morning),
                "afternoon_reminder": AnyCodable(afternoon)
            ]
        )
        await familyRepo.updateFamily(req)

        if let err = familyRepo.error {
            errorMessage = err.localizedDescription
            showAlert = true
            return
        }

        onContinue()
    }
}

// MARK: - Preview

#Preview("ReminderCadenceStep") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    return ReminderCadenceStep(draft: CreateFamilyDraft(), familyRepo: family, onContinue: { })
}
