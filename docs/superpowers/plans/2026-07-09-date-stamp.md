# Date Stamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a date stamp — pick a date (default today) and one of 5 fixed format presets, render it to an image, and place it on the page via the existing signature-stamp machinery (drag/resize, Move/Remove, persistence).

**Architecture:** A pure `DateStampFormat` enum formats `(date) → String`. `DateStampRenderer` draws that string to a transparent, high-res `UIImage`. `AddDateSheet` (a SwiftUI sheet) lets the user pick the date + format. The viewer renders the chosen date to an image and hands it to the *same* `SignaturePlacementView`/`ImageStampAnnotation` path signatures already use — tagged with a new `dateStampAnnotationName` and carrying the rendered date string in `contents` so Move can re-render it (works even after a save→reload).

**Tech Stack:** Swift, SwiftUI, PDFKit (`PDFAnnotation`/`ImageStampAnnotation`), UIKit (`UIGraphicsImageRenderer`), `@AppStorage`, XCTest.

**Context for the implementer:**
- Reuse, don't reinvent: `ImageStampAnnotation(image:bounds:userName:)` already exists; `SignaturePlacementView` already does drag + pinch-resize and returns a page-space `CGRect`; the viewer already places/persists/moves/removes signature stamps.
- Signature stamps are tagged `userName == DocumentSession.signatureAnnotationName` (`"DocumentScanner.signature"`) and carry their signature id in `contents`. Date stamps mirror this with a **new tag** and the **rendered date string** in `contents`.
- The viewer's tap handler routes by `userName` (see `onRequestDelete` in `documentContent`). `contents` and `userName` both survive a PDF `dataRepresentation()` round-trip (proven by `SignatureAnnotationPersistenceTests`).
- Ground-truth test command (from repo root):
  ```
  xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DocumentScannerTests
  ```
  Scope a single class by appending e.g. `-only-testing:DocumentScannerTests/DateStampFormatTests`. New files auto-join their target (file-system-synchronized groups) — no `.pbxproj` edits.

---

## File Structure

- **Create** `DocumentScanner/DocumentScanner/DateStamp/DateStampFormat.swift` — pure enum, 5 formats, `string(for:)`.
- **Create** `DocumentScanner/DocumentScanner/DateStamp/DateStampRenderer.swift` — string → transparent high-res `UIImage`.
- **Create** `DocumentScanner/DocumentScanner/DateStamp/AddDateSheet.swift` — date picker + live-previewed format list.
- **Modify** `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift` — add `dateStampAnnotationName`.
- **Modify** `DocumentScanner/DocumentScanner/Signature/SignaturePlacementView.swift` — parameterize the nav title.
- **Modify** `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift` — "Date" button, present the sheet, render + place, tag routing, date edit alert, `PlacementRequest` generalization.
- **Create** `DocumentScanner/DocumentScannerTests/DateStampFormatTests.swift`, `DateStampRendererTests.swift`, `DateStampAnnotationPersistenceTests.swift`.
- **Modify** `docs/FutureEnhancements.md` — mark built.

---

## Task 1: `DateStampFormat` (pure formatting)

**Files:**
- Create: `DocumentScanner/DocumentScanner/DateStamp/DateStampFormat.swift`
- Test: `DocumentScanner/DocumentScannerTests/DateStampFormatTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DocumentScanner/DocumentScannerTests/DateStampFormatTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class DateStampFormatTests: XCTestCase {

    /// Build a date at noon in the current calendar so formatting (which uses the
    /// current time zone) can't roll it to an adjacent day.
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    func test_allFormats_knownDate() {
        let d = date(2026, 7, 9)
        XCTAssertEqual(DateStampFormat.iso.string(for: d), "2026-07-09")
        XCTAssertEqual(DateStampFormat.numericUS.string(for: d), "07/09/2026")
        XCTAssertEqual(DateStampFormat.numericIntl.string(for: d), "09/07/2026")
        XCTAssertEqual(DateStampFormat.longUS.string(for: d), "July 9, 2026")
        XCTAssertEqual(DateStampFormat.longIntl.string(for: d), "9 July 2026")
    }

    func test_singleDigitDayAndMonth_padding() {
        let d = date(2026, 3, 5)
        XCTAssertEqual(DateStampFormat.iso.string(for: d), "2026-03-05")       // zero-padded
        XCTAssertEqual(DateStampFormat.numericUS.string(for: d), "03/05/2026") // zero-padded
        XCTAssertEqual(DateStampFormat.longUS.string(for: d), "March 5, 2026") // day NOT padded
        XCTAssertEqual(DateStampFormat.longIntl.string(for: d), "5 March 2026")
    }

    func test_caseIterable_hasFiveStableOrder() {
        XCTAssertEqual(DateStampFormat.allCases,
                       [.iso, .numericUS, .numericIntl, .longUS, .longIntl])
    }
}
```

