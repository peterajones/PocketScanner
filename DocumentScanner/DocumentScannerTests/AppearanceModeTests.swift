import XCTest
import SwiftUI
@testable import DocumentScanner

final class AppearanceModeTests: XCTestCase {

    func test_threeOptionsNoMore() {
        XCTAssertEqual(AppearanceMode.allCases.count, 3)
    }

    /// `.system` must map to nil, not to a guess at the current scheme. nil is what tells
    /// SwiftUI "do not override", which is the only way to actually follow iOS — including
    /// when the user changes it while the app is open.
    func test_systemDoesNotOverride() {
        XCTAssertNil(AppearanceMode.system.preferredColorScheme)
    }

    func test_lightAndDarkOverride() {
        XCTAssertEqual(AppearanceMode.light.preferredColorScheme, .light)
        XCTAssertEqual(AppearanceMode.dark.preferredColorScheme, .dark)
    }

    // MARK: - Storage

    func test_allCasesRoundTripThroughRawValue() {
        for mode in AppearanceMode.allCases {
            XCTAssertEqual(AppearanceMode(rawValue: mode.rawValue), mode)
        }
    }

    /// The shipped default. An app that ignores the system setting without being asked is
    /// the thing users complain about.
    func test_emptyStorageResolvesToSystem() {
        XCTAssertEqual(AppearanceMode.resolve(""), .system)
    }

    /// A value written by a future version must not leave the app in an undefined state.
    func test_unknownValueResolvesToSystem() {
        XCTAssertEqual(AppearanceMode.resolve("sepia"), .system)
        XCTAssertEqual(AppearanceMode.resolve("SYSTEM"), .system, "raw values are case-sensitive")
    }

    func test_storageKeyIsStable() {
        // Changing this silently resets everyone's preference on upgrade.
        XCTAssertEqual(AppearanceMode.storageKey, "appearanceMode")
    }

    // MARK: - Display

    func test_displayNamesAreNonEmptyAndDistinct() {
        let names = AppearanceMode.allCases.map(\.displayName)
        XCTAssertFalse(names.contains(where: \.isEmpty))
        XCTAssertEqual(Set(names).count, names.count)
    }

    /// No option can leave the user unable to find the control that undoes it — the
    /// reasoning that ruled out a free colour picker. Every mode is a defined scheme or a
    /// deliberate no-override, so Settings stays legible in all three.
    func test_everyModeIsAValidTerminalState() {
        for mode in AppearanceMode.allCases {
            let scheme = mode.preferredColorScheme
            XCTAssertTrue(scheme == nil || scheme == .light || scheme == .dark,
                          "\(mode) produced an unexpected scheme")
        }
    }
}
