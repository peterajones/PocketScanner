# Signature iCloud Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist signatures to iCloud (in the hidden sibling of the document scope) so they survive reinstall / new-phone setup, without changing `SignatureStore`'s public API or its callers.

**Architecture:** Replace `SignatureStore`'s directory-of-PNGs backing with a single binary-plist archive file (`signatures.dat`). A `SignatureArchive` Codable type holds every signature (PNG bytes + name + creation date). The store resolves its location to `<iCloud container>/Signatures/signatures.dat` when signed into iCloud, falling back to `Application Support/Signature/signatures.dat` locally. A single lazy "converge toward the preferred location" path on load handles one-time migration from the old PNG format and promotion of local data up to iCloud. Reads/writes use `NSFileCoordinator`; reads first trigger `startDownloadingUbiquitousItem` so a fresh device materializes the file.

**Tech Stack:** Swift, UIKit (`UIImage`), Foundation (`PropertyListEncoder/Decoder`, `NSFileCoordinator`, `FileManager` ubiquity APIs), XCTest.

**Context for the implementer:**
- The store's public API MUST stay exactly: `all() -> [Signature]`, `add(_ image: UIImage) throws -> Signature`, `remove(id: String)`, `rename(id: String, to: String)`, `signature(withID: String) -> Signature?`. Callers `SettingsView.swift` and `DocumentViewerView.swift` construct it as `SignatureStore()` (no args) and must not need edits.
- `Signature` is `struct Signature: Identifiable { let id: String; let image: UIImage; var name: String? = nil }`.
- Ground-truth test command (run from repo root):
  ```
  xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
  ```
  Scope to one class by appending e.g. `-only-testing:DocumentScannerTests/SignatureStoreICloudTests`.
- The critical safety invariant: **a read must never overwrite or delete an existing archive.** The load path only ever writes when the preferred file does NOT exist (seeding). A corrupt existing file therefore degrades to "temporarily empty," never "permanently wiped."

---

## File Structure

- **Create** `DocumentScanner/DocumentScanner/Signature/SignatureArchive.swift` — the Codable archive model + binary-plist (de)serialization helpers. One responsibility: the on-disk representation.
- **Modify** `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift` — single-archive backing, location resolution, convergence/migration, coordinated I/O. Public API unchanged.
- **Modify** `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift` — update the four format-coupled tests to the archive model; keep the behavioral tests.
- **Create** `DocumentScanner/DocumentScannerTests/SignatureStoreICloudTests.swift` — iCloud convergence tests via an injected fake iCloud directory.
- **Modify** `docs/FutureEnhancements.md` — mark feature A built.
- **No changes:** `SettingsView.swift`, `DocumentViewerView.swift`, `SignaturePicker.swift`.

---

## Task 1: `SignatureArchive` Codable model

**Files:**
- Create: `DocumentScanner/DocumentScanner/Signature/SignatureArchive.swift`
- Test: `DocumentScanner/DocumentScannerTests/SignatureArchiveTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DocumentScanner/DocumentScannerTests/SignatureArchiveTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class SignatureArchiveTests: XCTestCase {

    func test_binaryRoundTrip_preservesEntries() throws {
        let now = Date()
        let archive = SignatureArchive(entries: [
            .init(id: "a", pngData: Data([0x89, 0x50]), name: "Work", createdAt: now),
            .init(id: "b", pngData: Data([0x01, 0x02, 0x03]), name: nil, createdAt: now.addingTimeInterval(1))
        ])

        let data = try archive.serialized()
        let decoded = try SignatureArchive.deserialized(from: data)

        XCTAssertEqual(decoded.entries.map(\.id), ["a", "b"])
        XCTAssertEqual(decoded.entries[0].name, "Work")
        XCTAssertNil(decoded.entries[1].name)
        XCTAssertEqual(decoded.entries[1].pngData, Data([0x01, 0x02, 0x03]))
    }

    func test_empty_hasNoEntries() {
        XCTAssertTrue(SignatureArchive.empty.entries.isEmpty)
    }

    func test_deserialize_garbage_throws() {
        XCTAssertThrowsError(try SignatureArchive.deserialized(from: Data("nope".utf8)))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DocumentScannerTests/SignatureArchiveTests`
