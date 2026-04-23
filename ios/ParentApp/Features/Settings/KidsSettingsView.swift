import SwiftUI
import TidyQuestCore

/// Settings §2 — Kids roster with per-kid editing.
@available(iOS 17, *)
struct KidsSettingsView: View {

    var familyRepo: FamilyRepository

    var body: some View {
        List {
            if familyRepo.kids.isEmpty {
                ContentUnavailableView(
                    "No kids yet",
                    systemImage: "person.2",
                    description: Text("Add a kid from the Family tab.")
                )
            } else {
                ForEach(familyRepo.kids) { kid in
                    NavigationLink {
                        KidSettingsDetailView(kid: kid, familyRepo: familyRepo)
                    } label: {
                        KidSettingsRow(kid: kid)
                    }
                    .accessibilityLabel("\(kid.displayName), \(kid.complexityTier.rawValue) tier. Tap to edit.")
                }
            }
        }
        .navigationTitle("Kids")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Row

private struct KidSettingsRow: View {
    let kid: AppUser

    private var kidColor: Color {
        Color(hex: kid.color) ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(kidColor)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(kid.displayName.prefix(1)))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(kid.displayName)
                    .font(.body.weight(.medium))
                Text(kid.complexityTier.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Color helper

private extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        self.init(
            red:   Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue:  Double( rgbValue & 0x0000FF) / 255.0
        )
    }
}

// MARK: - Preview

#Preview("KidsSettingsView") {
    let client = MockAPIClient()
    let family = FamilyRepository(apiClient: client)
    family.loadSeedData()
    return NavigationStack {
        KidsSettingsView(familyRepo: family)
    }
}
