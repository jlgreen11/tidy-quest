import SwiftUI

/// Controls which complexity level of UI a kid sees.
/// Tokens are consumed by UI agents (C1–C4); no tier logic lives in UI code.
public enum Tier: Sendable {
    case starter, standard, advanced

    // MARK: - Layout tokens

    public var tileCornerRadius: CGFloat {
        switch self {
        case .starter: 28
        case .standard: 20
        case .advanced: 14
        }
    }

    public var minTapTarget: CGFloat {
        switch self {
        case .starter: 60
        case .standard: 56
        case .advanced: 44
        }
    }

    // MARK: - Typography tokens

    public var headlineFont: Font {
        switch self {
        case .starter: .system(size: 28, weight: .bold, design: .rounded)
        case .standard: .system(size: 22, weight: .semibold, design: .rounded)
        case .advanced: .system(size: 17, weight: .semibold, design: .default)
        }
    }

    public var bodyFont: Font {
        switch self {
        case .starter: .system(size: 20, weight: .medium, design: .rounded)
        case .standard: .system(size: 17, weight: .regular, design: .rounded)
        case .advanced: .system(size: 15, weight: .regular, design: .default)
        }
    }

    public var captionFont: Font {
        switch self {
        case .starter: .system(size: 16, weight: .medium, design: .rounded)
        case .standard: .system(size: 13, weight: .regular, design: .rounded)
        case .advanced: .system(size: 12, weight: .regular, design: .default)
        }
    }

    // MARK: - Icon tokens

    /// Starter tier uses illustrated/emoji-style icons; others use SF Symbols.
    public var useIllustratedIcons: Bool { self == .starter }

    // MARK: - Balance display token

    /// Starter tier shows a jar metaphor instead of a raw number.
    public var showNumericBalance: Bool { self != .starter }

    // MARK: - Motion token

    public var motionDensity: MotionDensity { self == .advanced ? .reduced : .standard }

    // MARK: - Color token

    /// Returns the SwiftUI Color for a given KidColor in this tier's palette.
    /// Tier does not alter the color itself; it gates whether extra flourishes render.
    public func primaryColor(for kidColor: KidColor) -> Color {
        Color(hex: kidColor.hex)
    }
}

// MARK: - MotionDensity

public enum MotionDensity: Sendable {
    /// Normal spring animations and transitions.
    case standard
    /// Minimal motion; respects user preference; appropriate for focused / older kids.
    case reduced
}

// MARK: - Color(hex:) helper

extension Color {
    /// Initialise a Color from a 6-digit hex string (with or without leading `#`).
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let int = UInt64(hex, radix: 16) ?? 0
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
