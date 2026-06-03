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
}
