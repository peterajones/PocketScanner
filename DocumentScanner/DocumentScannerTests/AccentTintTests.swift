import XCTest
import SwiftUI
@testable import DocumentScanner

final class AccentTintTests: XCTestCase {

    // MARK: - Storage

    func test_fourOptions() {
        XCTAssertEqual(AccentTint.allCases.count, 4)
    }

    func test_allCasesRoundTripThroughRawValue() {
        for tint in AccentTint.allCases {
            XCTAssertEqual(AccentTint(rawValue: tint.rawValue), tint)
        }
    }

    /// The default is the brand purple sampled from the app icon, so an upgrading user sees
    /// no change unless they choose one.
    func test_emptyStorageResolvesToBrandPurple() {
        XCTAssertEqual(AccentTint.resolve(""), .purple)
    }

    func test_unknownValueResolvesToBrandPurple() {
        XCTAssertEqual(AccentTint.resolve("chartreuse"), .purple)
    }

    func test_storageKeyIsStable() {
        // Changing this silently resets everyone's choice on upgrade.
        XCTAssertEqual(AccentTint.storageKey, "accentTint")
    }

    func test_displayNamesAreNonEmptyAndDistinct() {
        let names = AccentTint.allCases.map(\.displayName)
        XCTAssertFalse(names.contains(where: \.isEmpty))
        XCTAssertEqual(Set(names).count, names.count)
    }

    // MARK: - Contrast

    /// WCAG relative luminance.
    private func luminance(_ color: Color, scheme: ColorScheme) -> CGFloat {
        let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        func f(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
    }

    private func contrast(_ color: Color, against background: CGFloat, scheme: ColorScheme) -> CGFloat {
        let l = luminance(color, scheme: scheme)
        let hi = max(l, background), lo = min(l, background)
        return (hi + 0.05) / (lo + 0.05)
    }

    /// The guarantee that makes presets safe where a free picker was not: no option can
    /// render the crop handles or buttons invisible. WCAG AA for UI components and
    /// graphical objects is 3.0:1.
    func test_everyTintIsLegibleInLightMode() {
        for tint in AccentTint.allCases {
            let ratio = contrast(tint.color, against: 1.0, scheme: .light)   // white
            XCTAssertGreaterThanOrEqual(ratio, 3.0,
                "\(tint.displayName) is \(String(format: "%.2f", ratio)):1 on white — below the 3:1 minimum")
        }
    }

    func test_everyTintIsLegibleInDarkMode() {
        for tint in AccentTint.allCases {
            let ratio = contrast(tint.color, against: 0.0, scheme: .dark)    // black
            XCTAssertGreaterThanOrEqual(ratio, 3.0,
                "\(tint.displayName) is \(String(format: "%.2f", ratio)):1 on black — below the 3:1 minimum")
        }
    }

    // MARK: - Per-scheme behaviour

    /// A single fixed colour cannot be legible on both white and black. Each tint must
    /// actually resolve differently per scheme rather than being one value.
    func test_everyTintDiffersBetweenLightAndDark() {
        for tint in AccentTint.allCases {
            let light = UIColor(tint.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            let dark = UIColor(tint.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            XCTAssertNotEqual(light, dark, "\(tint.displayName) is the same colour in both schemes")
        }
    }

    /// Dark-mode variants are brighter — that is what reads as luminescent against black,
    /// and it is the opposite of what a naive "darken for dark mode" would produce.
    func test_darkVariantsAreBrighterThanLightVariants() {
        for tint in AccentTint.allCases {
            let light = luminance(tint.color, scheme: .light)
            let dark = luminance(tint.color, scheme: .dark)
            XCTAssertGreaterThan(dark, light, "\(tint.displayName)'s dark variant is not brighter")
        }
    }

    func test_swatchMatchesTheResolvedColorForEachScheme() {
        for tint in AccentTint.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
                let resolved = UIColor(tint.color).resolvedColor(with: traits)
                let swatch = UIColor(tint.swatch(for: scheme))
                XCTAssertEqual(resolved, swatch, "\(tint.displayName) swatch differs from the real tint in \(scheme)")
            }
        }
    }

    /// Graphite is the deliberate "no colour" option; the others should read as colours.
    func test_graphiteIsNeutralAndTheOthersAreNot() {
        func saturation(_ tint: AccentTint) -> CGFloat {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(tint.swatch(for: .light)).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return s
        }
        XCTAssertLessThan(saturation(.graphite), 0.15, "graphite should be near-neutral")
        for tint in [AccentTint.purple, .blue, .green] {
            XCTAssertGreaterThan(saturation(tint), 0.5, "\(tint.displayName) should be vivid, not muted")
        }
    }
}