- [ ] **Step 2: Run it — verify it fails**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DocumentScannerTests/DateStampFormatTests`
Expected: FAIL to compile — `DateStampFormat` undefined.

- [ ] **Step 3: Implement**

Create `DocumentScanner/DocumentScanner/DateStamp/DateStampFormat.swift`:

```swift
import Foundation

/// The five date formats a date stamp can render in. Explicit, fixed formats with
/// a fixed `en_US_POSIX` locale so output never shifts with the device's region —
/// the document dictates the format, not the phone. `rawValue` backs @AppStorage.
enum DateStampFormat: String, CaseIterable, Identifiable, Equatable {
    case iso          // 2026-07-09
    case numericUS    // 07/09/2026
    case numericIntl  // 09/07/2026
    case longUS       // July 9, 2026
    case longIntl     // 9 July 2026

    var id: String { rawValue }

    private var template: String {
        switch self {
        case .iso:         return "yyyy-MM-dd"
        case .numericUS:   return "MM/dd/yyyy"
        case .numericIntl: return "dd/MM/yyyy"
        case .longUS:      return "MMMM d, yyyy"
        case .longIntl:    return "d MMMM yyyy"
        }
    }

    func string(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = template
        return f.string(from: date)
    }
}
```

- [ ] **Step 4: Run it — verify it passes**

Run: same `-only-testing:DocumentScannerTests/DateStampFormatTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/DateStamp/DateStampFormat.swift DocumentScanner/DocumentScannerTests/DateStampFormatTests.swift
git commit -m "feat: DateStampFormat — 5 fixed date-format presets"
```

---

## Task 2: `DateStampRenderer` (string → transparent image)

**Files:**
- Create: `DocumentScanner/DocumentScanner/DateStamp/DateStampRenderer.swift`
- Test: `DocumentScanner/DocumentScannerTests/DateStampRendererTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DocumentScanner/DocumentScannerTests/DateStampRendererTests.swift`:

```swift
import XCTest
import UIKit
@testable import DocumentScanner

final class DateStampRendererTests: XCTestCase {

    func test_image_hasPositiveSize_andCGImage() {
        let img = DateStampRenderer.image(for: "2026-07-09")
        XCTAssertGreaterThan(img.size.width, 0)
        XCTAssertGreaterThan(img.size.height, 0)
        XCTAssertNotNil(img.cgImage)
    }

    func test_longerText_isWider() {
        let short = DateStampRenderer.image(for: "1")
        let long = DateStampRenderer.image(for: "September 30, 2026")
        XCTAssertGreaterThan(long.size.width, short.size.width,
                             "wider text produces a wider image")
    }
}
```

- [ ] **Step 2: Run it — verify it fails**

Run: `xcodebuild test … -only-testing:DocumentScannerTests/DateStampRendererTests`
Expected: FAIL to compile — `DateStampRenderer` undefined.

- [ ] **Step 3: Implement**

Create `DocumentScanner/DocumentScanner/DateStamp/DateStampRenderer.swift`:

```swift
import UIKit

/// Renders a short string (a formatted date) to a transparent, black-text image.
/// Rendered at a large point size so the placed stamp stays crisp when the user
/// pinch-resizes it up (unlike a scanned signature, text degrades if rendered
/// small then scaled). The image is then placed exactly like a signature.
enum DateStampRenderer {
    private static let fontSize: CGFloat = 96
    private static let padding: CGFloat = 12

