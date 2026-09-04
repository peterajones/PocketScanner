import SwiftUI

/// Whether the app follows the system light/dark setting or overrides it.
///
/// Preset-style, like `ImageFilter` and `PaperSize`. Three fixed options with no invalid
/// states — which is the difference between this and the free colour picker that was
/// rejected: a user cannot put the app into a condition they have no visible control to
/// escape from.
///
/// This is an *appearance* setting, not a scanning one. It changes how the app looks, never
/// what it does to a document — see the revised scope principle: presets-not-sliders governs
/// document manipulation, not personalisation.
enum AppearanceMode: String, CaseIterable, Identifiable {

    /// Follow iOS. The shipped default: an app that ignores the system setting without being
    /// asked is the thing users complain about.
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "System", comment: "Appearance setting: follow the iOS light/dark setting")
        case .light:  return String(localized: "Light", comment: "Appearance setting: always light mode")
        case .dark:   return String(localized: "Dark", comment: "Appearance setting: always dark mode")
        }
    }

    /// What to hand SwiftUI's `.preferredColorScheme`. `nil` means "don't override", which is
    /// how the system case defers to iOS rather than guessing at the current setting.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// Storage key, shared by the Settings picker and the root view so the two cannot drift.
    static let storageKey = "appearanceMode"

    /// Resolves a stored raw value, falling back to `.system` for anything unrecognised —
    /// an empty default, or a value written by a future version.
    static func resolve(_ rawValue: String) -> AppearanceMode {
        AppearanceMode(rawValue: rawValue) ?? .system
    }
}
