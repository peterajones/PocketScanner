# Multiple Signatures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user keep several reusable signatures (thumbnail-identified, local), pick which to place when signing, and have Move re-place the *same* signature.

**Architecture:** Refactor `SignatureStore` from one PNG to a collection of `<uuid>.png` files (with a one-time migration of the legacy `signature.png`). Settings shows a list of thumbnails; the viewer's Sign shows a picker when 2+ exist; the placed annotation carries its signature id in the PDF `contents` field so Move reloads the right image.

**Tech Stack:** Swift, SwiftUI, PDFKit (`PDFAnnotation.contents`), XCTest.

**Spec:** `docs/superpowers/specs/2026-06-23-multiple-signatures-design.md`

---

## File Structure

- Create: `Signature/Signature.swift` — `Signature { id, image }` model.
- Create: `Signature/SignaturePicker.swift` — sheet to choose a signature.
- Modify: `Signature/SignatureStore.swift` — single PNG → collection + migration.
- Modify: `Signature/SignatureCaptureView.swift` — `store.save` → `store.add`.
- Modify: `Settings/SettingsView.swift` — Signatures list (multiple thumbnails + swipe-delete + Add).
- Modify: `Viewer/DocumentViewerView.swift` — Sign picker (0/1/2+), tag `contents` id on place, Move by id with picker fallback.
- Modify (tests): `DocumentScannerTests/SignatureStoreTests.swift` (collection + migration), `DocumentScannerTests/SignatureAnnotationPersistenceTests.swift` (id round-trip).
- Modify: `docs/FutureEnhancements.md` — on merge.

Build / test commands:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```

> SourceKit may show "cannot find … in scope" / "No such module" for these files — stale-index
> artifacts. `xcodebuild` is the source of truth.

---

## Task 1: `Signature` model + `SignatureStore` collection (with migration); keep callers compiling

This refactors the store and updates its three callers minimally so the app keeps building and
behaves exactly as today (it places/shows the single/newest signature). Later tasks add the list,
picker, and Move-by-id.

**Files:**
- Create: `DocumentScanner/DocumentScanner/Signature/Signature.swift`
- Modify: `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift`
- Modify: `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift`
- Modify: `DocumentScanner/DocumentScanner/Signature/SignatureCaptureView.swift`
- Modify: `DocumentScanner/DocumentScanner/Settings/SettingsView.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`

- [ ] **Step 1: Write the failing store tests**

Replace the contents of `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift`:

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
        UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
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
        Thread.sleep(forTimeInterval: 0.05)       // ensure distinct creation timestamps
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

    func test_migratesLegacySignaturePng() throws {
        let dir = tempDir()
        // Simulate an existing single-signature user.
        try image(70, 35).pngData()!.write(to: dir.appendingPathComponent("signature.png"))
        let store = SignatureStore(directory: dir)
        let all = store.all()
        XCTAssertEqual(all.count, 1, "legacy signature folded into the collection")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("signature.png").path),
                       "legacy file renamed away")
        XCTAssertEqual(store.all().count, 1, "migration is idempotent")
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SignatureStoreTests 2>&1 | grep -E "value of type|error:|\*\* TEST" | tail -5
```
Expected: FAIL (the old store has no `add`/`all`/`remove`/`signature(withID:)`).

- [ ] **Step 3: Create the `Signature` model**

Create `DocumentScanner/DocumentScanner/Signature/Signature.swift`:

```swift
import UIKit

/// One saved signature. `id` is the on-disk filename stem (a UUID), so the store
/// and placed annotations can reference a specific signature.
struct Signature: Identifiable {
    let id: String
    let image: UIImage
}
```

- [ ] **Step 4: Rewrite `SignatureStore` as a collection**

Replace the contents of `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift`:

```swift
import UIKit

/// Persists the user's reusable signatures as transparent PNGs (one `<uuid>.png`
/// per signature) in Application Support. Local only; the injectable directory
/// keeps it testable and makes a future iCloud move a localized change.
struct SignatureStore {
    private let directory: URL

    init(directory: URL = SignatureStore.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Signature", isDirectory: true)
    }

    /// All saved signatures, newest first.
    func all() -> [Signature] {
        migrateLegacyIfNeeded()
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]) else { return [] }
        let pngs = urls.filter { $0.pathExtension.lowercased() == "png" }
        let newestFirst = pngs.sorted {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return a > b
        }
        return newestFirst.compactMap { url in
            guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
            return Signature(id: url.deletingPathExtension().lastPathComponent, image: img)
        }
    }

    var isEmpty: Bool { all().isEmpty }

    @discardableResult
    func add(_ image: UIImage) throws -> Signature {
        migrateLegacyIfNeeded()
        guard let data = image.pngData() else { throw NSError(domain: "SignatureStore", code: 1) }
        let id = UUID().uuidString
        try data.write(to: directory.appendingPathComponent("\(id).png"), options: .atomic)
        return Signature(id: id, image: image)
    }

    func remove(id: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).png"))
    }

    func signature(withID id: String) -> Signature? {
        let url = directory.appendingPathComponent("\(id).png")
        guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
        return Signature(id: id, image: img)
    }

    /// One-time: fold a legacy single `signature.png` into the collection by
    /// renaming it to a `<uuid>.png`. Idempotent (no-op once gone).
    private func migrateLegacyIfNeeded() {
        let legacy = directory.appendingPathComponent("signature.png")
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        let dest = directory.appendingPathComponent("\(UUID().uuidString).png")
        try? FileManager.default.moveItem(at: legacy, to: dest)
    }
}
```

- [ ] **Step 5: Update `SignatureCaptureView` to use `add`**

In `DocumentScanner/DocumentScanner/Signature/SignatureCaptureView.swift`, its `save()` calls
`try? store.save(processed)`. Change that line to:

```swift
        _ = try? store.add(processed)
```

- [ ] **Step 6: Keep `SettingsView` compiling (interim single-thumbnail)**

In `DocumentScanner/DocumentScanner/Settings/SettingsView.swift`, the section uses
`signatureStore.load()` and `.clear()`. Update those usages to the collection API (this stays a
single-thumbnail UI for now; Task 2 turns it into the list):

- `.onAppear { signatureThumbnail = signatureStore.load() }` → `.onAppear { signatureThumbnail = signatureStore.all().first?.image }`
- the capture sheet's `onSaved: { showingSignatureCapture = false; signatureThumbnail = signatureStore.load() }` → `onSaved: { showingSignatureCapture = false; signatureThumbnail = signatureStore.all().first?.image }`
- the "Remove Signature" button body `signatureStore.clear(); self.signatureThumbnail = nil` →
```swift
                        if let first = signatureStore.all().first { signatureStore.remove(id: first.id) }
                        self.signatureThumbnail = signatureStore.all().first?.image
```

- [ ] **Step 7: Keep `DocumentViewerView` compiling (interim newest-signature)**

In `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift` there are three
`signatureStore.load()` uses. Replace each `signatureStore.load()` with
`signatureStore.all().first?.image`:
- the **Sign** button: `guard let sig = signatureStore.load() else { … }` → `guard let sig = signatureStore.all().first?.image else { … }`
- the **capture onSaved**: `if let sig = signatureStore.load(), let page = … ` → `if let sig = signatureStore.all().first?.image, let page = …`
- the **Move** handler: `guard let sig = signatureStore.load() else { … }` → `guard let sig = signatureStore.all().first?.image else { … }`

- [ ] **Step 8: Build + run the store tests**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SignatureStoreTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/Signature.swift \
        DocumentScanner/DocumentScanner/Signature/SignatureStore.swift \
        DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift \
        DocumentScanner/DocumentScanner/Signature/SignatureCaptureView.swift \
        DocumentScanner/DocumentScanner/Settings/SettingsView.swift \
        DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
git commit -m "feat: SignatureStore collection + migration (callers keep single-signature behavior)"
```

---

## Task 2: Settings — Signatures list (multiple thumbnails, swipe-delete, Add)

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Settings/SettingsView.swift`

- [ ] **Step 1: Switch state from one thumbnail to a list**

Replace the `@State private var signatureThumbnail: UIImage?` declaration with:

```swift
    @State private var signatures: [Signature] = []
```

- [ ] **Step 2: Replace the Signature section body with a list**

Replace the whole Signature `Section { … } header/footer` block with:

```swift
            Section {
                ForEach(signatures) { sig in
                    Image(uiImage: sig.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 100)
                        .padding(.vertical, 10)
                        .background(Color.white)   // black ink on transparent — visible in dark mode
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4)))
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                signatureStore.remove(id: sig.id)
                                signatures = signatureStore.all()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                }
                Button("Add Signature") { showingSignatureCapture = true }
            } header: {
                Text("Signature")
            } footer: {
                Text("Scan your signature on paper, then reuse it to sign any document. Add more than one — you'll pick which to place.")
            }
```

- [ ] **Step 3: Update the load + capture wiring**