Expected: FAIL to compile — `SignatureArchive` is not defined.

- [ ] **Step 3: Write minimal implementation**

Create `DocumentScanner/DocumentScanner/Signature/SignatureArchive.swift`:

```swift
import Foundation

/// The complete set of saved signatures, serialized as a single binary-plist
/// file (`signatures.dat`). One file keeps iCloud sync trivial: a fresh device
/// materializes it with one coordinated read, with no per-file placeholder
/// guesswork. Binary plist stores the raw PNG bytes compactly (no base64 bloat).
struct SignatureArchive: Codable {
    struct Entry: Codable {
        let id: String
        let pngData: Data
        var name: String?
        let createdAt: Date
    }

    var entries: [Entry]

    static let empty = SignatureArchive(entries: [])

    func serialized() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(self)
    }

    static func deserialized(from data: Data) throws -> SignatureArchive {
        try PropertyListDecoder().decode(SignatureArchive.self, from: data)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DocumentScannerTests/SignatureArchiveTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignatureArchive.swift DocumentScanner/DocumentScannerTests/SignatureArchiveTests.swift
git commit -m "feat: SignatureArchive codable model (binary-plist single-file storage)"
```

---

## Task 2: Rewrite `SignatureStore` onto the single archive (local-only)

Rewrites the store to read/write the archive at a local directory. iCloud resolution is added in Task 3; here the store is local-only (default no-arg init stays local so the app is unchanged for the user — a safe intermediate). Migration from the old `<uuid>.png` + `names.json` format is included.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift` (full replacement)
- Modify: `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift` (update format-coupled tests)

- [ ] **Step 1: Replace the store implementation**

Replace the entire contents of `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift` with:

```swift
import UIKit

/// Persists the user's reusable signatures as a single binary-plist archive
/// (`signatures.dat`). Local-only in this task; Task 3 adds iCloud resolution.
/// The public API (all/add/remove/rename/signature(withID:)) is unchanged so
/// callers stay untouched.
struct SignatureStore {
    private let localDirectory: URL
    private let iCloudDirectoryProvider: () -> URL?
    private let archiveName = "signatures.dat"

    init(
        localDirectory: URL = SignatureStore.defaultLocalDirectory,
        iCloudDirectoryProvider: @escaping () -> URL? = { nil }
    ) {
        self.localDirectory = localDirectory
        self.iCloudDirectoryProvider = iCloudDirectoryProvider
        try? FileManager.default.createDirectory(at: localDirectory, withIntermediateDirectories: true)
    }

    /// Convenience for tests / local-only callers.
    init(directory: URL) {
        self.init(localDirectory: directory, iCloudDirectoryProvider: { nil })
    }

