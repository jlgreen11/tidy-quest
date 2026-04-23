import SwiftUI
import TidyQuestCore

// MARK: - TierTheme environment key

/// Propagates the active kid's Tier through the view hierarchy.
/// Views read `@Environment(\.tierTheme)` instead of receiving Tier as a parameter.
struct TierThemeKey: EnvironmentKey {
    static let defaultValue: Tier = .standard
}

extension EnvironmentValues {
    var tierTheme: Tier {
        get { self[TierThemeKey.self] }
        set { self[TierThemeKey.self] = newValue }
    }
}

extension View {
    /// Injects the kid's Tier (derived from ComplexityTier) into the environment.
    func tierTheme(_ tier: Tier) -> some View {
        environment(\.tierTheme, tier)
    }
}

// MARK: - ComplexityTier → Tier bridge

extension ComplexityTier {
    var tier: Tier {
        switch self {
        case .starter:  .starter
        case .standard: .standard
        case .advanced: .advanced
        }
    }
}
