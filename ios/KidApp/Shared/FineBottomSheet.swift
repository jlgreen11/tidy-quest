import SwiftUI
import TidyQuestCore

// MARK: - FineBottomSheet

/// In-app bottom sheet that slides up when a fine fires while the kid is active.
/// Triggered by a realtime PointTransaction INSERT where kind == .fine and userId == current kid.
///
/// Design rules per PLAN §4.5:
/// - NO red sheet chrome — only the amount is red.
/// - Neutral scale icon, NOT alarm-bell.
/// - Two actions: "OK" (dismiss) and "Talk to mom" (creates ApprovalRequest).
/// - Reduce Motion: fades instead of slides.
/// - Swipe-down or OK tap to dismiss.
struct FineBottomSheet: View {
    let fine: PointTransaction
    /// Display name of the primary parent (e.g. "Mom", "Dad", "your parents").
    let parentName: String
    @Binding var isPresented: Bool
    let onContest: (PointTransaction) -> Void

    @Environment(\.tierTheme) private var tier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var showContestConfirmation = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 18)
                .accessibilityHidden(true)

            // Content
            VStack(spacing: 20) {
                // Neutral scale icon — gray, NOT red
                Image(systemName: "scalemass")
                    .font(.system(size: tier == .starter ? 52 : 44, weight: .light))
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)

                // Reason text (parent's words)
                VStack(spacing: 6) {
                    Text(parentName)
                        .font(tier.captionFont)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(fine.reason ?? "You received a fine.")
                        .font(tier.headlineFont)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Message from \(parentName): \(fine.reason ?? "You received a fine.")")

                // Amount — only this is red
                Text("\(fine.amount)")
                    .font(.system(size: tier == .starter ? 44 : 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.red)
                    .monospacedDigit()
                    .accessibilityLabel("\(abs(fine.amount)) points removed")

                // Balance indicator (Standard/Advanced)
                if tier != .starter {
                    Text("Points will update in your balance.")
                        .font(tier.captionFont)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)

            // Action buttons
            VStack(spacing: 10) {
                // "Talk to [parent]" — secondary
                Button {
                    onContest(fine)
                    showContestConfirmation = true
                } label: {
                    Text("Talk to \(parentName)")
                        .font(tier.bodyFont)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: tier.minTapTarget)
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Talk to \(parentName) about this fine")

                // "OK" — primary dismiss
                Button {
                    dismiss()
                } label: {
                    Text("OK")
                        .font(tier.bodyFont.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: tier.minTapTarget)
                        .background(
                            Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.12),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .accessibilityLabel("OK, dismiss")
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
        )
        .alert("Sent!", isPresented: $showContestConfirmation) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Sent — \(parentName) will see this.")
        }
    }

    private func dismiss() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - FineBottomSheetModifier

/// Convenience ViewModifier: attach to KidRootView to automatically show FineBottomSheet.
struct FineBottomSheetModifier: ViewModifier {
    @Binding var pendingFine: PointTransaction?
    let parentName: String
    let onContest: (PointTransaction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .sheet(item: $pendingFine) { fine in
                FineBottomSheet(
                    fine: fine,
                    parentName: parentName,
                    isPresented: Binding(
                        get: { pendingFine != nil },
                        set: { if !$0 { pendingFine = nil } }
                    ),
                    onContest: onContest
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.hidden)  // we draw our own
                .presentationCornerRadius(20)
                .transaction { t in
                    // Reduce Motion: replace spring with fade
                    if reduceMotion {
                        t.animation = .easeInOut(duration: 0.3)
                    } else {
                        t.animation = .spring(duration: 0.4)
                    }
                }
            }
    }
}

extension View {
    /// Attaches fine-bottom-sheet presentation to any view.
    func fineBottomSheet(
        fine: Binding<PointTransaction?>,
        parentName: String,
        onContest: @escaping (PointTransaction) -> Void
    ) -> some View {
        modifier(FineBottomSheetModifier(
            pendingFine: fine,
            parentName: parentName,
            onContest: onContest
        ))
    }
}

// MARK: - Preview

#Preview("FineBottomSheet — Standard") {
    @Previewable @State var shown = true
    let fine = PointTransaction(
        id: UUID(),
        userId: MockAPIClient.SeedID.zara,
        familyId: MockAPIClient.SeedID.family,
        amount: -10,
        kind: .fine,
        referenceId: nil,
        reason: "Rude to sibling",
        createdByUserId: MockAPIClient.SeedID.mei,
        idempotencyKey: UUID(),
        choreInstanceId: nil,
        createdAt: Date(),
        reversedByTransactionId: nil
    )
    return ZStack(alignment: .bottom) {
        Color.gray.opacity(0.2).ignoresSafeArea()
        if shown {
            FineBottomSheet(
                fine: fine,
                parentName: "Mom",
                isPresented: $shown,
                onContest: { _ in }
            )
            .tierTheme(.standard)
        }
    }
}

#Preview("FineBottomSheet — Starter") {
    @Previewable @State var shown = true
    let fine = PointTransaction(
        id: UUID(),
        userId: MockAPIClient.SeedID.ava,
        familyId: MockAPIClient.SeedID.family,
        amount: -5,
        kind: .fine,
        referenceId: nil,
        reason: "Didn't follow instruction",
        createdByUserId: MockAPIClient.SeedID.mei,
        idempotencyKey: UUID(),
        choreInstanceId: nil,
        createdAt: Date(),
        reversedByTransactionId: nil
    )
    return ZStack(alignment: .bottom) {
        Color.gray.opacity(0.2).ignoresSafeArea()
        if shown {
            FineBottomSheet(
                fine: fine,
                parentName: "Mom",
                isPresented: $shown,
                onContest: { _ in }
            )
            .tierTheme(.starter)
        }
    }
}