    static var defaultLocalDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Signature", isDirectory: true)
    }

    // MARK: - Public API

    /// All saved signatures, newest first.
    func all() -> [Signature] {
        loadArchive().entries
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { entry in
                guard let img = UIImage(data: entry.pngData) else { return nil }
                return Signature(id: entry.id, image: img, name: entry.name)
            }
    }

    @discardableResult
    func add(_ image: UIImage) throws -> Signature {
        guard let data = image.pngData() else { throw NSError(domain: "SignatureStore", code: 1) }
        var archive = loadArchive()
        let entry = SignatureArchive.Entry(id: UUID().uuidString, pngData: data, name: nil, createdAt: Date())
        archive.entries.append(entry)
        try writeArchive(archive, to: preferredArchiveURL())
        return Signature(id: entry.id, image: image, name: nil)
    }

    func remove(id: String) {
        var archive = loadArchive()
        archive.entries.removeAll { $0.id == id }
        try? writeArchive(archive, to: preferredArchiveURL())
    }

    /// Sets or clears a signature's name. A blank/whitespace-only name reverts it
    /// to unnamed. Name is trimmed before saving.
    func rename(id: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        var archive = loadArchive()
        guard let idx = archive.entries.firstIndex(where: { $0.id == id }) else { return }
        archive.entries[idx].name = trimmed.isEmpty ? nil : trimmed
        try? writeArchive(archive, to: preferredArchiveURL())
    }

    func signature(withID id: String) -> Signature? {
        guard let entry = loadArchive().entries.first(where: { $0.id == id }),
              let img = UIImage(data: entry.pngData) else { return nil }
        return Signature(id: entry.id, image: img, name: entry.name)
    }

    // MARK: - Location

    /// The archive location writes/reads target. Local-only in this task.
    private func preferredArchiveURL() -> URL {
        localDirectory.appendingPathComponent(archiveName)
    }

    // MARK: - Load / converge

    /// Loads the archive, seeding it once from the old PNG format if needed.
    /// NEVER overwrites an existing file — a corrupt file degrades to empty.
    private func loadArchive() -> SignatureArchive {
        let url = preferredArchiveURL()
        if FileManager.default.fileExists(atPath: url.path) {
            return readArchive(at: url) ?? .empty
        }
        if let seed = localSeedArchive() {
            try? writeArchive(seed, to: url)
            return seed
        }
        return .empty
    }

    /// Builds a seed archive from local data: an existing local archive, else the
    /// old-format `<uuid>.png` files (+ `names.json`). Returns nil if nothing to migrate.
    private func localSeedArchive() -> SignatureArchive? {
        let localURL = localDirectory.appendingPathComponent(archiveName)
        if FileManager.default.fileExists(atPath: localURL.path),
           let existing = readArchive(at: localURL) {
            return existing
        }
        return buildArchiveFromLegacy()
    }

    /// One-time migration: fold old `<uuid>.png` files (+ legacy single
    /// `signature.png`, + `names.json`) into an archive. Leaves the PNGs on disk
    /// as a local backup. Returns nil when there are no PNGs.
    private func buildArchiveFromLegacy() -> SignatureArchive? {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: localDirectory, includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]) else { return nil }
        let pngs = urls.filter { $0.pathExtension.lowercased() == "png" }
        guard !pngs.isEmpty else { return nil }
        let names = loadLegacyNames()
        var entries: [SignatureArchive.Entry] = []
        for url in pngs {
            guard let data = try? Data(contentsOf: url) else { continue }
            let stem = url.deletingPathExtension().lastPathComponent
            // Legacy single "signature.png" has no UUID stem — assign one.
            let id = (stem == "signature") ? UUID().uuidString : stem
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            entries.append(.init(id: id, pngData: data, name: names[stem], createdAt: created))
        }
        return entries.isEmpty ? nil : SignatureArchive(entries: entries)
    }

    private func loadLegacyNames() -> [String: String] {
        let url = localDirectory.appendingPathComponent("names.json")
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    // MARK: - Coordinated I/O

    private func readArchive(at url: URL) -> SignatureArchive? {
        var archive: SignatureArchive?
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            guard let data = try? Data(contentsOf: readURL) else { return }
            archive = try? SignatureArchive.deserialized(from: data)
        }
        return archive
    }

    private func writeArchive(_ archive: SignatureArchive, to url: URL) throws {
        let data = try archive.serialized()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
            do { try data.write(to: writeURL, options: .atomic) } catch { writeError = error }
        }
        if let error = coordError ?? (writeError as NSError?) { throw error }
    }
}
```

- [ ] **Step 2: Update the format-coupled tests**

Replace the entire contents of `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift` with (behavioral tests kept; the four format-coupled tests replaced by archive-equivalent ones):

```swift
import XCTest
import UIKit
@testable import DocumentScanner

