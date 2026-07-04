import XCTest
@testable import DocumentScanner

final class ScanDestinationsTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/docs", isDirectory: true)

    func test_build_mainIsRoot() {
        let tree = ScanDestinations.build(root: root, folders: [], subfoldersByFolder: [:])
        XCTAssertEqual(tree.main.url, root)
        XCTAssertEqual(tree.main.name, "Main Library")
        XCTAssertTrue(tree.groups.isEmpty)
    }

    func test_build_groupsFoldersWithTheirSubfolders() {
        let taxes = root.appendingPathComponent("Taxes", isDirectory: true)
        let t3 = taxes.appendingPathComponent("T3", isDirectory: true)
        let receipts = root.appendingPathComponent("Receipts", isDirectory: true)
        let tree = ScanDestinations.build(
            root: root,
            folders: [taxes, receipts],
            subfoldersByFolder: [taxes: [t3], receipts: []]
        )
        XCTAssertEqual(tree.groups.map { $0.folder.name }, ["Taxes", "Receipts"])
        XCTAssertEqual(tree.groups[0].subfolders.map { $0.name }, ["T3"])
        XCTAssertTrue(tree.groups[1].subfolders.isEmpty)
    }
}
