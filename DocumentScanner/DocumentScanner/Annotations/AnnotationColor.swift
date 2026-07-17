import UIKit

/// The fixed highlight palette. Translucent so the scanned page shows through.
enum AnnotationColor: String, CaseIterable {
    case yellow
    case green
    case pink
    case blue

    var uiColor: UIColor {
        switch self {
        case .yellow: return UIColor.systemYellow.withAlphaComponent(0.4)
        case .green:  return UIColor.systemGreen.withAlphaComponent(0.4)
        case .pink:   return UIColor.systemPink.withAlphaComponent(0.4)
        case .blue:   return UIColor.systemBlue.withAlphaComponent(0.4)
        }
    }

    var displayName: String {
        switch self {
        case .yellow: return String(localized: "Yellow", comment: "Highlight color name")
        case .green:  return String(localized: "Green", comment: "Highlight color name")
        case .pink:   return String(localized: "Pink", comment: "Highlight color name")
        case .blue:   return String(localized: "Blue", comment: "Highlight color name")
        }
    }
}
