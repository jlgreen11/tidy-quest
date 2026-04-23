import UIKit

// MARK: - HapticFeedback

/// Thin wrapper around UIImpactFeedbackGenerator and UINotificationFeedbackGenerator.
/// All call sites go through this type so haptics are easy to silence in tests
/// and respect AccessibilitySettings at a single point.
@MainActor
enum HapticFeedback {

    // MARK: - Impact

    /// Medium impact — default for successful chore tap (Standard/Starter tier).
    static func medium() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }

    /// Light impact — for subtle confirmations.
    static func light() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    /// Heavy impact — routine completion celebration (Standard tier).
    static func heavy() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
    }

    // MARK: - Notification

    /// Error haptic — double-tap on already-completed tile.
    static func error() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.error)
    }

    /// Success haptic — auto-approved redemption.
    static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    // MARK: - Tier-aware helpers

    /// Fires the appropriate completion haptic for the given tier.
    /// Advanced tier uses a quieter light impact per PLAN §5.4.
    static func choreComplete(tier: TidyQuestCore.Tier) {
        switch tier {
        case .starter, .standard: medium()
        case .advanced:           light()
        }
    }

    /// Fires the routine-complete celebration haptic.
    /// Advanced tier skips the heavy pulse.
    static func routineComplete(tier: TidyQuestCore.Tier) {
        switch tier {
        case .starter, .standard: heavy()
        case .advanced:           medium()
        }
    }
}
