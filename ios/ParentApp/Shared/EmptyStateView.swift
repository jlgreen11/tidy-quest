import SwiftUI

/// Reusable empty-state view: icon + title + message.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(label)
                .accessibilityHint("Tap to \(label.lowercased())")
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview("EmptyStateView") {
    EmptyStateView(
        systemImage: "checkmark.circle",
        title: "All caught up",
        message: "No pending approvals right now. Check back when the kids have been busy.",
        action: {},
        actionLabel: "Refresh"
    )
}
