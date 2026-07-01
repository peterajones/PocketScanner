# Signature Names Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each saved signature an optional name, edited via tap-to-rename in Settings and shown in the "Choose a Signature" picker.

**Architecture:** Names persist in a single `names.json` sidecar (`[id: name]`) in the existing Signature directory; the `<uuid>.png` files and their newest-first order are untouched. `SignatureStore` gains name load + a `rename(id:to:)` writer and prunes the sidecar on `remove`. Two SwiftUI touch points render the name.

**Tech Stack:** Swift, SwiftUI, XCTest. iOS app `DocumentScanner`.

---

## File Structure

- `DocumentScanner/DocumentScanner/Signature/Signature.swift` — add `name: String?`.
- `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift` — sidecar load/save, `rename(id:to:)`, prune on `remove`, attach name in `all()` + `signature(withID:)`.
- `DocumentScanner/DocumentScanner/Settings/SettingsView.swift` — compact tappable row + rename alert.
- `DocumentScanner/DocumentScanner/Signature/SignaturePicker.swift` — name caption under each thumbnail.
- `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift` — new store test cases.

Run the full suite at any point with `./scripts/test.sh` (from repo root). Individual runs use the `xcodebuild` invocation shown in each task.

---

## Task 1: Add `name` to `Signature` and load names in the store

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Signature/Signature.swift`
- Modify: `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift`
- Test: `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `SignatureStoreTests`:

```swift
func test_all_noSidecar_namesAreNil() throws {
    let store = SignatureStore(directory: tempDir())
    _ = try store.add(image())
    XCTAssertNil(store.all().first?.name, "no sidecar ⇒ unnamed")
}

func test_all_attachesNameFromSidecar() throws {
    let dir = tempDir()
    let store = SignatureStore(directory: dir)
    let sig = try store.add(image())
    let json = try JSONEncoder().encode([sig.id: "Work"])
    try json.write(to: dir.appendingPathComponent("names.json"))
    XCTAssertEqual(store.all().first?.name, "Work")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/SignatureStoreTests/test_all_attachesNameFromSidecar`
Expected: FAIL — `Signature` has no member `name`.

- [ ] **Step 3: Add the `name` field**

Replace the body of `Signature.swift`:

```swift
import UIKit

/// One saved signature. `id` is the on-disk filename stem (a UUID), so the store
/// and placed annotations can reference a specific signature. `name` is an
/// optional user-supplied label (nil when unnamed).
struct Signature: Identifiable {
    let id: String
    let image: UIImage
    var name: String? = nil
}
```

- [ ] **Step 4: Load names in the store**

In `SignatureStore.swift`, add sidecar helpers (place above `migrateLegacyIfNeeded`):

```swift
private var namesURL: URL { directory.appendingPathComponent("names.json") }

/// id → name. Absent or unreadable sidecar ⇒ empty (all unnamed).
private func loadNames() -> [String: String] {
    guard let data = try? Data(contentsOf: namesURL),
          let dict = try? JSONDecoder().decode([String: String].self, from: data)
    else { return [:] }
    return dict
}

private func saveNames(_ names: [String: String]) {
    guard let data = try? JSONEncoder().encode(names) else { return }
    try? data.write(to: namesURL, options: .atomic)
}
```

In `all()`, load names once and attach. Change the final `return` block:

```swift
func all() -> [Signature] {
    migrateLegacyIfNeeded()
    let names = loadNames()
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
        let id = url.deletingPathExtension().lastPathComponent
        return Signature(id: id, image: img, name: names[id])
    }
}
```

In `signature(withID:)`, attach the name:

```swift
func signature(withID id: String) -> Signature? {
    let url = directory.appendingPathComponent("\(id).png")
    guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
    return Signature(id: id, image: img, name: loadNames()[id])
}
```