    static func image(for text: String) -> UIImage {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let str = text as NSString
        let textSize = str.size(withAttributes: attrs)
        let size = CGSize(width: ceil(textSize.width) + padding * 2,
                          height: ceil(textSize.height) + padding * 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false   // transparent background
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            str.draw(at: CGPoint(x: padding, y: padding), withAttributes: attrs)
        }
    }
}
```

- [ ] **Step 4: Run it — verify it passes**

Run: same `-only-testing:DocumentScannerTests/DateStampRendererTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/DateStamp/DateStampRenderer.swift DocumentScanner/DocumentScannerTests/DateStampRendererTests.swift
git commit -m "feat: DateStampRenderer — date string to transparent high-res image"
```

---

## Task 3: `AddDateSheet` (date picker + live-previewed formats)

No unit test — it's a presentation-only SwiftUI view (the app doesn't unit-test views; its logic lives in the tested `DateStampFormat`). Verified via the build + on-device smoke.

**Files:**
- Create: `DocumentScanner/DocumentScanner/DateStamp/AddDateSheet.swift`

- [ ] **Step 1: Implement**

Create `DocumentScanner/DocumentScanner/DateStamp/AddDateSheet.swift`:

```swift
import SwiftUI

/// Sheet for adding a date stamp: pick a date (defaults to today) and a format.
/// The format rows preview the currently-selected date live; the last-used format
/// is checkmarked and persisted. Tapping a format row is the confirm.
struct AddDateSheet: View {
    @AppStorage("dateStampFormat") private var lastFormatRaw = DateStampFormat.iso.rawValue
    @State private var selectedDate = Date()

