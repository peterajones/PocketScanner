import SwiftUI
import UIKit

/// The app's tint colour. Four vetted presets, not a free picker.
///
/// A `ColorPicker` was considered and rejected: a user can tint everything white, or near
/// enough, and then have no visible control left to undo it with. Every option here is
/// checked for contrast in both light and dark mode, so no choice can leave the app
/// unusable — the same reasoning behind `AppearanceMode` having three fixed cases.
///
/// **Contrast, WCAG ratio against the background it sits on** (AA for UI components and
/// graphical objects is 3.0:1):
///
/// | Tint | light on white | dark on black |
/// |---|---|---|
/// | purple | 8.96 | 4.30 |
/// | blue | 5.77 | 8.00 |
/// | graphite | 8.81 | 9.75 |
/// | green | 5.39 | 9.37 |
///
/// Every value clears the threshold with room to spare. Recompute before adding a fifth —
/// see `docs/brand-color.md` for the method.
enum AccentTint: String, CaseIterable, Identifiable {

    /// Sampled from the app icon. The default, and the app's actual brand colour —
    /// see `docs/brand-color.md`.
    case purple
    case blue
    case graphite
    case green

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .purple:   return String(localized: "Purple", comment: "Accent colour name")
        case .blue:     return String(localized: "Blue", comment: "Colour name: used for both highlight colours and the app accent tint")
        case .graphite: return String(localized: "Graphite", comment: "Accent colour name: a neutral grey")
        case .green:    return String(localized: "Green", comment: "Colour name: used for both highlight colours and the app accent tint")
        }
    }

    /// Light-mode value: deeper and highly saturated, so it holds contrast against white.
    /// A luminous colour on a white background is the unreadable case, which is why these
    /// are darker than their dark-mode counterparts rather than lighter.
    private var lightHex: UInt32 {
        switch self {
        case .purple:   return 0x7505A8
        case .blue:     return 0x0A63C9
        case .graphite: return 0x4A4A4F
        case .green:    return 0x1B7A3D
        }
    }

    /// Dark-mode value: brighter and still high-chroma, which is what reads as luminescent
    /// against black. The light values would sink into a dark background — the brand purple
    /// at 1.5pt is close to invisible there.
    private var darkHex: UInt32 {
        switch self {
        case .purple:   return 0xA046D2
        case .blue:     return 0x4DA3FF
        case .graphite: return 0xB0B0B8
        case .green:    return 0x45C46E
        }
    }

    /// Resolves per-scheme via UIColor's trait handling, so switching light/dark updates the
    /// tint live rather than only on next launch.
    var color: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgb: darkHex)
                : UIColor(rgb: lightHex)
        })
    }

    /// A fixed-scheme swatch for the Settings picker, so each option shows the colour it
    /// will actually produce in the scheme the user is currently in.
    func swatch(for scheme: ColorScheme) -> Color {
        Color(UIColor(rgb: scheme == .dark ? darkHex : lightHex))
    }

    static let storageKey = "accentTint"

    /// Falls back to the brand purple for an empty default or a value from a future version.
    static func resolve(_ rawValue: String) -> AccentTint {
        AccentTint(rawValue: rawValue) ?? .purple
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}
