import SwiftUI
import TidyQuestCore

/// Circular avatar with a colorblind-safe border per kid's assigned color.
/// Always pairs color with the KidColor icon — never color alone.
struct KidAvatar: View {
    let user: AppUser
    var size: CGFloat = 44

    private var kidColor: KidColor? {
        // Strip leading "#" if present
        let raw = user.color.trimmingCharacters(in: .init(charactersIn: "#")).lowercased()
        return KidColor.allCases.first { $0.hex.lowercased() == raw }
    }

    private var borderColor: Color {
        kidColor.map { Color(hex: $0.hex) } ?? .secondary
    }

    private var pairedIcon: String {
        kidColor?.icon ?? "person.fill"
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(borderColor.opacity(0.15))
                .frame(width: size, height: size)

            Image(systemName: pairedIcon)
                .resizable()
                .scaledToFit()
                .padding(size * 0.22)
                .foregroundStyle(borderColor)
        }
        .overlay(
            Circle()
                .strokeBorder(borderColor, lineWidth: size * 0.07)
        )
        .frame(width: size, height: size)
        .accessibilityLabel("\(user.displayName)'s avatar")
        .accessibilityHint("Kid profile icon")
    }
}

#Preview("KidAvatar — light and dark") {
    let mockClient = MockAPIClient()
    let users = MockAPIClient.seedUsers.filter { $0.role == .child }
    return HStack(spacing: 16) {
        ForEach(users) { user in
            VStack(spacing: 4) {
                KidAvatar(user: user, size: 52)
                Text(user.displayName)
                    .font(.caption)
            }
        }
    }
    .padding()
    .previewLayout(.sizeThatFits)
}
