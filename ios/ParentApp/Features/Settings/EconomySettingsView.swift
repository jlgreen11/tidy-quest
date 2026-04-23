import SwiftUI
import TidyQuestCore

/// Settings §6 — Economy: weekly band target, deduction caps.
/// Maps to family.weekly_band_target, family.daily_deduction_cap, family.weekly_deduction_cap.
@available(iOS 17, *)
struct EconomySettingsView: View {

    var familyRepo: FamilyRepository

    @State private var bandLow: Double = 250
    @State private var bandHigh: Double = 500
    @State private var dailyCap: Double = 50
    @State private var weeklyCap: Double = 150
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    // Snapshots for rollback
    @State private var savedBandLow: Double = 250
    @State private var savedBandHigh: Double = 500
    @State private var savedDailyCap: Double = 50
    @State private var savedWeeklyCap: Double = 150

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
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Target range")
                        Spacer()
                        Text("\(Int(bandLow)) – \(Int(bandHigh)) pts/wk")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Text("Lower bound")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $bandLow, in: 0...500, step: 25) {
                        Text("Weekly band lower bound")
                    } minimumValueLabel: {
                        Text("0").font(.caption)
                    } maximumValueLabel: {
                        Text("500").font(.caption)
                    }
                    .onChange(of: bandLow) { _, new in
                        if new >= bandHigh { bandHigh = new + 25 }
                    }
                    .accessibilityLabel("Weekly earnings band lower bound: \(Int(bandLow)) points")
                    .accessibilityValue("\(Int(bandLow)) points")
                    .disabled(isSaving)

                    Text("Upper bound")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $bandHigh, in: 25...1000, step: 25) {
                        Text("Weekly band upper bound")
                    } minimumValueLabel: {
                        Text("25").font(.caption)
                    } maximumValueLabel: {
                        Text("1,000").font(.caption)
                    }
                    .onChange(of: bandHigh) { _, new in
                        if new <= bandLow { bandLow = max(0, new - 25) }
                    }
                    .accessibilityLabel("Weekly earnings band upper bound: \(Int(bandHigh)) points")
                    .accessibilityValue("\(Int(bandHigh)) points")
                    .disabled(isSaving)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Weekly Earnings Band")
            } footer: {
                Text("The Economy tab alerts you when any kid's expected weekly earnings drift outside this range by more than 20%.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Daily deduction cap")
                        Spacer()
                        Text("\(Int(dailyCap)) pts/day")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $dailyCap, in: 0...200, step: 10) {
                        Text("Daily deduction cap")
                    } minimumValueLabel: {
                        Text("0").font(.caption)
                    } maximumValueLabel: {
                        Text("200").font(.caption)
                    }
                    .accessibilityLabel("Daily deduction cap: \(Int(dailyCap)) points per day")
                    .accessibilityValue("\(Int(dailyCap))")
                    .disabled(isSaving)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weekly deduction cap")
                        Spacer()
                        Text("\(Int(weeklyCap)) pts/wk")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $weeklyCap, in: 0...500, step: 25) {
                        Text("Weekly deduction cap")
                    } minimumValueLabel: {
                        Text("0").font(.caption)
                    } maximumValueLabel: {
                        Text("500").font(.caption)
                    }
                    .accessibilityLabel("Weekly deduction cap: \(Int(weeklyCap)) points per week")
                    .accessibilityValue("\(Int(weeklyCap))")
                    .disabled(isSaving)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Deduction Caps")
            } footer: {
                Text("Regardless of fines issued, deductions are capped per day and per week. This protects kids from runaway penalties.")
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
                            Text("Save Economy Settings")
                                .font(.body.weight(.semibold))
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
                .accessibilityLabel("Save economy settings")
            }
        }
        .navigationTitle("Economy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromRepo() }
    }

    // MARK: - Helpers

    private func loadFromRepo() {
        guard let family = familyRepo.family else { return }
        dailyCap = Double(family.dailyDeductionCap)
        savedDailyCap = dailyCap
        weeklyCap = Double(family.weeklyDeductionCap)
        savedWeeklyCap = weeklyCap
        if let bandStr = family.weeklyBandTarget {
            let stripped = bandStr.trimmingCharacters(in: CharacterSet(charactersIn: "[(])"))
            let parts = stripped.split(separator: ",")
            if parts.count == 2,
               let lo = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let hi = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                bandLow = lo
                savedBandLow = lo
                bandHigh = hi
                savedBandHigh = hi
            }
        }
    }

    private func saveChanges() async {
        guard let family = familyRepo.family else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let bandTarget = "[\(Int(bandLow)),\(Int(bandHigh)))"
        let req = UpdateFamilyRequest(
            familyId: family.id,
            weeklyBandTarget: bandTarget,
            dailyDeductionCap: Int(dailyCap),
            weeklyDeductionCap: Int(weeklyCap)
        )
        await familyRepo.updateFamily(req)

        if familyRepo.error != nil {
            // Roll back UI to last saved values
            bandLow = savedBandLow
            bandHigh = savedBandHigh
            dailyCap = savedDailyCap
            weeklyCap = savedWeeklyCap
            errorMessage = familyRepo.error?.localizedDescription ?? "Failed to save. Please try again."
        } else {
            // Commit snapshots
            savedBandLow = bandLow
            savedBandHigh = bandHigh
            savedDailyCap = dailyCap
            savedWeeklyCap = weeklyCap
        }
    }
}

// MARK: - Preview

#Preview("EconomySettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    return NavigationStack {
        EconomySettingsView(familyRepo: family)
    }
}
