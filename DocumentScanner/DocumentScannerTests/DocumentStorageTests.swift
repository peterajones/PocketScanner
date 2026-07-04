import XCTest
import PDFKit
@testable import DocumentScanner

final class DocumentStorageTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_write_savesPDFToProvidedDirectoryWithExpectedFilename() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        XCTAssertEqual(url.lastPathComponent, "Receipt.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_write_resolvesCollisionsBySuffix() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let first = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let second = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let third = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        XCTAssertEqual(first.lastPathComponent, "Receipt.pdf")
        XCTAssertEqual(second.lastPathComponent, "Receipt (2).pdf")
        XCTAssertEqual(third.lastPathComponent, "Receipt (3).pdf")
    }

    func test_write_sanitizesIllegalFilenameCharacters() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "A/B:C")
        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertFalse(url.lastPathComponent.contains(":"))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".pdf"))
    }

    func test_replace_overwritesExistingFile() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let originalData = try Data(contentsOf: url)

        // A structurally different PDF (2 pages).
        let twoPagePDF: PDFDocument = {
            let d = PDFDocument()
            d.insert(makeSinglePagePDF().page(at: 0)!, at: 0)
            d.insert(makeSinglePagePDF().page(at: 0)!, at: 1)
            return d
        }()
        let returnedURL = try storage.write(twoPagePDF, replacing: url, withName: "Receipt")

        XCTAssertEqual(returnedURL, url)
        let newData = try Data(contentsOf: returnedURL)
        XCTAssertNotEqual(originalData, newData, "file should have been overwritten")
        let reloaded = try XCTUnwrap(PDFDocument(url: returnedURL))
        XCTAssertEqual(reloaded.pageCount, 2)
    }

    func test_replace_renamesFileWhenNameChanges() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let newURL = try storage.write(makeSinglePagePDF(), replacing: url, withName: "Lease Agreement")
        XCTAssertEqual(newURL.lastPathComponent, "Lease Agreement.pdf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "old file should have been removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
    }

    func test_replace_resolvesCollisionWhenRenamingToExistingName() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        _ = try storage.write(makeSinglePagePDF(), preferredName: "Lease")
        let other = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let renamedURL = try storage.write(makeSinglePagePDF(), replacing: other, withName: "Lease")
        XCTAssertEqual(renamedURL.lastPathComponent, "Lease (2).pdf")
    }

    func test_delete_removesFile() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let url = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        try storage.delete(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Folders

    func test_createFolder_createsDirectoryAtRoot() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Receipts")
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
        XCTAssertEqual(folder.lastPathComponent, "Receipts")
    }

    func test_createFolder_throwsOnEmptyName() {
        let storage = DocumentStorage(documentsURL: tempDir)
        XCTAssertThrowsError(try storage.createFolder(named: "   "))
    }

    func test_createFolder_sanitizesIllegalCharacters() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Tax/2025")
        XCTAssertFalse(folder.lastPathComponent.contains("/"))
    }

    func test_moveDocument_relocatesPDFIntoFolder() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let docURL = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let folder = try storage.createFolder(named: "Receipts")
        let newURL = try storage.moveDocument(at: docURL, toFolder: folder)
        XCTAssertEqual(newURL.deletingLastPathComponent(), folder)
        XCTAssertEqual(newURL.lastPathComponent, "Receipt.pdf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: docURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
    }

    func test_moveDocument_resolvesCollisionsBySuffix() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Receipts")
        // Pre-existing file in the destination folder
        let preExisting = folder.appendingPathComponent("Receipt.pdf")
        try Data().write(to: preExisting)

        let docURL = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let newURL = try storage.moveDocument(at: docURL, toFolder: folder)
        XCTAssertEqual(newURL.lastPathComponent, "Receipt (2).pdf")
    }

    func test_moveDocument_relocatesFromFolderBackToRoot() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Receipts")
        let docURL = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let inFolder = try storage.moveDocument(at: docURL, toFolder: folder)

        // Move it back out to the root documents directory.
        let backAtRoot = try storage.moveDocument(at: inFolder, toFolder: tempDir)

        XCTAssertEqual(backAtRoot.deletingLastPathComponent().standardizedFileURL.path,
                       tempDir.standardizedFileURL.path)
        XCTAssertEqual(backAtRoot.lastPathComponent, "Receipt.pdf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: inFolder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backAtRoot.path))
    }

    func test_moveDocument_relocatesBetweenFolders() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folderA = try storage.createFolder(named: "A")
        let folderB = try storage.createFolder(named: "B")
        let docURL = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let inA = try storage.moveDocument(at: docURL, toFolder: folderA)

        let inB = try storage.moveDocument(at: inA, toFolder: folderB)

        XCTAssertEqual(inB.deletingLastPathComponent(), folderB)
        XCTAssertEqual(inB.lastPathComponent, "Receipt.pdf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: inA.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inB.path))
    }

    func test_moveDocument_toRootResolvesCollisionBySuffix() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Receipts")
        // Root already contains Receipt.pdf.
        let atRoot = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        // A separate document, also named Receipt.pdf, living inside the folder.
        let inFolder = folder.appendingPathComponent("Receipt.pdf")
        let data = try XCTUnwrap(makeSinglePagePDF().dataRepresentation())
        try data.write(to: inFolder)

        // Moving the folder copy back to root must NOT clobber the existing
        // Receipt.pdf — it gets a (2) suffix via collision resolution.
        let backAtRoot = try storage.moveDocument(at: inFolder, toFolder: tempDir)

        XCTAssertEqual(backAtRoot.lastPathComponent, "Receipt (2).pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backAtRoot.path))
        // The original root document is untouched.
        XCTAssertTrue(FileManager.default.fileExists(atPath: atRoot.path))
    }

    func test_listFolders_returnsOnlyDirectories() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        _ = try storage.createFolder(named: "Receipts")
        _ = try storage.createFolder(named: "Recipes")
        _ = try storage.write(makeSinglePagePDF(), preferredName: "loose-doc")
        let folders = try storage.listFolders()
        let names = Set(folders.map(\.lastPathComponent))
        XCTAssertEqual(names, ["Receipts", "Recipes"])
    }

    func test_renameFolder_movesDirectoryToNewName() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Old")
        let renamed = try storage.renameFolder(at: folder, to: "New")
        XCTAssertEqual(renamed.lastPathComponent, "New")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.path))
    }

    func test_renameFolder_preservesContents() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Old")
        let docURL = try storage.write(makeSinglePagePDF(), preferredName: "Receipt")
        let movedURL = try storage.moveDocument(at: docURL, toFolder: folder)
        let renamed = try storage.renameFolder(at: folder, to: "New")
        let renamedDocURL = renamed.appendingPathComponent("Receipt.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamedDocURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: movedURL.path))
    }

    func test_renameFolder_resolvesNameCollision() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        _ = try storage.createFolder(named: "Receipts")
        let other = try storage.createFolder(named: "Recipes")
        let renamed = try storage.renameFolder(at: other, to: "Receipts")
        XCTAssertEqual(renamed.lastPathComponent, "Receipts (2)")
    }

    func test_renameFolder_throwsOnEmptyName() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Folder")
        XCTAssertThrowsError(try storage.renameFolder(at: folder, to: "   "))
    }

    // MARK: - Nested Folders

    func test_createFolder_inParent_createsNestedSubfolder() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let parent = try storage.createFolder(named: "Taxes2026")
        let sub = try storage.createFolder(named: "T3", in: parent)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: sub.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
        XCTAssertEqual(sub.deletingLastPathComponent().standardizedFileURL.path,
                       parent.standardizedFileURL.path)
        XCTAssertEqual(sub.lastPathComponent, "T3")
    }

    func test_listFolders_inParent_listsOnlyThatParentsSubfolders() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let a = try storage.createFolder(named: "A")
        let b = try storage.createFolder(named: "B")
        _ = try storage.createFolder(named: "A1", in: a)
        _ = try storage.createFolder(named: "A2", in: a)
        _ = try storage.createFolder(named: "B1", in: b)
        let subsOfA = try storage.listFolders(in: a).map(\.lastPathComponent)
        XCTAssertEqual(Set(subsOfA), ["A1", "A2"])
    }

    func test_listFolders_rootWrapper_unchanged() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        _ = try storage.createFolder(named: "Receipts")
        XCTAssertEqual(try storage.listFolders().map(\.lastPathComponent), ["Receipts"])
    }

    func test_deleteFolder_removesFolderAndContents() throws {
        let storage = DocumentStorage(documentsURL: tempDir)
        let folder = try storage.createFolder(named: "Receipts")
        let docURL = try storage.write(makeSinglePagePDF(), preferredName: "R1")
        let movedURL = try storage.moveDocument(at: docURL, toFolder: folder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: movedURL.path))

        try storage.deleteFolder(at: folder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: movedURL.path))
    }

    // MARK: - Helpers

    private func makeSinglePagePDF() -> PDFDocument {
        let doc = PDFDocument()
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 100, height: 100), true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        doc.insert(PDFPage(image: img)!, at: 0)
        return doc
    }
}
