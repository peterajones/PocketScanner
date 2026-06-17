import XCTest
import PDFKit
@testable import DocumentScanner

/// Isolates the storage→store boundary for the page-extraction refresh bug:
/// after DocumentStorage.write, does an *immediate* InMemoryLibraryStore.refresh()
/// see the new file? If this passes, the write is synchronously visible and the
/// bug lives in the SwiftUI/navigation layer, not the store.
final class LibraryRefreshAfterWriteTests: XCTestCase {

    func test_refresh_immediatelyAfterWrite_seesNewFile() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("refresh-after-write-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let storage = DocumentStorage(documentsURL: dir)
        let store = InMemoryLibraryStore()
        store.documentsURL = dir

        store.refresh()
        XCTAssertEqual(store.summaries.count, 0, "empty to start")

        let pdf = PDFDocument()
        pdf.insert(PDFPage(), at: 0)
        _ = try storage.write(pdf, preferredName: "Extracted")

        // Immediate refresh — exactly what onDocumentCreated does after extraction.
        store.refresh()
        XCTAssertEqual(store.summaries.count, 1,
                       "store.refresh() right after write must see the new file")
        XCTAssertEqual(store.summaries.first?.displayName, "Extracted")
    }
}
