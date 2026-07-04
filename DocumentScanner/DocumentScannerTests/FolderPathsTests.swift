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
}
