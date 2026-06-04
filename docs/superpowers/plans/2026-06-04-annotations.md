# Annotations (Highlight + Strikethrough) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users select text in the viewer and apply a coloured highlight or a red strikethrough, tap a mark to delete it, with marks persisted into the PDF.

**Architecture:** Pure, testable model pieces (`AnnotationColor`, `AnnotationFactory`) build per-line `PDFAnnotation`s from a `PDFSelection` (reusing the search-highlight `selectionsByLine()` pattern). `DocumentSession.save()` is refactored to strip only *search-tagged* highlights so user marks persist. The viewer's `PDFKitView` swaps its `PDFView` for a `MarkupPDFView` subclass that customizes the text-selection edit menu (highlight colours + strikethrough) and hit-tests taps for deletion.

**Tech Stack:** Swift, SwiftUI, PDFKit, UIKit (UIMenu/UIMenuBuilder), XCTest, xcodebuild.

---

## Conventions for this plan

- **Run tests** (from repo root):

  ```bash
  cd DocumentScanner && xcodebuild test \
    -scheme DocumentScanner \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:DocumentScannerTests/<ClassName>
  ```

  Full unit suite: `-only-testing:DocumentScannerTests` (no class). If `iPhone 17`
  isn't installed, run `xcrun simctl list devices available` and substitute.

- **SourceKit/LSP false positives:** "No such module 'UIKit'/'XCTest'/'PDFKit'"
  and "Cannot find type" diagnostics appear constantly in this project and are
  spurious. `xcodebuild` is the source of truth — never treat an editor diagnostic
  as a real error.

- **Synchronized file groups:** this project uses Xcode
  `PBXFileSystemSynchronizedRootGroup`, so any `.swift` file placed in the correct
  directory on disk is included in the target automatically. **Do NOT edit the
  `.pbxproj`** to add files. New non-test files go under
  `DocumentScanner/DocumentScanner/Annotations/`; tests go under
  `DocumentScanner/DocumentScannerTests/`.

- **Commit message trailer:** every commit ends with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