(`add(_:)`'s `return Signature(id: id, image: image)` needs no change — `name` defaults to nil. Newly captured signatures are unnamed. `names.json` is not a `.png`, so it is never mistaken for a signature by the `.png` filter.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/SignatureStoreTests`
Expected: PASS (existing cases + the two new ones).

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/Signature.swift \
        DocumentScanner/DocumentScanner/Signature/SignatureStore.swift \
        DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift
git commit -m "feat: load optional signature names from a names.json sidecar

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `rename(id:to:)` — write, overwrite, clear

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift`
- Test: `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/SignatureStoreTests/test_rename_setsName_roundTrips`
Expected: FAIL — no member `rename`.

- [ ] **Step 3: Implement `rename`**

Add to `SignatureStore` (below `remove`):

```swift
/// Sets or clears a signature's name. A blank/whitespace-only name removes the
/// entry (reverts to unnamed). Name is trimmed before saving.
func rename(id: String, to newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    var names = loadNames()
    if trimmed.isEmpty {
        names.removeValue(forKey: id)
    } else {
        names[id] = trimmed
    }
    saveNames(names)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/SignatureStoreTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignatureStore.swift \
        DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift
git commit -m "feat: SignatureStore.rename sets, overwrites, and clears names

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Prune the sidecar on `remove` (+ stale-id robustness)

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Signature/SignatureStore.swift`
- Test: `DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func test_remove_prunesNameFromSidecar() throws {
    let dir = tempDir()
    let store = SignatureStore(directory: dir)
    let a = try store.add(image())
    store.rename(id: a.id, to: "Work")
    store.remove(id: a.id)
    // A new signature reuses no ids (UUIDs), and the old name must not linger.
    let b = try store.add(image())
    XCTAssertNil(store.all().first(where: { $0.id == b.id })?.name)
    // And the pruned id is gone from the sidecar contents.
    if let data = try? Data(contentsOf: dir.appendingPathComponent("names.json")),
       let dict = try? JSONDecoder().decode([String: String].self, from: data) {
        XCTAssertNil(dict[a.id], "removed signature's name pruned")
    }
}

func test_all_ignoresSidecarEntriesWithNoPng() throws {
    let dir = tempDir()
    let store = SignatureStore(directory: dir)
    let sig = try store.add(image())
    let json = try JSONEncoder().encode([sig.id: "Work", "ghost-id": "Nobody"])
    try json.write(to: dir.appendingPathComponent("names.json"))
    let all = store.all()
    XCTAssertEqual(all.count, 1, "ghost entry adds no signature")
    XCTAssertEqual(all.first?.name, "Work")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/SignatureStoreTests/test_remove_prunesNameFromSidecar`
Expected: FAIL — the name entry survives (`dict[a.id]` non-nil). (`test_all_ignoresSidecarEntriesWithNoPng` may already pass, since `all()` iterates PNGs; keep it as a regression guard.)

- [ ] **Step 3: Prune on `remove`**

Replace `remove(id:)` in `SignatureStore`:

```swift
func remove(id: String) {
    try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).png"))
    var names = loadNames()
    if names.removeValue(forKey: id) != nil {
        saveNames(names)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DocumentScannerTests/SignatureStoreTests`
Expected: PASS (all store tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignatureStore.swift \
        DocumentScanner/DocumentScannerTests/SignatureStoreTests.swift
git commit -m "feat: prune signature name from sidecar on remove

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Settings — compact tappable row + rename alert

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Settings/SettingsView.swift`

No unit test (SwiftUI view wiring; verified in the on-device smoke test). Build must succeed and the full suite must stay green.

- [ ] **Step 1: Add rename state**

Near the other `@State` at the top of `SettingsView` (alongside `signatures`, `showingSignatureCapture`):

```swift
@State private var renamingID: String?
@State private var renameField = ""
```

- [ ] **Step 2: Replace the signature row + Add button**

Replace the `ForEach(signatures) { ... }` row (the full-width `Image(...)` with its `.swipeActions`) with the compact tappable row:

```swift
ForEach(signatures) { sig in
    HStack(spacing: 12) {
        Image(uiImage: sig.image)
            .resizable()
            .scaledToFit()
            .frame(width: 56, height: 32)
            .padding(6)
            .background(Color.white)   // black ink on transparent — visible in dark mode
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
        if let name = sig.name, !name.isEmpty {
            Text(name).lineLimit(1).truncationMode(.tail)
        } else {
            Text("Add a name").foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
    .onTapGesture { beginRename(sig) }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
            signatureStore.remove(id: sig.id)
            signatures = signatureStore.all()
        } label: { Label("Delete", systemImage: "trash") }
    }
}
Button("Add Signature") { showingSignatureCapture = true }
```

- [ ] **Step 3: Add the rename alert**

Attach after the existing `.sheet(isPresented: $showingSignatureCapture) { ... }` modifier on the list:

```swift
.alert("Rename Signature",
       isPresented: Binding(
        get: { renamingID != nil },
        set: { if !$0 { renamingID = nil } }
       )) {
    TextField("Name", text: $renameField)
        .autocorrectionDisabled()
        .onChange(of: renameField) { _, new in
            if new.count > 40 { renameField = String(new.prefix(40)) }
        }
    Button("Rename") { commitRename() }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Give this signature a name so you can tell it apart when signing.")
}
```

- [ ] **Step 4: Add the helper methods**

Add inside `SettingsView` (e.g. below `body`):

```swift
private func beginRename(_ sig: Signature) {
    renameField = sig.name ?? ""
    renamingID = sig.id
}

private func commitRename() {
    guard let id = renamingID else { return }
    signatureStore.rename(id: id, to: renameField)
    signatures = signatureStore.all()
    renamingID = nil
}
```

- [ ] **Step 5: Build to verify it compiles**

Run: `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/Settings/SettingsView.swift
git commit -m "feat: tap a signature row in Settings to rename it

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Picker — show the name under each thumbnail

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Signature/SignaturePicker.swift`

- [ ] **Step 1: Add a name caption**

Replace `pickerList`'s row (`Button { onPick(sig) } label: { Image(...) }`) with a captioned version:

```swift
private var pickerList: some View {
    List(signatures) { sig in
        Button { onPick(sig) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(uiImage: sig.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 90)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4)))
                if let name = sig.name, !name.isEmpty {
                    Text(name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Signature/SignaturePicker.swift
git commit -m "feat: show signature name under thumbnail in the picker

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Update roadmap doc + full-suite verification

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Mark the roadmap item shipped**

In `docs/FutureEnhancements.md`, under Signing, replace the `**Signature names/labels + reordering (v2.3)**` bullet with a shipped/struck version noting names shipped and reordering dropped. Example:

```markdown
- ~~**Signature names (v2.3)**~~ — **Shipped.** Each saved signature takes an
  optional name (edited by tapping its row in Settings → Rename alert), shown
  under the thumbnail in the "Choose a Signature" picker so multiple signatures
  are distinguishable at signing time. Names persist in a `names.json` sidecar
  (`[id: name]`) beside the PNGs. **Reordering was dropped** — with 2–3
  signatures a custom order is marginal; order stays creation-date, newest first.
```

- [ ] **Step 2: Run the full suite**

Run: `./scripts/test.sh`
Expected: summary shows `Passed: <n>  Failed: 0` (n = 177 + the new store tests).

- [ ] **Step 3: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: mark signature names shipped (v2.3); reordering dropped

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 4: On-device smoke test (manual, at release time)**

Before archiving v2.3 (21): capture/have 2 signatures, name one via Settings tap-to-rename, confirm the name and the "Add a name" placeholder render, delete a named signature and confirm no stale label, then sign a document and confirm the name shows in the picker. Version bump to 2.3 (21) happens at archive (main currently reads 2.2 / 20).

---

## Notes for the implementer

- Swift's memberwise init: because `name` has a default (`= nil`), existing `Signature(id:image:)` call sites keep compiling; only `all()` and `signature(withID:)` pass a name.
- The 40-char cap is UI-only (truncate-on-entry in the rename `TextField`); the store just trims whitespace. No store test covers the cap.
- Do not add names to the capture flow — capture stays a single-shot, no-prompt path by design.
