# Tips Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a findable **Tips** screen (Settings ▸ About ▸ Tips) with six short tips — five everyday tricks plus the decided highlights/handwriting expectation-setter — built so more tips are a one-line append.

**Architecture:** Tip content is pure data (`Tip` value + static `Tip.all`) in its own file, unit-tested. `TipsView` renders `Tip.all` as a `List` of `Section`s (title = header, body = content). `SettingsView` gains one `NavigationLink` row.

**Tech Stack:** Swift, SwiftUI (`Form`/`List`/`Section`, `NavigationLink`), XCTest.

**Spec:** `docs/superpowers/specs/2026-06-19-tips-screen-design.md`

---

## File Structure

- Create: `DocumentScanner/DocumentScanner/Settings/Tip.swift` — `Tip` model + static `Tip.all` (pure content). (The spec sketched this inside `TipsView.swift`; splitting the pure data into its own file matches the codebase pattern — `SearchMatcher.swift`, `DocumentSort.swift` — and makes it unit-testable.)
- Create: `DocumentScanner/DocumentScanner/Settings/TipsView.swift` — the view.
- Create: `DocumentScanner/DocumentScannerTests/TipTests.swift` — pure-data assertions.
- Modify: `DocumentScanner/DocumentScanner/Settings/SettingsView.swift` — add the About-section "Tips" row.
- Modify: `docs/FutureEnhancements.md` — remove the now-resolved highlighter item (on merge).

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

## Task 1: `Tip` model + content (pure, tested)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Settings/Tip.swift`
- Test: `DocumentScanner/DocumentScannerTests/TipTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DocumentScanner/DocumentScannerTests/TipTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class TipTests: XCTestCase {

    func test_all_isNonEmpty() {
        XCTAssertFalse(Tip.all.isEmpty)
    }

    func test_all_haveUniqueIDs() {
        XCTAssertEqual(Set(Tip.all.map(\.id)).count, Tip.all.count, "tip ids must be unique")
    }

    func test_all_haveNonEmptyTitleAndBody() {
        for tip in Tip.all {
            XCTAssertFalse(tip.title.isEmpty, "tip \(tip.id) has an empty title")
            XCTAssertFalse(tip.body.isEmpty, "tip \(tip.id) has an empty body")
        }
    }

    func test_highlightsTip_isPresent() {
        XCTAssertTrue(Tip.all.contains { $0.id == "highlights" },
                      "the highlights/handwriting note is the reason this screen exists")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/TipTests 2>&1 | grep -E "Cannot find|error:|\*\* TEST" | tail -5
```
Expected: FAIL — "Cannot find 'Tip' in scope".

- [ ] **Step 3: Implement `Tip` + `Tip.all`**

Create `DocumentScanner/DocumentScanner/Settings/Tip.swift`:

```swift
import Foundation

/// A single in-app tip shown on the Tips screen. Pure content (no UI), so the
/// copy is unit-testable and new tips are added by appending to `all`.
struct Tip: Identifiable {
    let id: String
    let title: String
    let body: String
}

extension Tip {
    /// Tips in display order: everyday tricks first, the highlights caveat last.
    static let all: [Tip] = [
        Tip(id: "search",
            title: "Search inside your scans",
            body: "Search reads the text inside every scan, even ones filed in folders. Tap a result to jump straight to the highlighted match."),
        Tip(id: "swipe-delete",
            title: "Swipe to delete",
            body: "Swipe left on any document or folder to remove it."),
        Tip(id: "grid",
            title: "See your scans as thumbnails",
            body: "Tap the layout button in the toolbar to switch between a list and a thumbnail grid of your library."),
        Tip(id: "extract",
            title: "Split out pages",
            body: "In a document's edit mode, select pages and tap Save as New to pull them into their own scan."),
        Tip(id: "flat-list",
            title: "One big list",
            body: "Prefer everything in one place? Turn off Show Folders in Settings and every scan lives in a single list."),
        Tip(id: "highlights",
            title: "Highlights & handwriting",
            body: "Highlights snap to the text Pocket Scanner detects in your scan. On printed pages that's precise; on handwriting or rough scans, text detection is looser — so a highlight may sit a bit tall or not line up exactly. Your scan itself is never altered."),
    ]
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/TipTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Settings/Tip.swift \
        DocumentScanner/DocumentScannerTests/TipTests.swift
git commit -m "feat: Tip model + content (pure, tested)"
```

---

## Task 2: `TipsView` + Settings row

**Files:**
- Create: `DocumentScanner/DocumentScanner/Settings/TipsView.swift`
- Modify: `DocumentScanner/DocumentScanner/Settings/SettingsView.swift`

- [ ] **Step 1: Create `TipsView`**

Create `DocumentScanner/DocumentScanner/Settings/TipsView.swift`:

```swift
import SwiftUI

/// A findable list of short in-app tips, reached from Settings ▸ About ▸ Tips.
/// Content lives in `Tip.all`; this view only renders it.
struct TipsView: View {
    var body: some View {
        List {
            ForEach(Tip.all) { tip in
                Section {
                    Text(tip.body)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(tip.title)
                }
            }
        }
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Add the "Tips" row to Settings' About section**

In `DocumentScanner/DocumentScanner/Settings/SettingsView.swift`, replace the existing About
section (currently):

```swift
            Section("About") {
                AboutRow()
                SendFeedbackRow()
            }
```

with:

```swift
            Section("About") {
                NavigationLink {
                    TipsView()
                } label: {
                    Label("Tips", systemImage: "lightbulb")
                }
                AboutRow()
                SendFeedbackRow()
            }
```

(`SettingsView` is pushed within the library's `NavigationStack`, so this `NavigationLink`
pushes `TipsView` onto that stack.)

- [ ] **Step 3: Build**

```bash
cd DocumentScanner && xcodebuild build -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScanner/Settings/TipsView.swift \
        DocumentScanner/DocumentScanner/Settings/SettingsView.swift
git commit -m "feat: Tips screen + Settings ▸ About ▸ Tips row"
```

---

## Task 3: Full suite + roadmap cleanup

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Run the full unit suite (no regressions)**

```bash
cd DocumentScanner && xcodebuild test -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests 2>&1 | grep -E "\*\* TEST|failed" | tail -5
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Remove the now-resolved highlighter roadmap item**

The "Highlighter thickness / bleed" item's two halves are now both shipped: the demo-seeder
tighten (v1.9) and the in-app clarify note (this Tips screen). In `docs/FutureEnhancements.md`,
delete the entire **"Highlighter thickness / bleed"** bullet from the `### Editing` section.
Leave the other Editing items intact.

- [ ] **Step 3: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: drop resolved highlighter item (clarify note shipped via Tips)"
```

---

## Done

After Task 3: Settings ▸ About has a **Tips** row that opens a six-tip screen (Search, Swipe to
delete, Grid view, Split out pages, One big list, Highlights & handwriting); the content is pure
data (`Tip.all`, unit-tested) and adding a tip is a one-line append. The highlighter roadmap item
is fully resolved and removed.

**On-device smoke test (manual):**
1. Settings ▸ About ▸ **Tips** → the screen lists all six tips; each title/body reads correctly.
2. Back navigation returns to Settings cleanly; the row sits in the About section with a lightbulb.
3. (DEBUG build) Settings still shows the Developer section above About — unchanged.

Ships in the next release after v1.10.