- **Two UI tests are known-broken in the simulator** (`GoldenPathTests`,
  `EditModeTests`) — they fail on a clean `main` too (the stubbed scanner flow
  doesn't complete in the simulator). Ignore them; rely on `DocumentScannerTests`
  (the unit bundle).

---

## File Structure

- **Create** `DocumentScanner/DocumentScanner/Annotations/AnnotationColor.swift` —
  the four highlight colours (enum, pure; `UIColor` + display name + raw value).
- **Create** `DocumentScanner/DocumentScanner/Annotations/AnnotationFactory.swift` —
  `AnnotationTool` enum + pure `annotations(for:tool:)` builder + `isUserDeletable(_:)`
  classifier. No SwiftUI.
- **Modify** `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift` — add
  `userAnnotationName`; refactor the save-time strip to remove only search-tagged
  highlights.
- **Modify** `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift` —
  swap `PDFView`→`MarkupPDFView`, add the edit-menu + tap-delete plumbing, and the
  apply/delete/confirm wiring.
- **Create** `DocumentScanner/DocumentScannerTests/AnnotationColorTests.swift`.
- **Create** `DocumentScanner/DocumentScannerTests/AnnotationFactoryTests.swift`.
- **Modify** `DocumentScanner/DocumentScannerTests/DocumentSessionStripHighlightsTests.swift`
  — update strip semantics + add persistence regression.

---

## Task 1: `AnnotationColor`

**Files:**
- Create: `DocumentScanner/DocumentScanner/Annotations/AnnotationColor.swift`
- Test: `DocumentScanner/DocumentScannerTests/AnnotationColorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DocumentScanner/DocumentScannerTests/AnnotationColorTests.swift`:

```swift
import XCTest
import UIKit
@testable import DocumentScanner

final class AnnotationColorTests: XCTestCase {

    func test_allCases_areTheFourPaletteColours() {
        XCTAssertEqual(AnnotationColor.allCases, [.yellow, .green, .pink, .blue])
    }

    func test_rawValues_roundTrip() {
        for color in AnnotationColor.allCases {
            XCTAssertEqual(AnnotationColor(rawValue: color.rawValue), color)
        }
    }

    func test_uiColors_areTranslucentAndPairwiseDistinct() {
        let colors = AnnotationColor.allCases.map(\.uiColor)
        // Translucent so the scan shows through.
        for c in colors {
            var alpha: CGFloat = 0
            c.getRed(nil, green: nil, blue: nil, alpha: &alpha)
            XCTAssertLessThan(alpha, 1.0, "highlight colour should be translucent")
        }
        // Pairwise distinct.
        for i in colors.indices {
            for j in colors.indices where j > i {
                XCTAssertFalse(colors[i].isApproximately(colors[j]),
                               "palette colours must be visually distinct")
            }
        }
    }

    func test_displayNames() {
        XCTAssertEqual(AnnotationColor.yellow.displayName, "Yellow")
        XCTAssertEqual(AnnotationColor.green.displayName, "Green")
        XCTAssertEqual(AnnotationColor.pink.displayName, "Pink")
        XCTAssertEqual(AnnotationColor.blue.displayName, "Blue")
    }
}

private extension UIColor {
    /// Compares RGBA components within a small tolerance.
    func isApproximately(_ other: UIColor) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.05 && abs(g1 - g2) < 0.05
            && abs(b1 - b2) < 0.05 && abs(a1 - a2) < 0.05
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/AnnotationColorTests
```
Expected: FAIL to compile — "Cannot find 'AnnotationColor' in scope".

- [ ] **Step 3: Write the implementation**

Create `DocumentScanner/DocumentScanner/Annotations/AnnotationColor.swift`:

```swift
import UIKit

/// The fixed highlight palette. Translucent so the scanned page shows through.
enum AnnotationColor: String, CaseIterable {
    case yellow
    case green
    case pink
    case blue

    var uiColor: UIColor {
        switch self {
        case .yellow: return UIColor.systemYellow.withAlphaComponent(0.4)
        case .green:  return UIColor.systemGreen.withAlphaComponent(0.4)
        case .pink:   return UIColor.systemPink.withAlphaComponent(0.4)
        case .blue:   return UIColor.systemBlue.withAlphaComponent(0.4)
        }
    }

    var displayName: String {
        switch self {
        case .yellow: return "Yellow"
        case .green:  return "Green"
        case .pink:   return "Pink"
        case .blue:   return "Blue"
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/AnnotationColorTests
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Annotations/AnnotationColor.swift \
        DocumentScanner/DocumentScannerTests/AnnotationColorTests.swift
git commit -m "feat: add AnnotationColor highlight palette"
```

---

## Task 2: `DocumentSession` — persist user marks

Add the user-annotation tag and refactor the save-time strip to remove only
*search-tagged* highlights (so user highlights and strikethroughs survive). Update
the strip test to the new semantics and add a persistence regression.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift`
- Test: `DocumentScanner/DocumentScannerTests/DocumentSessionStripHighlightsTests.swift`

- [ ] **Step 1: Rewrite the strip test for the new semantics**

Replace the ENTIRE contents of
`DocumentScanner/DocumentScannerTests/DocumentSessionStripHighlightsTests.swift`
with:

```swift
import XCTest
import PDFKit
@testable import DocumentScanner

@MainActor
final class DocumentSessionStripHighlightsTests: XCTestCase {

    /// New semantics: save() strips only annotations tagged as SEARCH highlights.
    /// User marks (highlight + strikethrough) and other annotations survive.
    func test_save_stripsOnlySearchHighlights() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: image, observations: [])],
            createdAt: Date()
        )
        let storage = DocumentStorage(documentsURL: tempDir)
        let initialURL = try storage.write(pdf, preferredName: "Test")
        let summary = DocumentSummary(url: initialURL, displayName: "Test",
                                      createdAt: Date(), pageCount: 1, ocrSnippet: "",
                                      isCorrupt: false)
        let session = try DocumentSession(summary: summary, storage: storage)

        let page = try XCTUnwrap(session.pdf.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)

        // (a) A SEARCH highlight — must be stripped.
        let searchHL = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        searchHL.userName = DocumentSession.searchHighlightAnnotationName
        page.addAnnotation(searchHL)

        // (b) A USER highlight — must survive.
        let userHL = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        userHL.userName = DocumentSession.userAnnotationName
        page.addAnnotation(userHL)

        // (c) A USER strikethrough — must survive.
        let userStrike = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
        userStrike.userName = DocumentSession.userAnnotationName
        page.addAnnotation(userStrike)

        _ = try session.save()

        let reloaded = try XCTUnwrap(PDFDocument(url: initialURL))
        let reloadedPage = try XCTUnwrap(reloaded.page(at: 0))
        let types = reloadedPage.annotations.map(\.type)

        XCTAssertEqual(types.filter { $0 == "Highlight" }.count, 1,
                       "exactly the user highlight should survive; search highlight stripped. types: \(types)")
        XCTAssertTrue(types.contains("StrikeOut"),
                      "user strikethrough should survive. types: \(types)")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/DocumentSessionStripHighlightsTests
