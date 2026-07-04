import XCTest
@testable import DocumentScanner

final class MoveDestinationsTests: XCTestCase {

    private let root = URL(fileURLWithPath: "/docs", isDirectory: true)
    private func folder(_ name: String) -> URL {
        URL(fileURLWithPath: "/docs/\(name)", isDirectory: true)
    }

    func test_docInFolder_offersMainLibraryAndOtherFolders() {
        let folders = [folder("A"), folder("B"), folder("C")]
        let result = MoveDestinations.list(
            currentParent: folder("B"), root: root, folders: folders
        )
        XCTAssertEqual(result.map(\.name), ["Main Library", "A", "C"])
        XCTAssertEqual(result.first?.url.standardizedFileURL.path,
                       root.standardizedFileURL.path)
    }

    func test_docInOnlyFolder_offersOnlyMainLibrary() {
        // The doc lives in the single existing folder, so the only place left
        // to move it is back to the main library.
        let result = MoveDestinations.list(
            currentParent: folder("B"), root: root, folders: [folder("B")]
        )
        XCTAssertEqual(result.map(\.name), ["Main Library"])
    }

    func test_docAtRoot_hidesMainLibraryAndListsAllFolders() {
        let folders = [folder("A"), folder("B")]
        let result = MoveDestinations.list(
            currentParent: root, root: root, folders: folders
        )
        XCTAssertEqual(result.map(\.name), ["A", "B"])
    }

    func test_docAtRoot_withNoFolders_isEmpty() {
        let result = MoveDestinations.list(
            currentParent: root, root: root, folders: []
        )
        XCTAssertTrue(result.isEmpty)
    }

    func test_pathComparisonIgnoresTrailingSlashDifferences() {
        // currentParent built without the isDirectory flag should still match.
        let bNoSlash = URL(fileURLWithPath: "/docs/B")
        let result = MoveDestinations.list(
            currentParent: bNoSlash, root: root, folders: [folder("A"), folder("B")]
        )
        XCTAssertEqual(result.map(\.name), ["Main Library", "A"])
    }

    func test_list_labelsSubfoldersWithParentContext() {
        let root = URL(fileURLWithPath: "/docs", isDirectory: true)
        let taxes = root.appendingPathComponent("Taxes", isDirectory: true)
        let t3 = taxes.appendingPathComponent("T3", isDirectory: true)
        // Doc currently at root; destinations should include the sub-folder, labeled with parent.
        let dests = MoveDestinations.list(currentParent: root, root: root, folders: [taxes, t3])
        let t3Dest = dests.first { $0.url == t3 }
        XCTAssertEqual(t3Dest?.name, "Taxes ▸ T3")
        XCTAssertEqual(dests.first { $0.url == taxes }?.name, "Taxes")
    }
}