Change the two state-loading sites:
- `.onAppear { signatureThumbnail = signatureStore.all().first?.image }` → `.onAppear { signatures = signatureStore.all() }`
- the capture sheet `onSaved: { showingSignatureCapture = false; signatureThumbnail = signatureStore.all().first?.image }` → `onSaved: { showingSignatureCapture = false; signatures = signatureStore.all() }`

- [ ] **Step 4: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Settings/SettingsView.swift
git commit -m "feat: Settings shows a list of signatures (swipe to delete, Add)"
```

---

## Task 3: Viewer — Sign picker (0/1/2+) + tag signature id on place

**Files:**
- Create: `DocumentScanner/DocumentScanner/Signature/SignaturePicker.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`
- Modify: `DocumentScanner/DocumentScannerTests/SignatureAnnotationPersistenceTests.swift`

- [ ] **Step 1: Create `SignaturePicker`**

Create `DocumentScanner/DocumentScanner/Signature/SignaturePicker.swift`:

```swift
import SwiftUI

/// A sheet that lists saved signatures as thumbnails; tapping one calls `onPick`.
/// Used when signing with 2+ signatures, and as Move's fallback.
struct SignaturePicker: View {
    let signatures: [Signature]
    let onPick: (Signature) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List(signatures) { sig in
                Button { onPick(sig) } label: {
                    Image(uiImage: sig.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 90)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4)))
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Choose a Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
            }
        }
    }
}
```

- [ ] **Step 2: Carry the signature id through placement**

In `DocumentViewerView`, the `PlacementRequest` struct currently has `signature: UIImage`, `page`,
`seedRect`, `replacing`. Add the id **with a default** (so the Task 1 Move construction, not yet
updated until Task 4, keeps compiling):

```swift
        var signatureID: String? = nil    // which saved signature this came from (for Move)
```
Place it right after `signature`. Because it's defaulted, existing `PlacementRequest(...)` calls
that omit it still compile, and callers that know the id pass `signatureID: sig.id`.

- [ ] **Step 3: Add picker state + drive Sign by count**

Add state near the other signature state:

```swift
    @State private var showingSignaturePicker = false
```

Replace the **Sign** button body with the count-based logic:

```swift
                Button("Sign") {
                    let sigs = signatureStore.all()
                    if sigs.isEmpty { showingSignCapture = true }
                    else if sigs.count == 1, let page = currentPageForSigning(session: session) {
                        placement = PlacementRequest(signature: sigs[0].image, signatureID: sigs[0].id,
                                                     page: page, seedRect: nil)
                    } else {
                        showingSignaturePicker = true
                    }
                }
```

Add the picker sheet (alongside the other `.sheet`s on the PDF-hosting view):

```swift
        .sheet(isPresented: $showingSignaturePicker) {
            SignaturePicker(
                signatures: signatureStore.all(),
                onPick: { sig in
                    showingSignaturePicker = false
                    if let page = currentPageForSigning(session: session) {
                        placement = PlacementRequest(signature: sig.image, signatureID: sig.id,
                                                     page: page, seedRect: nil)
                    }
                },
                onCancel: { showingSignaturePicker = false }
            )
        }
```

- [ ] **Step 4: Tag the annotation with the signature id on place**

Update `placeSignature` to accept and store the id, and update its call sites. Change the signature
of `placeSignature` to:

```swift
    private func placeSignature(_ image: UIImage, id: String?, at rect: CGRect, on page: PDFPage, session: DocumentSession) {
        let stamp = ImageStampAnnotation(image: image, bounds: rect,
                                         userName: DocumentSession.signatureAnnotationName)
        stamp.contents = id    // remember which saved signature this is, for Move
        page.addAnnotation(stamp)
        _ = try? session.save()
        annotationRevision &+= 1
        signatureRevision &+= 1
    }
```

In the placement sheet's `onPlace`, pass the id from the request:

```swift
                onPlace: { rect in
                    if let old = req.replacing { req.page.removeAnnotation(old) }
                    placeSignature(req.signature, id: req.signatureID, at: rect, on: req.page, session: session)
                    placement = nil
                },
```

Also update the **capture onSaved** (first-run) to build a `PlacementRequest` with the new
signature's id:

```swift
                onSaved: {
                    showingSignCapture = false
                    if let sig = signatureStore.all().first, let page = currentPageForSigning(session: session) {
                        placement = PlacementRequest(signature: sig.image, signatureID: sig.id,
                                                     page: page, seedRect: nil)
                    }
                },
