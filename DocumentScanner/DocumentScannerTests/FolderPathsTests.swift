import XCTest
@testable import DocumentScanner

final class FolderPathsTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/docs", isDirectory: true)

    func test_level_root_isZero() {
        XCTAssertEqual(FolderPaths.level(of: root, root: root), 0)
    }
    func test_level_topFolder_isOne() {
        let f = root.appendingPathComponent("Taxes", isDirectory: true)
        XCTAssertEqual(FolderPaths.level(of: f, root: root), 1)
    }
    func test_level_subfolder_isTwo() {
        let sub = root.appendingPathComponent("Taxes", isDirectory: true)
            .appendingPathComponent("T3", isDirectory: true)
        XCTAssertEqual(FolderPaths.level(of: sub, root: root), 2)
    }
    func test_label_root_isMainLibrary() {
        XCTAssertEqual(FolderPaths.label(for: root, root: root), "Main Library")
    }
    func test_label_topFolder_isName() {
        let f = root.appendingPathComponent("Taxes", isDirectory: true)
        XCTAssertEqual(FolderPaths.label(for: f, root: root), "Taxes")
    }
    func test_label_subfolder_isParentThenName() {
        let sub = root.appendingPathComponent("Taxes", isDirectory: true)
            .appendingPathComponent("T3", isDirectory: true)
        XCTAssertEqual(FolderPaths.label(for: sub, root: root), "Taxes ▸ T3")
    }
    // MARK: - Depth 3 (Tax Slips / 2006 / T4)

    func test_maxDepthIsThree() {
        XCTAssertEqual(FolderPaths.maxDepth, 3)
    }

    func test_level_thirdLevel_isThree() {
        let root = URL(fileURLWithPath: "/docs")
        let t4 = URL(fileURLWithPath: "/docs/Tax Slips/2006/T4")
        XCTAssertEqual(FolderPaths.level(of: t4, root: root), 3)
    }

    /// Showing only the parent would render "Tax Slips/2006/T4" and
    /// "Receipts/2006/T4" identically as "2006 ▸ T4" — two different destinations,
    /// indistinguishable in the Move menu.
    func test_label_thirdLevel_showsTheWholePath() {
        let root = URL(fileURLWithPath: "/docs")
        XCTAssertEqual(
            FolderPaths.label(for: URL(fileURLWithPath: "/docs/Tax Slips/2006/T4"), root: root),
            "Tax Slips ▸ 2006 ▸ T4")
    }

    func test_label_disambiguatesSameNamedFoldersUnderDifferentParents() {
        let root = URL(fileURLWithPath: "/docs")
        let a = FolderPaths.label(for: URL(fileURLWithPath: "/docs/Tax Slips/2006/T4"), root: root)
        let b = FolderPaths.label(for: URL(fileURLWithPath: "/docs/Receipts/2006/T4"), root: root)
        XCTAssertNotEqual(a, b)
    }

    /// The Save-to menu names entries relative to their group folder, so passing a
    /// non-root `root` must yield a relative label.
    func test_label_relativeToANonRootFolder() {
        let taxSlips = URL(fileURLWithPath: "/docs/Tax Slips")
        XCTAssertEqual(
            FolderPaths.label(for: URL(fileURLWithPath: "/docs/Tax Slips/2006/T4"), root: taxSlips),
            "2006 ▸ T4")
        XCTAssertEqual(
            FolderPaths.label(for: URL(fileURLWithPath: "/docs/Tax Slips/2006"), root: taxSlips),
            "2006")
    }

}
