import SwiftUI

/// Inline error banner with retry action.
struct ErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text(message)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Retry")
                    .accessibilityHint("Tap to try loading again")
            }
        }
        .padding(12)
        .background(Color(.systemRed).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.systemRed).opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

#Preview("ErrorBanner") {
    VStack {
        ErrorBanner(message: "Could not load data. Check your connection.") {
            print("retry tapped")
        }
        ErrorBanner(message: "Something went wrong.")
    }
    .padding()
}
