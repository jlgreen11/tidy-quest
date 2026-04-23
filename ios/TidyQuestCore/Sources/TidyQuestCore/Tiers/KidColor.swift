/// Colorblind-safe palette for kid avatars.
/// Colors are always paired with an icon — never used alone.
public enum KidColor: String, CaseIterable, Sendable {
    case coral
    case sunflower
    case sage
    case sky
    case lavender
    case rose
    case olive
    case slate

    /// 6-digit hex value (no leading `#`).
    public var hex: String {
        switch self {
        case .coral:     "FF6B6B"
        case .sunflower: "FFD93D"
        case .sage:      "6BCB77"
        case .sky:       "4D96FF"
        case .lavender:  "B983FF"
        case .rose:      "FF8FB1"
        case .olive:     "8BA888"
        case .slate:     "6C757D"
        }
    }

    /// SF Symbol name paired with this color.
    public var icon: String {
        switch self {
        case .coral:     "star.fill"
        case .sunflower: "sun.max.fill"
        case .sage:      "leaf.fill"
        case .sky:       "cloud.fill"
        case .lavender:  "moon.stars.fill"
        case .rose:      "heart.fill"
        case .olive:     "tree.fill"
        case .slate:     "circle.grid.3x3.fill"
        }
    }
}