```

- [ ] **Step 5: Add the id-persistence test**

In `DocumentScannerTests/SignatureAnnotationPersistenceTests.swift`, add:

```swift
    func test_signatureID_inContents_survivesRoundTrip() throws {
        let pdf = PDFDocument(); let page = PDFPage(); pdf.insert(page, at: 0)
        let stamp = ImageStampAnnotation(
            image: solidImage(.black, CGSize(width: 80, height: 30)),
            bounds: CGRect(x: 20, y: 20, width: 80, height: 30),
            userName: "DocumentScanner.signature")
        stamp.contents = "sig-id-123"
        page.addAnnotation(stamp)

        let data = try XCTUnwrap(pdf.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        let anno = try XCTUnwrap(reloaded.page(at: 0)?.annotations.first {
            $0.userName == "DocumentScanner.signature"
        })
        XCTAssertEqual(anno.contents, "sig-id-123", "signature id must survive in contents for Move")
    }
```

- [ ] **Step 6: Build + run the persistence tests**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/SignatureAnnotationPersistenceTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`. If `contents` does NOT survive the
round-trip, STOP and report — Move would need a different id channel (e.g. a custom annotation key);
do not silently proceed.

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignaturePicker.swift \
        DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift \
        DocumentScanner/DocumentScannerTests/SignatureAnnotationPersistenceTests.swift
git commit -m "feat: Sign picker for 2+ signatures; tag placed annotation with its signature id"
```

---

## Task 4: Move re-places the same signature (by id), with picker fallback

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`

- [ ] **Step 1: Resolve the source signature by id in Move**

Replace the **Move** button body (in the `.alert("Signature", …)` actions) with:

```swift
            Button("Move") {
                // Re-place the SAME signature: read its id off the annotation and
                // reload that image. If it was deleted (or has no id), fall back to
                // the picker so the move still works.
                let id = item.annotation.contents
                if let sig = id.flatMap({ signatureStore.signature(withID: $0) }) {
                    placement = PlacementRequest(signature: sig.image, signatureID: sig.id,
                                                 page: item.page, seedRect: item.annotation.bounds,
                                                 replacing: item.annotation)
                    pendingSignatureEdit = nil
                } else {
                    moveTarget = item                 // remember what we're moving
                    pendingSignatureEdit = nil
                    showingMovePicker = true
                }
            }
```

- [ ] **Step 2: Add the move-fallback state + picker**

Add state:

```swift
    @State private var showingMovePicker = false
    @State private var moveTarget: SignatureEdit?
```

Add the fallback picker sheet (near the other sheets):

```swift
        .sheet(isPresented: $showingMovePicker) {
            SignaturePicker(
                signatures: signatureStore.all(),
                onPick: { sig in
                    showingMovePicker = false
                    if let target = moveTarget {
                        placement = PlacementRequest(signature: sig.image, signatureID: sig.id,
                                                     page: target.page, seedRect: target.annotation.bounds,
                                                     replacing: target.annotation)
                    }
                    moveTarget = nil
                },
                onCancel: { showingMovePicker = false; moveTarget = nil }
            )
        }
```

(`SignatureEdit` already exists as a private `Identifiable` struct with `annotation` + `page`.)

- [ ] **Step 3: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
git commit -m "feat: Move re-places the same signature by id (picker fallback if deleted)"
```

---

## Task 5: Full suite + roadmap

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Full unit suite (no regressions)**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Update the roadmap**

In `docs/FutureEnhancements.md`, under the Signing section, note **multiple signatures shipped**
and that the remaining 2.x follow-ups are now: **iCloud sync** (storage is kept sync-ready),
**names/labels**, **reordering**, typed/drawn signatures, and initials/date templates.

- [ ] **Step 3: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: record multiple signatures shipped; trim Signing follow-ups"
```

---

## Done

After Task 5: the user can keep several signatures (Settings shows a list with swipe-to-delete +
Add), choose which to place when signing (picker for 2+, direct for one), and Move re-places the
same signature (by id, with a picker fallback if it was deleted). An existing single signature is
migrated into the collection automatically. iCloud sync stays a clean future add.

**On-device smoke test (manual):**
1. Settings ▸ Signature → **Add** two or three signatures → each shows as a thumbnail; **swipe** one to delete it.
2. Open a doc ▸ **Sign** with 2+ signatures → the **picker** appears → choose one → place it.
3. Single signature only → **Sign** places it directly (no picker).
4. No signatures → **Sign** routes to capture, then places it.
5. **Move** a placed signature → it re-places the **same** one. Delete that signature in Settings, then Move a doc still showing it → the **picker** appears (fallback).
6. Upgrade check: a user who had one signature before still has it (migrated) and signing works.

Ships in v2.x. iCloud sync, names, and reordering remain the Signing follow-ups.