```
Expected: FAIL — `userAnnotationName` doesn't exist yet ("Type 'DocumentSession'
has no member 'userAnnotationName'"), and/or the assertion fails because the
current strip removes ALL highlights.

- [ ] **Step 3: Add the constant and refactor the strip**

In `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift`, find:

```swift
    /// Annotation `userName` that marks PDFAnnotations added by the search-highlight
    /// view layer. `save()` strips these before writing so they don't persist.
    static let searchHighlightAnnotationName = "DocumentScanner.searchHighlight"
```

Add the new constant directly below it:

```swift
    /// Annotation `userName` that marks PDFAnnotations the USER created
    /// (highlights / strikethroughs). These persist across save.
    static let userAnnotationName = "DocumentScanner.userAnnotation"
```

Then replace the entire `stripSearchHighlightAnnotations()` method:

```swift
    private func stripSearchHighlightAnnotations() {
        // We rely on annotation type rather than the userName tag because
        // PDFKit doesn't reliably preserve userName on .highlight subtypes
        // through the page's annotation lifecycle. Since the app doesn't add
        // any non-search highlight annotations of its own, removing every
        // .highlight is safe — if that ever changes, fall back to userName
        // tagging or track our annotations explicitly.
        //
        // Note: PDFAnnotation.type returns the subtype string without the
        // leading slash ("Highlight"), while PDFAnnotationSubtype.highlight
        // .rawValue includes it ("/Highlight"). Compare against the bare
        // form.
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            let toRemove = page.annotations.filter { $0.type == "Highlight" }
            for annotation in toRemove {
                page.removeAnnotation(annotation)
            }
        }
    }
```

with:

```swift
    private func stripSearchHighlightAnnotations() {
        // Remove ONLY the ephemeral search highlights, identified by the tag
        // the view layer sets. Search highlights are added in-session by
        // PDFKitView and never loaded from disk, so their userName is always
        // freshly set and reliable here (the same in-session reliability
        // PDFKitView.removeOurAnnotations already depends on). User marks
        // (highlights / strikethroughs) are not search-tagged, so they survive
        // and persist into the saved PDF.
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            let toRemove = page.annotations.filter {
                $0.userName == Self.searchHighlightAnnotationName
            }
            for annotation in toRemove {
                page.removeAnnotation(annotation)
            }
        }
    }
```

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/DocumentSessionStripHighlightsTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift \
        DocumentScanner/DocumentScannerTests/DocumentSessionStripHighlightsTests.swift
git commit -m "feat: persist user annotations; strip only search highlights on save"
```

---

## Task 3: `AnnotationTool` + `AnnotationFactory`

Pure builder that turns a `PDFSelection` + tool into per-line `PDFAnnotation`s,
plus the delete classifier.