final class SignatureStoreTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sigstore-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func image(_ w: Int = 60, _ h: Int = 24) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    func test_add_then_all_returnsIt() throws {
        let store = SignatureStore(directory: tempDir())
        XCTAssertTrue(store.all().isEmpty)
        let sig = try store.add(image())
        let all = store.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, sig.id)
    }

    func test_multipleAdds_newestFirst() throws {
        let store = SignatureStore(directory: tempDir())
        let a = try store.add(image(40, 10))
        Thread.sleep(forTimeInterval: 0.05)
        let b = try store.add(image(80, 20))
        XCTAssertEqual(store.all().map(\.id), [b.id, a.id], "newest first")
    }

    func test_remove_dropsOne() throws {
        let store = SignatureStore(directory: tempDir())
        let a = try store.add(image())
        Thread.sleep(forTimeInterval: 0.05)
        let b = try store.add(image())
        store.remove(id: a.id)
        XCTAssertEqual(store.all().map(\.id), [b.id])
    }

    func test_signatureWithID_roundTrips() throws {
        let store = SignatureStore(directory: tempDir())
        let a = try store.add(image(50, 30))
        let loaded = store.signature(withID: a.id)
        XCTAssertEqual(loaded?.id, a.id)
        XCTAssertEqual(loaded?.image.cgImage?.width, 50)
        XCTAssertNil(store.signature(withID: "does-not-exist"))
    }

    func test_all_freshStore_namesAreNil() throws {
        let store = SignatureStore(directory: tempDir())
        _ = try store.add(image())
        XCTAssertNil(store.all().first?.name, "a fresh signature is unnamed")
    }

    func test_rename_setsName_roundTrips() throws {
        let store = SignatureStore(directory: tempDir())
        let sig = try store.add(image())
        store.rename(id: sig.id, to: "Work")
        XCTAssertEqual(store.all().first?.name, "Work")
    }

    func test_rename_overwritesPreviousName() throws {
        let store = SignatureStore(directory: tempDir())
        let sig = try store.add(image())
        store.rename(id: sig.id, to: "Work")
        store.rename(id: sig.id, to: "Personal")
        XCTAssertEqual(store.all().first?.name, "Personal")
    }

    func test_rename_blankClearsName() throws {
        let store = SignatureStore(directory: tempDir())
        let sig = try store.add(image())
        store.rename(id: sig.id, to: "Work")
        store.rename(id: sig.id, to: "   ")
        XCTAssertNil(store.all().first?.name, "whitespace-only clears the name")
    }

    func test_rename_trimsWhitespace() throws {
        let store = SignatureStore(directory: tempDir())
        let sig = try store.add(image())
        store.rename(id: sig.id, to: "  Work  ")
        XCTAssertEqual(store.all().first?.name, "Work")
    }

    func test_remove_dropsNameToo() throws {
        let store = SignatureStore(directory: tempDir())
        let a = try store.add(image())
        store.rename(id: a.id, to: "Work")
        store.remove(id: a.id)
        XCTAssertTrue(store.all().isEmpty)
        let b = try store.add(image())
        XCTAssertNil(store.all().first(where: { $0.id == b.id })?.name, "removed name does not linger")
    }

    // MARK: - Migration from the old PNG format

    func test_migratesOldFormatPngsAndNames() throws {
        let dir = tempDir()
        let id1 = UUID().uuidString, id2 = UUID().uuidString
        try image(50, 20).pngData()!.write(to: dir.appendingPathComponent("\(id1).png"))
        try image(60, 20).pngData()!.write(to: dir.appendingPathComponent("\(id2).png"))
        try JSONEncoder().encode([id1: "Work"]).write(to: dir.appendingPathComponent("names.json"))

        let store = SignatureStore(directory: dir)
        let all = store.all()
        XCTAssertEqual(all.count, 2, "both old PNGs migrated into the archive")
        XCTAssertEqual(all.first(where: { $0.id == id1 })?.name, "Work", "name migrated from sidecar")
        XCTAssertNil(all.first(where: { $0.id == id2 })?.name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(id1).png").path),
                      "old PNGs left in place as backup")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("signatures.dat").path),
                      "archive written")
        XCTAssertEqual(store.all().count, 2, "migration is idempotent")
    }

    func test_migratesLegacySingleSignaturePng() throws {
        let dir = tempDir()
        try image(70, 35).pngData()!.write(to: dir.appendingPathComponent("signature.png"))
        let store = SignatureStore(directory: dir)
        XCTAssertEqual(store.all().count, 1, "legacy signature.png folded into the archive")
        XCTAssertEqual(store.all().count, 1, "idempotent")
    }
}
```

- [ ] **Step 3: Run the full suite**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: PASS — all tests green, including the updated `SignatureStoreTests` and the Task 1 `SignatureArchiveTests`. (The app is still local-only; no user-visible change.)

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignatureStore.swift DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift
git commit -m "refactor: SignatureStore backed by a single archive file (local-only)"
```