    /// Called with the chosen date + format when a format row is tapped.
    let onPick: (Date, DateStampFormat) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)

                Section("Format") {
                    ForEach(DateStampFormat.allCases) { format in
                        Button {
                            lastFormatRaw = format.rawValue
                            onPick(selectedDate, format)
                        } label: {
                            HStack {
                                Text(format.string(for: selectedDate))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if format.rawValue == lastFormatRaw {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("AddDate.Format.\(format.rawValue)")
                    }
                }
            }
            .navigationTitle("Add Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
            }
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/DateStamp/AddDateSheet.swift
git commit -m "feat: AddDateSheet — date picker + live-previewed format list"
```

---

## Task 4: Viewer integration + persistence test

Wire the "Date" button, present the sheet, render + place via the shared placement flow, and add tag routing + a "Date" edit alert (Move re-renders from `contents`; Remove deletes).

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift`
- Modify: `DocumentScanner/DocumentScanner/Signature/SignaturePlacementView.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`
- Test: `DocumentScanner/DocumentScannerTests/DateStampAnnotationPersistenceTests.swift`

- [ ] **Step 1: Write the failing persistence test**

Create `DocumentScanner/DocumentScannerTests/DateStampAnnotationPersistenceTests.swift`:

```swift
import XCTest
import PDFKit
@testable import DocumentScanner

/// A date stamp is an ImageStampAnnotation tagged as a date, carrying the rendered
/// date string in `contents` so Move can re-render it — even after a save→reload.
/// This proves the tag + string survive the PDF data round-trip.
final class DateStampAnnotationPersistenceTests: XCTestCase {

    func test_dateStamp_tagAndContents_persistAcrossReload() throws {
        let pdf = PDFDocument(); let page = PDFPage(); pdf.insert(page, at: 0)
        let img = DateStampRenderer.image(for: "2026-07-09")
        let stamp = ImageStampAnnotation(image: img,
                                         bounds: CGRect(x: 20, y: 20, width: 120, height: 36),
                                         userName: DocumentSession.dateStampAnnotationName)
        stamp.contents = "2026-07-09"
        page.addAnnotation(stamp)

        let data = try XCTUnwrap(pdf.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        let anno = try XCTUnwrap(reloaded.page(at: 0)?.annotations.first {
            $0.userName == DocumentSession.dateStampAnnotationName
        })
        XCTAssertEqual(anno.contents, "2026-07-09",
                       "rendered date must survive in contents so Move can re-render it")
    }
}
```

- [ ] **Step 2: Run it — verify it fails**

Run: `xcodebuild test … -only-testing:DocumentScannerTests/DateStampAnnotationPersistenceTests`
Expected: FAIL to compile — `DocumentSession.dateStampAnnotationName` undefined.

- [ ] **Step 3: Add the date-stamp tag**

In `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift`, right after the `signatureAnnotationName` declaration, add:

```swift
    /// Annotation `userName` marking a placed date stamp. Persists across save like
    /// a signature; its `contents` holds the rendered date string so Move can
    /// re-render it (even after a reload). `nonisolated` for the same reason as above.
    nonisolated static let dateStampAnnotationName = "DocumentScanner.dateStamp"
```

- [ ] **Step 4: Run the persistence test — verify it passes**

Run: same `-only-testing:DocumentScannerTests/DateStampAnnotationPersistenceTests`
Expected: PASS.

- [ ] **Step 5: Parameterize the placement view title**

In `DocumentScanner/DocumentScanner/Signature/SignaturePlacementView.swift`, add a `title` property (after `onCancel`):

```swift
    var title: String = "Place Signature"
```

and change the nav title line from `.navigationTitle("Place Signature")` to:

```swift
            .navigationTitle(title)
```

- [ ] **Step 6: Generalize `PlacementRequest` for date stamps**

In `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`, extend the `PlacementRequest` struct with a title and an optional date string:

```swift
    private struct PlacementRequest: Identifiable {
        let id = UUID()
        let signature: UIImage
        var signatureID: String? = nil    // which saved signature this came from (for Move)
        let page: PDFPage
        let seedRect: CGRect?
        var replacing: PDFAnnotation? = nil
        var title: String = "Place Signature"
        var dateString: String? = nil     // non-nil ⇒ this is a date stamp (place via placeDateStamp)
    }
```

Then in the `.sheet(item: $placement)` body, pass the title and branch `onPlace` on `dateString`:

```swift
        .sheet(item: $placement) { req in
            SignaturePlacementView(
                pageImage: pageRenderForSigning(req.page),
                signature: req.signature,
                pageBounds: req.page.bounds(for: .mediaBox),
                initialPageRect: req.seedRect,
                title: req.title,
                onPlace: { rect in
                    if let old = req.replacing { req.page.removeAnnotation(old) }
                    if let ds = req.dateString {
                        placeDateStamp(req.signature, dateString: ds, at: rect, on: req.page, session: session)
                    } else {
                        placeSignature(req.signature, id: req.signatureID, at: rect, on: req.page, session: session)
                    }
                    placement = nil
                },
                onCancel: { placement = nil }
            )
        }
```

- [ ] **Step 7: Add `placeDateStamp` + the sheet/edit state**

In `DocumentViewerView`, add state near `showingSignaturePicker`:

```swift
    @State private var showingAddDate = false
    @State private var pendingDateEdit: SignatureEdit?
```

Add `placeDateStamp` next to `placeSignature`:

```swift
    private func placeDateStamp(_ image: UIImage, dateString: String, at rect: CGRect, on page: PDFPage, session: DocumentSession) {
        let stamp = ImageStampAnnotation(image: image, bounds: rect,
                                         userName: DocumentSession.dateStampAnnotationName)
        stamp.contents = dateString   // persist the rendered date so Move can re-render it
        page.addAnnotation(stamp)
        _ = try? session.save()
        annotationRevision &+= 1
        signatureRevision &+= 1
    }
```

- [ ] **Step 8: Add the "Date" toolbar button**

In `viewerToolbar`, immediately after the `Button("Sign") { … }` block (before `Spacer()`), add:

```swift
            Button("Date") {
                if currentPageForSigning(session: session) != nil { showingAddDate = true }
            }
            .accessibilityIdentifier("Viewer.DateButton")
```

- [ ] **Step 9: Present `AddDateSheet` and open placement**

Add alongside the other `.sheet`/`.alert` modifiers on the content (e.g. right after the `.sheet(item: $placement)` block):

```swift
        .sheet(isPresented: $showingAddDate) {
            AddDateSheet(
                onPick: { date, format in
                    showingAddDate = false
                    guard let page = currentPageForSigning(session: session) else { return }
                    let str = format.string(for: date)
                    let img = DateStampRenderer.image(for: str)
                    placement = PlacementRequest(signature: img, page: page, seedRect: nil,
                                                 title: "Place Date", dateString: str)
                },
                onCancel: { showingAddDate = false }
            )
        }
```

- [ ] **Step 10: Route taps + add the "Date" edit alert**

In `documentContent`'s `onRequestDelete` closure, add a date branch:

```swift
                onRequestDelete: { annotation, page in
                    if annotation.userName == DocumentSession.signatureAnnotationName {
                        pendingSignatureEdit = SignatureEdit(annotation: annotation, page: page)
                    } else if annotation.userName == DocumentSession.dateStampAnnotationName {
                        pendingDateEdit = SignatureEdit(annotation: annotation, page: page)
                    } else {
                        pendingDeletion = PendingDeletion(annotation: annotation, page: page)
                    }
                },
```

Add the date edit alert next to the existing `.alert("Signature", …)`:

```swift
        .alert("Date", isPresented: Binding(
            get: { pendingDateEdit != nil },
            set: { if !$0 { pendingDateEdit = nil } }
        ), presenting: pendingDateEdit) { item in
            Button("Move") {
                // Re-render the SAME date from the string persisted in contents,
                // then re-place it (works before and after a save→reload).
                let str = item.annotation.contents ?? ""
                let img = DateStampRenderer.image(for: str)
                placement = PlacementRequest(signature: img, page: item.page,
                                             seedRect: item.annotation.bounds,
                                             replacing: item.annotation,
                                             title: "Place Date", dateString: str)
                pendingDateEdit = nil
            }
            Button("Remove", role: .destructive) {
                item.page.removeAnnotation(item.annotation)
                _ = try? session.save(); annotationRevision &+= 1; signatureRevision &+= 1
                pendingDateEdit = nil
            }
            Button("Cancel", role: .cancel) { pendingDateEdit = nil }
        }
```

- [ ] **Step 11: Build + run the full unit suite**

Run: `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DocumentScannerTests`
Expected: PASS — all prior tests plus the new `DateStampFormatTests`, `DateStampRendererTests`, `DateStampAnnotationPersistenceTests`. (Confirm the viewer changes compile and nothing regressed.)

- [ ] **Step 12: Commit**

```bash
git add DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift \
        DocumentScanner/DocumentScanner/Signature/SignaturePlacementView.swift \
        DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift \
        DocumentScanner/DocumentScannerTests/DateStampAnnotationPersistenceTests.swift
git commit -m "feat: date stamp — Date button, picker sheet, place/move/remove via stamp path"
```

---

## Task 5: Docs

**Files:**
- Modify: `docs/FutureEnhancements.md`

- [ ] **Step 1: Mark the date stamp built**

In `docs/FutureEnhancements.md`, under "Signing follow-ups", replace the `**Initials / date / text stamps**` bullet with:

```markdown
- ~~**Date stamp**~~ — **Built.** Viewer "Date" button → sheet with a date picker (defaults to today) + 5 fixed format presets (`2026-07-09` · `07/09/2026` · `09/07/2026` · `July 9, 2026` · `9 July 2026`, `en_US_POSIX`), previewed live and last-used remembered (`@AppStorage("dateStampFormat")`). The chosen date renders to a transparent image (`DateStampRenderer`) and is placed via the existing signature machinery (`SignaturePlacementView` drag/resize → `ImageStampAnnotation` tagged `dateStampAnnotationName`, rendered date string in `contents` so Move re-renders it). Initials dropped (scannable via multi-signatures); free text excluded (editor-ish). Spec/plan under `docs/superpowers/` dated 2026-07-09.
```

- [ ] **Step 2: Commit**

```bash
git add docs/FutureEnhancements.md
git commit -m "docs: mark date stamp built"
```

---

## After all tasks

- **On-device smoke** (drive the real flow): tap **Date** → the sheet shows today + 5 live previews; pick a **non-today** date via the picker and confirm the previews update; place each of a couple formats; **drag + pinch-resize**; tap a placed date → **Move** (re-renders, repositions) and **Remove**; **save→reopen** the document and confirm the date stamp is still there and still Movable. Verify the last-used format is checkmarked next time.
- Then use **superpowers:finishing-a-development-branch** to merge.
- Version bump + What's New + archive/submit happen at release time (not part of this plan).

---

## Self-review notes (checked against the spec)

- **Spec coverage:** date picker default-today (Task 3 `selectedDate = Date()`, `.compact`); 5 fixed presets (Task 1, `en_US_POSIX`); live previews + last-used memory (Task 3 `@AppStorage`); render to transparent crisp image (Task 2); reuse placement/`ImageStampAnnotation` (Task 4); Date-vs-Signature Move routing via `contents` re-render (Task 4 Steps 6–10, persistence Step 1); English month names (Task 1 locale). All covered.
- **Type consistency:** `DateStampFormat.string(for:)`, `DateStampRenderer.image(for:)`, `DocumentSession.dateStampAnnotationName`, `PlacementRequest(title:dateString:)`, `SignaturePlacementView(title:)`, `placeDateStamp(_:dateString:at:on:session:)`, `pendingDateEdit`/`showingAddDate` used identically across tasks.
- **No placeholders:** every step has complete code and exact commands.
- **Non-goal guard:** no free-text, no font/colour/size controls, no auto-detect/multi-page — matches the spec.
```