**Files:**
- Create: `DocumentScanner/DocumentScanner/Annotations/AnnotationFactory.swift`
- Test: `DocumentScanner/DocumentScannerTests/AnnotationFactoryTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DocumentScanner/DocumentScannerTests/AnnotationFactoryTests.swift`:

```swift
import XCTest
import PDFKit
import UIKit
@testable import DocumentScanner

final class AnnotationFactoryTests: XCTestCase {

    /// Builds a 1-page PDF with one OCR observation so findString returns a
    /// real PDFSelection to annotate.
    private func pdfWithSelection(_ needle: String) throws -> (PDFDocument, PDFSelection) {
        let pageSize = CGSize(width: 612, height: 792)
        let normalized = CGRect(x: 0.1, y: 0.25, width: 0.6, height: 0.03)
        let observation = OCRObservation(string: needle, boundingBox: normalized)
        let image = UIGraphicsImageRenderer(size: pageSize).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pageSize))
        }
        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: image, observations: [observation])],
            createdAt: Date()
        )
        let selection = try XCTUnwrap(
            pdf.findString(needle, withOptions: .caseInsensitive).first,
            "expected a selection for the needle"
        )
        return (pdf, selection)
    }

    func test_highlight_producesHighlightAnnotationsTaggedAsUser() throws {
        let (_, selection) = try pdfWithSelection("Annotate me")
        let made = AnnotationFactory.annotations(for: selection, tool: .highlight(.yellow))
        XCTAssertFalse(made.isEmpty, "expected at least one annotation")
        for (_, annotation) in made {
            XCTAssertEqual(annotation.type, "Highlight")
            XCTAssertEqual(annotation.userName, DocumentSession.userAnnotationName)
            XCTAssertNotNil(annotation.color)
        }
    }

    func test_strikethrough_producesStrikeOutAnnotations() throws {
        let (_, selection) = try pdfWithSelection("Strike me")
        let made = AnnotationFactory.annotations(for: selection, tool: .strikethrough)
        XCTAssertFalse(made.isEmpty)
        for (_, annotation) in made {
            XCTAssertEqual(annotation.type, "StrikeOut")
            XCTAssertEqual(annotation.userName, DocumentSession.userAnnotationName)
        }
    }

    func test_differentColours_produceDifferentAnnotationColours() throws {
        let (_, selection) = try pdfWithSelection("Colour me")
        let yellow = AnnotationFactory.annotations(for: selection, tool: .highlight(.yellow)).first
        let blue = AnnotationFactory.annotations(for: selection, tool: .highlight(.blue)).first
        let yColor = try XCTUnwrap(yellow?.annotation.color)
        let bColor = try XCTUnwrap(blue?.annotation.color)
        XCTAssertNotEqual(yColor, bColor)
    }

    func test_isUserDeletable_classification() {
        let bounds = CGRect(x: 0, y: 0, width: 10, height: 10)

        // Highlight loaded from disk (no userName) → deletable.
        let loadedHL = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        XCTAssertTrue(AnnotationFactory.isUserDeletable(loadedHL))

        // Strikethrough → deletable.
        let strike = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
        XCTAssertTrue(AnnotationFactory.isUserDeletable(strike))

        // Search-tagged highlight → NOT deletable.
        let searchHL = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        searchHL.userName = DocumentSession.searchHighlightAnnotationName
        XCTAssertFalse(AnnotationFactory.isUserDeletable(searchHL))

        // A non-mark annotation (free text) → NOT deletable.
        let note = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        XCTAssertFalse(AnnotationFactory.isUserDeletable(note))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/AnnotationFactoryTests
```
Expected: FAIL to compile — "Cannot find 'AnnotationFactory' in scope".

- [ ] **Step 3: Write the implementation**

Create `DocumentScanner/DocumentScanner/Annotations/AnnotationFactory.swift`:

```swift
import PDFKit
import UIKit

/// A markup tool the user can apply to a text selection.
enum AnnotationTool: Equatable {
    case highlight(AnnotationColor)
    case strikethrough
}

/// Builds the PDFAnnotations for a tool applied to a selection, and classifies
/// whether a tapped annotation is a user mark the user may delete. Pure — no
/// SwiftUI, no view state.
enum AnnotationFactory {

    /// Solid red line for strikethroughs — conventional "done / no longer needed".
    static let strikethroughColor = UIColor.systemRed

    /// One annotation per visual line of the selection (mirrors the search-
    /// highlight rendering). Empty-bounds lines are skipped. Each annotation is
    /// tagged with `DocumentSession.userAnnotationName` so it persists.
    static func annotations(
        for selection: PDFSelection,
        tool: AnnotationTool
    ) -> [(page: PDFPage, annotation: PDFAnnotation)] {
        var result: [(page: PDFPage, annotation: PDFAnnotation)] = []
        for lineSelection in selection.selectionsByLine() {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard !bounds.isEmpty else { continue }

                let annotation: PDFAnnotation
                switch tool {
                case .highlight(let color):
                    annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                    annotation.color = color.uiColor
                case .strikethrough:
                    annotation = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
                    annotation.color = strikethroughColor
                }
                annotation.userName = DocumentSession.userAnnotationName
                result.append((page, annotation))
            }
        }
        return result
    }

    /// True for marks the user created and may delete. Keyed on SUBTYPE (not the
    /// user tag) so marks loaded from disk — whose userName may not round-trip —
    /// are still recognised. In-session search highlights are excluded by tag.
    static func isUserDeletable(_ annotation: PDFAnnotation) -> Bool {
        let isMarkSubtype = annotation.type == "Highlight" || annotation.type == "StrikeOut"
        return isMarkSubtype && annotation.userName != DocumentSession.searchHighlightAnnotationName
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests/AnnotationFactoryTests
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Annotations/AnnotationFactory.swift \
        DocumentScanner/DocumentScannerTests/AnnotationFactoryTests.swift
git commit -m "feat: add AnnotationFactory (build marks + delete classifier)"
```

---

## Task 4: Viewer integration (`MarkupPDFView` + wiring)

Swap the viewer's `PDFView` for a `MarkupPDFView` that customizes the text-
selection edit menu (Highlight colours + Strikethrough) and hit-tests taps for
deletion, then wire apply/delete/confirm into `DocumentViewerView`. UI behaviour
(menu, tap-delete) is validated by the manual smoke test in Task 5; this task's
gate is a clean build.

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`

- [ ] **Step 0: Ensure UIKit is imported**

At the top of `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`,
confirm the imports include `UIKit` (the new `MarkupPDFView` uses
`UITapGestureRecognizer`, `UIMenu`, `UIAction`, `UIImage`, `UIMenuBuilder`, and
`UIGestureRecognizerDelegate`). The file currently reads:

```swift
import SwiftUI
import PDFKit
```

Add `import UIKit` so it reads:

```swift
import SwiftUI
import PDFKit
import UIKit
```

- [ ] **Step 1: Replace the `PDFKitView` struct with the markup-aware version**

In `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`, replace the
ENTIRE `private struct PDFKitView: UIViewRepresentable { … }` (currently the last
type in the file) with the following — it adds a `MarkupPDFView` subclass, the two
callbacks, and an `annotationRevision` refresh trigger:

```swift
private final class MarkupPDFView: PDFView {
    /// Called when the user picks a tool from the selection menu.
    var onMark: ((AnnotationTool, PDFSelection) -> Void)?
    /// Called when the user taps an existing, deletable mark.
    var onTapAnnotation: ((PDFAnnotation, PDFPage) -> Void)?

    private var didInstallTap = false