---

## Task 3: iCloud resolution + convergence (promotion, fallback, download, corrupt-safe)

Adds the real iCloud location, promotes local data up to iCloud on load, wires the no-arg init to the container, and makes reads materialize a fresh-device placeholder.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift`
- Test: `DocumentScanner/DocumentScannerTests/SignatureStoreICloudTests.swift` (create)

- [ ] **Step 1: Write the failing tests**

Create `DocumentScanner/DocumentScannerTests/SignatureStoreICloudTests.swift`:

```swift
import XCTest
import UIKit
@testable import DocumentScanner

/// Exercises the iCloud convergence logic with an injected fake iCloud directory
/// (a temp dir) — no real iCloud account needed. "Signed out" = nil provider.
final class SignatureStoreICloudTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sigicloud-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func image(_ w: Int = 60, _ h: Int = 24) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    private func datExists(in dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent("signatures.dat").path)
    }

    func test_iCloudArchiveIsSourceOfTruth() throws {
        let local = tempDir(); let cloud = tempDir()
        let store = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { cloud })
        let a = try store.add(image())
        XCTAssertTrue(datExists(in: cloud), "add writes to the iCloud location")
        XCTAssertFalse(datExists(in: local), "not written locally when signed into iCloud")
        XCTAssertEqual(store.all().map(\.id), [a.id])
    }

    func test_promotesLocalArchiveToICloud() throws {
        let local = tempDir(); let cloud = tempDir()
        // Signed out: writes go local.
        let localStore = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { nil })
        let a = try localStore.add(image())
        XCTAssertTrue(datExists(in: local))

        // Signed in later: reading promotes the local archive up to iCloud.
        let cloudStore = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { cloud })
        XCTAssertEqual(cloudStore.all().map(\.id), [a.id], "reads promoted signatures")
        XCTAssertTrue(datExists(in: cloud), "archive promoted into the iCloud directory")
    }

    func test_promotesOldPngFormatDirectlyToICloud() throws {
        let local = tempDir(); let cloud = tempDir()
        // Old-format signatures sit in the local (Application Support) dir.
        let id = UUID().uuidString
        try image(50, 20).pngData()!.write(to: local.appendingPathComponent("\(id).png"))

        let store = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { cloud })
        XCTAssertEqual(store.all().map(\.id), [id], "old PNG migrated")
        XCTAssertTrue(datExists(in: cloud), "migrated archive lands in iCloud")
    }

    func test_fallsBackToLocalWhenSignedOut() throws {
        let local = tempDir()
        let store = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { nil })
        _ = try store.add(image())
        XCTAssertTrue(datExists(in: local))
        XCTAssertEqual(store.all().count, 1)
    }

    func test_corruptICloudArchive_returnsEmpty_andIsPreserved() throws {
        let cloud = tempDir()
        let corrupt = Data("not a plist".utf8)
        try corrupt.write(to: cloud.appendingPathComponent("signatures.dat"))
        let store = SignatureStore(localDirectory: tempDir(), iCloudDirectoryProvider: { cloud })
        XCTAssertTrue(store.all().isEmpty, "corrupt archive → empty, no crash")
        let after = try Data(contentsOf: cloud.appendingPathComponent("signatures.dat"))
        XCTAssertEqual(after, corrupt, "corrupt file left intact, never overwritten by a read")
    }

    func test_orderNewestFirst_acrossReopen() throws {
        let cloud = tempDir(); let local = tempDir()
        let store = SignatureStore(localDirectory: local, iCloudDirectoryProvider: { cloud })
        let a = try store.add(image())
        Thread.sleep(forTimeInterval: 0.05)
        let b = try store.add(image())
        let reopened = SignatureStore(localDirectory: tempDir(), iCloudDirectoryProvider: { cloud })
        XCTAssertEqual(reopened.all().map(\.id), [b.id, a.id])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DocumentScannerTests/SignatureStoreICloudTests`
Expected: FAIL — the store ignores `iCloudDirectoryProvider` (writes go local), so `test_iCloudArchiveIsSourceOfTruth`, `test_promotesLocalArchiveToICloud`, `test_promotesOldPngFormatDirectlyToICloud`, and `test_orderNewestFirst_acrossReopen` fail on the missing iCloud `signatures.dat`.

- [ ] **Step 3: Implement iCloud resolution + convergence**

In `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift`, make these edits:

**(a) Flip the no-arg default provider to the real container.** Change the default value of `iCloudDirectoryProvider` in the designated init:

```swift
    init(
        localDirectory: URL = SignatureStore.defaultLocalDirectory,
        iCloudDirectoryProvider: @escaping () -> URL? = SignatureStore.defaultICloudDirectoryProvider
    ) {
```

**(b) Add the default provider.** Add this static, right after `defaultLocalDirectory`:

```swift
    /// The hidden sibling of the document scope: `<container>/Signatures/`. NOT
    /// under `/Documents`, so iCloud syncs it but Files.app and the scan library
    /// (which enumerate `/Documents`) never surface it. nil when signed out of iCloud.
    static var defaultICloudDirectoryProvider: () -> URL? {
        {
            FileManager.default
                .url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Signatures", isDirectory: true)
        }
    }
```

**(c) Resolve the preferred URL to iCloud when available.** Replace `preferredArchiveURL()`:

```swift
    /// iCloud archive when signed in, else the local archive.
    private func preferredArchiveURL() -> URL {
        if let cloudDir = iCloudDirectoryProvider() {
            return cloudDir.appendingPathComponent(archiveName)
        }
        return localDirectory.appendingPathComponent(archiveName)
    }
```

**(d) Seed the preferred location from local data.** `loadArchive()` already writes the seed to `preferredArchiveURL()`, so when the preferred location is iCloud and it's empty, `localSeedArchive()` (which reads the local archive, else the legacy PNGs) is promoted up automatically. No change needed to `loadArchive()` or `localSeedArchive()` — verify they still read as in Task 2.

**(e) Materialize a fresh-device placeholder.** In `readArchive(at:)`, trigger a download before the coordinated read:

```swift
    private func readArchive(at url: URL) -> SignatureArchive? {
        // Force download if this is a not-yet-materialized iCloud placeholder.
        // Throws (harmlessly) for a non-ubiquitous local URL, hence try?.
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        var archive: SignatureArchive?
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            guard let data = try? Data(contentsOf: readURL) else { return }
            archive = try? SignatureArchive.deserialized(from: data)
        }
        return archive
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DocumentScannerTests/SignatureStoreICloudTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Run the full suite**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: PASS — entire suite green.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignatureStore.swift DocumentScanner/DocumentScannerTests/SignatureStoreICloudTests.swift
git commit -m "feat: signatures sync via iCloud container (hidden Signatures/ sibling)"
```

**Known limitation (acceptable, documented):** if a user adds signatures while signed into iCloud and then signs out of iCloud entirely, the local fallback rebuilds from the pre-migration PNG backup and won't include the iCloud-only additions. This is out of scope (scenario is reinstall/new-phone survival, not iCloud sign-out); no mirror is maintained, per YAGNI.

---

## Task 4: Docs — mark feature A built

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Update the "Next up" A entry**

In `docs/FutureEnhancements.md`, under "## Next up", change the **A — Signature iCloud sync** bullet from a plan to a built entry. Replace its leading text so it reads (keep the existing findings prose that follows if useful, but lead with the built status):

```markdown
- ~~**A — Signature iCloud sync (v2.7 / 26)**~~ — **Built (branch `feature/signature-icloud-sync`).** `SignatureStore` now persists all signatures as a single binary-plist archive (`signatures.dat`) instead of a directory of PNGs, stored at `<iCloud container>/Signatures/signatures.dat` — the **hidden sibling of `/Documents`**, so iCloud syncs it but Files.app and the scan library never surface it. Local `Application Support/Signature/` fallback when signed out. A single lazy converge-on-load path handles one-time migration from the old `<uuid>.png` + `names.json` format (old PNGs left as backup) and promotion of local data up to iCloud; reads trigger `startDownloadingUbiquitousItem` so a fresh device materializes the file. Public `SignatureStore` API unchanged (callers untouched). Fail-safe: a corrupt archive degrades to empty and is never overwritten by a read; conflicts are last-writer-wins. New `SignatureArchive` Codable model. Spec `docs/superpowers/specs/2026-07-08-signature-icloud-sync-design.md`, plan `docs/superpowers/plans/2026-07-08-signature-icloud-sync.md`. **On-device (Release build) smoke pending:** (1) reinstall pulls signatures back; (2) morning-iPhone → afternoon-iPad handoff (same iCloud account); (3) verify `Signatures/` does NOT appear in Files.app or the scan library.
```

- [ ] **Step 2: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: mark signature iCloud sync built (v2.7)"
```

---

## After all tasks

- **On-device (Release build) smoke test** — cannot be unit-tested (needs a real iCloud account). Verify, per the spec:
  1. Fresh install / reinstall pulls signatures back.
  2. A signature added on one device is available on another device (same iCloud account) after switching.
  3. `Signatures/` does **not** appear in Files.app or in the app's scan library.
- Then use **superpowers:finishing-a-development-branch** to merge.
- Version bump + What's New + archive/submit as **v2.7 (26)** happen at release time (not part of this plan).

---

## Self-review notes (checked against the spec)

- **Spec coverage:** single-archive storage (Task 1–2); hidden `/Signatures` sibling + local fallback (Task 3b/c); migration from old format, non-destructive + idempotent (Task 2 `buildArchiveFromLegacy`, tested); promotion local→iCloud (Task 3 seeding, tested); fresh-device download (Task 3e); load-latest-on-open (every `all()` re-reads — inherent, exercised by reopen test); corrupt-safe never-overwrite (Task 2 `loadArchive` structure, tested Task 3); LWW conflicts (structural — last write wins on the single file; no merge code needed); public API unchanged (Task 2, callers untouched); testing without iCloud via injected provider (Task 3). All covered.
- **Type consistency:** `SignatureArchive` / `SignatureArchive.Entry` / `.serialized()` / `.deserialized(from:)` / `.empty` used identically across tasks; `preferredArchiveURL()`, `loadArchive()`, `localSeedArchive()`, `buildArchiveFromLegacy()`, `readArchive(at:)`, `writeArchive(_:to:)` names stable; init shape `init(localDirectory:iCloudDirectoryProvider:)` + `init(directory:)` convenience consistent.
- **No placeholders:** all steps contain complete code and exact commands.
```