    func installTapIfNeeded() {
        guard !didInstallTap else { return }
        didInstallTap = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard currentSelection != nil else { return }

        let highlightActions = AnnotationColor.allCases.map { color in
            UIAction(title: color.displayName) { [weak self] _ in
                guard let self, let selection = self.currentSelection else { return }
                self.onMark?(.highlight(color), selection)
                self.clearSelection()
            }
        }
        let highlightMenu = UIMenu(title: "Highlight",
                                   image: UIImage(systemName: "highlighter"),
                                   children: highlightActions)
        let strikeAction = UIAction(title: "Strikethrough",
                                    image: UIImage(systemName: "strikethrough")) { [weak self] _ in
            guard let self, let selection = self.currentSelection else { return }
            self.onMark?(.strikethrough, selection)
            self.clearSelection()
        }
        let group = UIMenu(title: "", options: .displayInline,
                           children: [highlightMenu, strikeAction])
        builder.insertChild(group, atEndOfMenu: .standardEdit)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let viewPoint = gesture.location(in: self)
        guard let page = page(for: viewPoint, nearest: true) else { return }
        let pagePoint = convert(viewPoint, to: page)
        guard let annotation = page.annotation(at: pagePoint),
              AnnotationFactory.isUserDeletable(annotation) else { return }
        onTapAnnotation?(annotation, page)
    }
}

extension MarkupPDFView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let highlightedSelections: [PDFSelection]
    let currentSelection: PDFSelection?
    /// Bumped by the parent after add/delete to force a redraw of annotations.
    let annotationRevision: Int
    let onApplyTool: (AnnotationTool, PDFSelection) -> Void
    let onRequestDelete: (PDFAnnotation, PDFPage) -> Void

    /// Tag we attach to highlight annotations so we can remove the ones we
    /// added on the next update without disturbing any annotations that
    /// happened to be in the PDF already.
    private static let annotationUserName = DocumentSession.searchHighlightAnnotationName

    func makeUIView(context: Context) -> PDFView {
        let v = MarkupPDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.usePageViewController(false)
        v.installTapIfNeeded()
        return v
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard let view = view as? MarkupPDFView else { return }
        view.onMark = onApplyTool
        view.onTapAnnotation = onRequestDelete

        // PDFView.highlightedSelections doesn't reliably render on iOS — use
        // real PDFAnnotation highlights, which are guaranteed to draw.
        removeOurAnnotations(from: document)

        for match in highlightedSelections {
            let color: UIColor = (match == currentSelection)
                ? UIColor.systemBlue.withAlphaComponent(0.45)
                : UIColor.systemYellow.withAlphaComponent(0.45)
            addHighlight(for: match, color: color)
        }

        // PDFView doesn't automatically redraw when annotations on its
        // document change after the document was first assigned. Re-assigning
        // forces a refresh; we keep it unconditional rather than gated on
        // `view.document !== document` so highlight edits flow through.
        view.document = document

        if let currentSelection {
            view.go(to: currentSelection)
        }
    }

    private func removeOurAnnotations(from document: PDFDocument) {
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for annotation in page.annotations where annotation.userName == Self.annotationUserName {
                page.removeAnnotation(annotation)
            }
        }
    }

    private func addHighlight(for selection: PDFSelection, color: UIColor) {
        // selectionsByLine() splits a multi-line match into one selection per
        // line, each with a single bounding rect we can wrap in an annotation.
        for lineSelection in selection.selectionsByLine() {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard !bounds.isEmpty else { continue }
                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = color
                annotation.userName = Self.annotationUserName
                page.addAnnotation(annotation)
            }
        }
    }
}
```

- [ ] **Step 2: Add viewer state for the refresh counter and pending deletion**

In `DocumentViewerView`, find the `@State` block (currently ending with
`@State private var pendingJumpToLastMatch: Bool = false`) and add two entries:

```swift
    @State private var pendingJumpToLastMatch: Bool = false
    @State private var annotationRevision: Int = 0
    @State private var pendingDeletion: PendingDeletion?
```

Then add this nested type next to the existing `PageEditorContext` struct (just
below the `struct PageEditorContext { … }` declaration near the top of the view):

```swift
    private struct PendingDeletion: Identifiable {
        let id = UUID()
        let annotation: PDFAnnotation
        let page: PDFPage
    }
```

- [ ] **Step 3: Pass the new parameters to `PDFKitView` and add the confirm dialog**

In `loadedBody(session:)`, find the `PDFKitView( … )` call:

```swift
            PDFKitView(
                document: session.pdf,
                highlightedSelections: searchHighlight?.matches ?? [],
                currentSelection: searchHighlight?.current
            )
            .ignoresSafeArea(edges: editMode ? [] : .bottom)
```

Replace it with:

```swift
            PDFKitView(
                document: session.pdf,
                highlightedSelections: searchHighlight?.matches ?? [],
                currentSelection: searchHighlight?.current,
                annotationRevision: annotationRevision,
                onApplyTool: { tool, selection in
                    applyTool(tool, to: selection, session: session)
                },
                onRequestDelete: { annotation, page in
                    pendingDeletion = PendingDeletion(annotation: annotation, page: page)
                }
            )
            .ignoresSafeArea(edges: editMode ? [] : .bottom)
            .confirmationDialog(
                "Remove this mark?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                presenting: pendingDeletion
            ) { item in
                Button("Delete", role: .destructive) {
                    item.page.removeAnnotation(item.annotation)
                    try? session.save()
                    annotationRevision &+= 1
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            }
```

- [ ] **Step 4: Add the `applyTool` helper**

In `DocumentViewerView`, add this method next to `rebuildHighlight(session:)`:

```swift
    private func applyTool(_ tool: AnnotationTool, to selection: PDFSelection, session: DocumentSession) {
        let made = AnnotationFactory.annotations(for: selection, tool: tool)
        guard !made.isEmpty else { return }
        for (page, annotation) in made {
            page.addAnnotation(annotation)
        }
        // Persist immediately (consistent with edit-mode saves). save() strips
        // only search highlights, so these user marks are written to disk.
        try? session.save()
        annotationRevision &+= 1
    }
```

- [ ] **Step 5: Build to verify it compiles**

Run:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Run the full unit suite (no regressions)**

Run:
```bash
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests
```
Expected: PASS (all unit tests, including Tasks 1–3).

- [ ] **Step 7: Commit**

```bash
git add DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
git commit -m "feat: markup edit menu + tap-to-delete in document viewer"
```

---

## Task 5: Version bump + manual smoke test

**Files:**
- Modify: `DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj` (via Xcode UI)

- [ ] **Step 1: Bump version (manual, in Xcode)**

Xcode → target **DocumentScanner** → General: set **Version** to `1.4` and
**Build** to `9`. This updates `MARKETING_VERSION` (1.3 → 1.4) and
`CURRENT_PROJECT_VERSION` (8 → 9) for the main-app Debug + Release configs; leave
the test targets unchanged.

Verify:
```bash
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" \
  DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
```
Expected: the two main-app configs show `MARKETING_VERSION = 1.4;` and
`CURRENT_PROJECT_VERSION = 9;`; the four test-target configs stay at 1.0 / 1.

- [ ] **Step 2: Manual smoke test (device/simulator — user-driven)**

Confirm on a real document:
  1. Long-press text → the menu shows **Highlight ▸** (Yellow/Green/Pink/Blue) and
     **Strikethrough**.
  2. Pick a colour → the selected words gain a translucent highlight; pick
     Strikethrough → a red line through the words.
  3. Close and reopen the document → the marks are still there (persisted).
  4. Tap a mark → "Remove this mark?" → **Delete** removes it; reopen confirms it's
     gone.
  5. Run a text search in the same doc → search highlights still appear and don't
     clobber the user marks.

If the edit menu does NOT show the custom items on device, the fallback is the
(deprecated but functional) `UIMenuController` + `canPerformAction(_:withSender:)`
approach with custom `UIMenuItem`s; note it and report back rather than guessing.

- [ ] **Step 3: Commit the version bump**

```bash
git add DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj
git commit -m "chore: bump to v1.4 (9)"
```

---

## Done

After Task 5, users can highlight (four colours) and strike through text, marks
persist into the PDF and survive reload, and tapping a mark deletes it. Next steps
(outside this plan): push, archive, upload, submit for review — same flow as v1.3.
