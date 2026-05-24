# Mobile Document Scanner — Plan 5: XCUITest golden-path tests

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lock the app's most important user flows into automated UI tests that run on the simulator, with no real iCloud / camera dependence. Catches regressions in the navigation, name-and-save flow, and edit-mode interactions across all future changes.

**Architecture:** A `-UITestMode` launch argument tells `DocumentScannerApp` to construct test doubles instead of production services: `StubDocumentScanner` (returns fixture page images instead of opening VisionKit), `InMemoryLibraryStore` (no `NSMetadataQuery`, no iCloud), and a temp-directory `DocumentStorage`. Real UI flows are then exercised by `XCUIApplication`-driven tests with `accessibilityIdentifier`s placed on key controls.

**Tech Stack:** XCTest, XCUITest (`XCUIApplication`, `XCUIElement` queries), `accessibilityIdentifier` SwiftUI modifier.

**Spec:** [`docs/superpowers/specs/2026-05-21-mobile-document-scanner-design.md`](../specs/2026-05-21-mobile-document-scanner-design.md) — Testing strategy section.

**Prerequisite plans:** Plans 1, 2a, 2b, 3, 2c, 4, 4b all completed and verified on device.

---

## A note for the first-time iOS developer

UI tests are a different animal from unit tests:

- **`XCUIApplication`** is a *remote-control* for your app. It launches a separate process and pokes at the visible UI. Tests in your XCUITest target can't directly call functions in the app — they can only interact through what's on screen.
- **`accessibilityIdentifier`** is the canonical way to find a specific control. Without it, queries are text-based ("the button labeled 'Save'") which breaks if you ever rename UI strings.
- **Launch arguments** are how you tell the app "this is a test" — read them in the App's init with `CommandLine.arguments` or `ProcessInfo.processInfo.arguments`. Branch on them to swap in test doubles.
- **Hermeticity matters.** A UI test that depends on iCloud sync, leftover files from a previous run, or the simulator's camera is flaky. We swap in stubs so the test runs the same way every time.

## File structure (target end-state of Plan 5)

```text
DocumentScanner/
  Capture/
    StubDocumentScanner.swift               # NEW: returns fixture images instead of VisionKit
  App/
    DocumentScannerApp.swift                # MODIFY: branch on -UITestMode launch arg
  Library/
    DocumentRow.swift                       # MODIFY: accessibilityIdentifier per row
  Capture/
    NameDocumentSheet.swift                 # MODIFY: accessibilityIdentifier on name field + save
  Library/
    LibraryView.swift                       # MODIFY: accessibilityIdentifiers on +, gear, edit
  Viewer/
    DocumentViewerView.swift                # MODIFY: accessibilityIdentifiers on Edit, ShareLink, ...
    EditModeView.swift                      # MODIFY: accessibilityIdentifier per thumbnail
DocumentScannerUITests/
  GoldenPathTests.swift                     # NEW: scan → name → save → row → viewer → back
  EditModeTests.swift                       # NEW: reorder + delete page
  TestHelpers.swift                         # NEW: launch helper, fixture matchers
  DocumentScannerUITests.swift              # DELETE: Xcode template noise
  DocumentScannerUITestsLaunchTests.swift   # DELETE: same
```

After Plan 5: `xcodebuild test` runs all unit tests + the 2 new UI tests + the existing per-plan units; no flakiness from external state.

---

## Task 1: StubDocumentScanner + UITestMode plumbing

**Files:**
- Create: `DocumentScanner/DocumentScanner/Capture/StubDocumentScanner.swift`
- Modify: `DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift`

The stub conforms to `DocumentScannerPresenting`. On `makeViewController(onFinish:onCancel:)` it returns a tiny view controller with two buttons: "Finish" (calls `onFinish` with a fixture page image) and "Cancel" (calls `onCancel`). UI tests tap "Finish".

When `-UITestMode` is in launch arguments, `DocumentScannerApp` constructs the stub + an `InMemoryLibraryStore` + a temp-dir `DocumentStorage`.

- [ ] **Step 1: Implement `StubDocumentScanner`**

  ```swift
  import UIKit

  /// Test double for DocumentScannerPresenting. Instead of opening VisionKit,
  /// presents a minimal view controller with "Finish" / "Cancel" buttons.
  /// "Finish" hands back a deterministic fixture image so UI tests don't
  /// depend on a real camera or scanned content.
  struct StubDocumentScanner: DocumentScannerPresenting {

      func makeViewController(
          onFinish: @escaping ([UIImage]) -> Void,
          onCancel: @escaping () -> Void
      ) -> UIViewController {
          StubScannerViewController(onFinish: onFinish, onCancel: onCancel)
      }
  }

  private final class StubScannerViewController: UIViewController {
      let onFinish: ([UIImage]) -> Void
      let onCancel: () -> Void

      init(onFinish: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
          self.onFinish = onFinish
          self.onCancel = onCancel
          super.init(nibName: nil, bundle: nil)
      }

      required init?(coder: NSCoder) { fatalError() }

      override func viewDidLoad() {
          super.viewDidLoad()
          view.backgroundColor = .systemBackground

          let finishButton = UIButton(type: .system)
          finishButton.setTitle("Finish", for: .normal)
          finishButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .semibold)
          finishButton.accessibilityIdentifier = "StubScanner.Finish"
          finishButton.addAction(UIAction { [weak self] _ in
              self?.onFinish([Self.fixtureImage()])
          }, for: .touchUpInside)

          let cancelButton = UIButton(type: .system)
          cancelButton.setTitle("Cancel", for: .normal)
          cancelButton.accessibilityIdentifier = "StubScanner.Cancel"
          cancelButton.addAction(UIAction { [weak self] _ in
              self?.onCancel()
          }, for: .touchUpInside)

          let stack = UIStackView(arrangedSubviews: [finishButton, cancelButton])
          stack.axis = .vertical
          stack.spacing = 16
          stack.alignment = .center
          stack.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(stack)
          NSLayoutConstraint.activate([
              stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
              stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
          ])
      }

      /// A deterministic 612×792 (US Letter) page with a unique marker
      /// string so UI tests can verify it round-trips.
      static func fixtureImage() -> UIImage {
          let size = CGSize(width: 612, height: 792)
          return UIGraphicsImageRenderer(size: size).image { _ in
              UIColor.white.setFill()
              UIRectFill(CGRect(origin: .zero, size: size))
              let text = "UITest fixture page"
              (text as NSString).draw(
                  at: CGPoint(x: 40, y: 60),
                  withAttributes: [
                      .font: UIFont.boldSystemFont(ofSize: 48),
                      .foregroundColor: UIColor.black
                  ]
              )
          }
      }
  }
  ```

- [ ] **Step 2: Update `DocumentScannerApp` to branch on launch arg**

  Add a static helper to decide the mode:

  ```swift
  private static var isUITesting: Bool {
      ProcessInfo.processInfo.arguments.contains("-UITestMode")
  }
  ```

  Change the production wiring to choose stubs vs. real:

  ```swift
  private let pipeline = ScanPipeline()
  private let scannerPresenter: DocumentScannerPresenting =
      isUITesting ? StubDocumentScanner() : SystemDocumentScanner()
  private let testStorage: DocumentStorage = {
      let tmp = FileManager.default.temporaryDirectory
          .appendingPathComponent("uitests-\(UUID().uuidString)", isDirectory: true)
      try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
      return DocumentStorage(documentsURL: tmp)
  }()
  ```

  And in the WindowGroup body, choose store + storage based on the mode. The current body uses `MetadataQueryLibraryStore` and `DocumentStorage(documentsURL: container.resolveDocumentsURL())`. Replace with:

  ```swift
  WindowGroup {
      if Self.isUITesting {
          // Hermetic UI-test wiring: no iCloud, no real scanner.
          LibraryView(
              store: store,
              scannerPresenter: scannerPresenter,
              storage: testStorage,
              pipeline: pipeline,
              lockSettings: lockSettings
          )
          .environment(\.alertCenter, alertCenter)
      } else {
          // ... existing production WindowGroup body ...
      }
  }
  ```

  **Important wrinkle:** `store` is currently `@State private var store = MetadataQueryLibraryStore()`. For UI tests we want `InMemoryLibraryStore`, but the existing `LibraryView` is generic on `Store: LibraryStoring & Observable`. We need to branch the type. Two options:

  - **(a) Two separate `@State` properties** — `metadataStore` for prod, `inMemoryStore` for tests. Choose at the WindowGroup body. Simple and explicit. **Preferred.**
  - **(b) Type-erase the store** — wrap in an `AnyLibraryStoring`. More refactoring.

  Go with (a):

  ```swift
  @State private var metadataStore = MetadataQueryLibraryStore()
  @State private var inMemoryStore = InMemoryLibraryStore()
  ```

  Then in the body, pass whichever matches the mode. **Note:** `InMemoryLibraryStore` is currently `nonisolated final class` and not `@Observable` (see `LibraryStore.swift`). To use it with `LibraryView<Store: LibraryStoring & Observable>`, it needs `@Observable`. Add `@Observable` to `InMemoryLibraryStore` for this — the original reason it wasn't `@Observable` (the deinit-on-MainActor crash with the default isolation) doesn't apply anymore since we removed `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. It can be `@Observable` safely now.

- [ ] **Step 3: Make `InMemoryLibraryStore` Observable again**

  In `DocumentScanner/DocumentScanner/Library/LibraryStore.swift`, change:

  ```swift
  nonisolated final class InMemoryLibraryStore: LibraryStoring {
  ```

  to:

  ```swift
  @Observable
  final class InMemoryLibraryStore: LibraryStoring {
  ```

  (Remove `nonisolated` — it was a workaround for the deinit crash under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. We removed that setting in commit `d2782f8`, so `nonisolated` is no longer needed. Re-running the existing `LibraryStoreTests` should still pass.)

- [ ] **Step 4: Build + test**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)|Test case.*failed" | tail -5
  ```

  All existing tests must still pass, including `LibraryStoreTests`.

- [ ] **Step 5: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Capture/StubDocumentScanner.swift DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift DocumentScanner/DocumentScanner/Library/LibraryStore.swift
  git commit -m "Add StubDocumentScanner + UITestMode launch-arg plumbing

  Task 1 of plan-5: when launched with -UITestMode, DocumentScannerApp
  constructs StubDocumentScanner + InMemoryLibraryStore + temp-dir
  DocumentStorage instead of the real services. The stub presents a
  minimal view controller with Finish / Cancel buttons that hand
  back a deterministic fixture image. InMemoryLibraryStore regains
  @Observable since the deinit-on-MainActor crash that drove
  'nonisolated' no longer applies (project removed default
  MainActor isolation in d2782f8).

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 2: Accessibility identifiers on key controls

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/DocumentRow.swift`
- Modify: `DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/EditModeView.swift`

Add deterministic `accessibilityIdentifier`s so XCUITest queries don't rely on visible text (which can change with localization, layout, etc.).

Identifier naming convention: `View.ControlName`. E.g., `Library.AddButton`, `NameSheet.NameField`.

- [ ] **Step 1: Library**

  In `LibraryView.swift`:

  - The + Button: add `.accessibilityIdentifier("Library.AddButton")` on the `Image(systemName: "plus")` (or on the Button itself).
  - The gear Button: `.accessibilityIdentifier("Library.SettingsButton")`.

  In `DocumentRow.swift`, add to the outer `HStack`:

  ```swift
  .accessibilityIdentifier("Library.Row.\(summary.displayName)")
  ```

  So each row has a unique identifier based on its displayed name.

- [ ] **Step 2: Name & Save sheet**

  In `NameDocumentSheet.swift`:

  - The TextField: `.accessibilityIdentifier("NameSheet.NameField")`.
  - The Save button: `.accessibilityIdentifier("NameSheet.Save")`.
  - The Cancel button: `.accessibilityIdentifier("NameSheet.Cancel")`.

- [ ] **Step 3: Viewer**

  In `DocumentViewerView.swift`:

  - The Edit / Done button: `.accessibilityIdentifier("Viewer.EditToggle")`.
  - The trash menu item / Delete: `.accessibilityIdentifier("Viewer.Delete")`.
  - The Rename menu item: `.accessibilityIdentifier("Viewer.Rename")`.

  In `EditModeView.swift`, on each thumbnail outer view:

  ```swift
  .accessibilityIdentifier("EditMode.Thumbnail.\(index)")
  ```

  And on the Add Pages tile:

  ```swift
  .accessibilityIdentifier("EditMode.AddPages")
  ```

- [ ] **Step 4: Build (no behavior change; just identifiers)**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild build -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | grep -E "warning:|error:|BUILD (SUCCEEDED|FAILED)" | grep -v "^ld:\|appintentsmetadataprocessor" | head -5
  ```

- [ ] **Step 5: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Library/LibraryView.swift DocumentScanner/DocumentScanner/Library/DocumentRow.swift DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift DocumentScanner/DocumentScanner/Viewer/EditModeView.swift
  git commit -m "Add accessibilityIdentifiers to key UI controls

  Task 2 of plan-5: deterministic identifiers for XCUITest queries.
  Naming convention: <View>.<ControlName>. Lets tests find buttons
  and rows without depending on visible text.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 3: Golden-path UI test

**Files:**
- Create: `DocumentScanner/DocumentScannerUITests/TestHelpers.swift`
- Create: `DocumentScanner/DocumentScannerUITests/GoldenPathTests.swift`

End-to-end happy path: launch → empty state → tap + → stub scanner returns fixture → name and save → row appears → tap row → viewer renders → back.

- [ ] **Step 1: Implement `TestHelpers.swift`**

  ```swift
  import XCTest

  /// Common XCUITest setup helpers.
  enum TestHelpers {

      /// Launch the app in hermetic UI-test mode.
      @MainActor
      static func launchedApp() -> XCUIApplication {
          let app = XCUIApplication()
          app.launchArguments = ["-UITestMode"]
          app.launch()
          return app
      }

      /// Wait for a query to match an element within a generous timeout.
      static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
          element.waitForExistence(timeout: timeout)
      }
  }
  ```

- [ ] **Step 2: Implement `GoldenPathTests.swift`**

  ```swift
  import XCTest

  final class GoldenPathTests: XCTestCase {

      @MainActor
      func test_scan_save_viewLibrary_openViewer() async throws {
          let app = TestHelpers.launchedApp()

          // 1. Empty state visible.
          XCTAssertTrue(app.staticTexts["No documents yet"].waitForExistence(timeout: 5),
                        "expected empty-state title on first launch")

          // 2. Tap + button.
          let addButton = app.buttons["Library.AddButton"]
          XCTAssertTrue(addButton.waitForExistence(timeout: 5))
          addButton.tap()

          // 3. Stub scanner appears; tap Finish.
          let finishButton = app.buttons["StubScanner.Finish"]
          XCTAssertTrue(finishButton.waitForExistence(timeout: 5),
                        "expected stub scanner Finish button")
          finishButton.tap()

          // 4. Name sheet appears. Type a custom name.
          let nameField = app.textFields["NameSheet.NameField"]
          XCTAssertTrue(nameField.waitForExistence(timeout: 5),
                        "expected name sheet")
          nameField.tap()
          // Clear default contents and type test name.
          nameField.doubleTap()
          app.menuItems["Select All"].tap()
          nameField.typeText("UITest Document")

          // 5. Save.
          app.buttons["NameSheet.Save"].tap()

          // 6. New row appears in library.
          let row = app.cells.containing(NSPredicate(format: "label CONTAINS[c] %@", "UITest Document")).element
          XCTAssertTrue(row.waitForExistence(timeout: 5),
                        "expected new document row in library")

          // 7. Tap row to open viewer.
          row.tap()

          // 8. Viewer is presented (Edit toggle visible in bottom bar).
          XCTAssertTrue(app.buttons["Viewer.EditToggle"].waitForExistence(timeout: 5),
                        "expected viewer's Edit toggle")

          // 9. Back to library.
          app.navigationBars.buttons.element(boundBy: 0).tap()
          XCTAssertTrue(row.waitForExistence(timeout: 5),
                        "expected to return to library with the row still present")
      }
  }
  ```

- [ ] **Step 3: Run the test**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' -only-testing:DocumentScannerUITests/GoldenPathTests 2>&1 | grep -E "Test case.*(passed|failed)|TEST (SUCCEEDED|FAILED)" | tail -10
  ```

  UI tests are slow (boot simulator, launch app, wait for animations). Expect 30s-60s for this single test.

  If the test fails on a specific step, the error message will name the element it couldn't find. Common adjustments:
  - The "Select All" + `typeText` flow may not clear the existing text reliably. Alternative: `nameField.clearAndType("UITest Document")` via an XCTest helper, or use `nameField.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()` to position cursor at end and use `XCUIKeyboardKey.delete` repeatedly. Pick whichever works.
  - The empty state may have slightly different text — check the exact string in `ContentUnavailableView`.
  - The row's `accessibilityIdentifier` is on the HStack inside DocumentRow but XCUITest finds it as a cell. The `.cells.containing(...)` predicate matches by label rather than identifier. If that fails, try `app.otherElements["Library.Row.UITest Document"]`.

- [ ] **Step 4: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScannerUITests/TestHelpers.swift DocumentScanner/DocumentScannerUITests/GoldenPathTests.swift
  git commit -m "Add golden-path UI test: scan, save, open viewer

  Task 3 of plan-5: launches the app in -UITestMode, drives the
  scan → name → save → row → viewer round trip via XCUITest
  queries against the accessibilityIdentifiers from Task 2.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 4: Edit-mode UI test

**Files:**
- Create: `DocumentScanner/DocumentScannerUITests/EditModeTests.swift`

A second test exercises edit-mode interactions: scan two pages (two passes through stub scanner), reorder, delete one, exit Edit.

- [ ] **Step 1: Implement**

  ```swift
  import XCTest

  final class EditModeTests: XCTestCase {

      @MainActor
      func test_editMode_reorderAndDeletePages() async throws {
          let app = TestHelpers.launchedApp()

          // Create a 2-page document by tapping + → Finish → Save twice...
          // Actually, the stub returns one fixture page per Finish tap. To get a
          // 2-page document, we'd need the stub to return multiple pages, OR we
          // create one doc then use "Add Pages" to append a second page.
          //
          // For this test, we create the doc, then use Add Pages from edit mode.

          // 1. Create initial document.
          app.buttons["Library.AddButton"].tap()
          app.buttons["StubScanner.Finish"].waitForElementOrFail()
          app.buttons["StubScanner.Finish"].tap()
          let nameField = app.textFields["NameSheet.NameField"]
          nameField.waitForElementOrFail()
          nameField.tap()
          nameField.typeText("EditTest")
          app.buttons["NameSheet.Save"].tap()

          // 2. Open document.
          let row = app.cells.containing(NSPredicate(format: "label CONTAINS[c] %@", "EditTest")).element
          row.waitForElementOrFail()
          row.tap()

          // 3. Enter edit mode.
          let editButton = app.buttons["Viewer.EditToggle"]
          editButton.waitForElementOrFail()
          editButton.tap()

          // 4. Add a page via the + tile in the edit strip.
          let addPagesTile = app.buttons["EditMode.AddPages"]
          addPagesTile.waitForElementOrFail()
          addPagesTile.tap()
          app.buttons["StubScanner.Finish"].waitForElementOrFail()
          app.buttons["StubScanner.Finish"].tap()

          // 5. After Add Pages finishes, both page thumbnails should exist.
          let thumb0 = app.otherElements["EditMode.Thumbnail.0"]
          let thumb1 = app.otherElements["EditMode.Thumbnail.1"]
          XCTAssertTrue(thumb0.waitForExistence(timeout: 8))
          XCTAssertTrue(thumb1.waitForExistence(timeout: 8))

          // 6. Long-press thumbnail 1, delete it.
          thumb1.press(forDuration: 1.0)
          app.buttons["Delete page"].waitForElementOrFail()
          app.buttons["Delete page"].tap()

          // 7. Thumbnail 1 is gone (only one page left).
          XCTAssertFalse(app.otherElements["EditMode.Thumbnail.1"].exists,
                         "expected second thumbnail to be removed")
          XCTAssertTrue(app.otherElements["EditMode.Thumbnail.0"].exists,
                        "expected first thumbnail still present")

          // 8. Exit Edit mode.
          editButton.tap()
      }
  }

  private extension XCUIElement {
      func waitForElementOrFail(timeout: TimeInterval = 8) {
          if !waitForExistence(timeout: timeout) {
              XCTFail("element \(self) not found within \(timeout)s")
          }
      }
  }
  ```

- [ ] **Step 2: Run the test**

  ```
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' -only-testing:DocumentScannerUITests/EditModeTests 2>&1 | grep -E "Test case.*(passed|failed)|TEST (SUCCEEDED|FAILED)" | tail -10
  ```

  Watch for: the "Delete page" context menu uses a `Label("Delete page", systemImage: "trash")`. The XCUITest button query is by visible label, so `app.buttons["Delete page"]` should match. If not, try `app.menuItems["Delete page"]` or `.contextMenu.buttons["Delete page"]`.

- [ ] **Step 3: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScannerUITests/EditModeTests.swift
  git commit -m "Add edit-mode UI test: add page, delete page

  Task 4 of plan-5: drives the edit-mode strip — appends a page
  via the Add Pages tile, long-presses to delete the second
  thumbnail, verifies the strip count updates.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 5: Remove default Xcode UI tests

**Files:**
- Delete: `DocumentScanner/DocumentScannerUITests/DocumentScannerUITests.swift`
- Delete: `DocumentScanner/DocumentScannerUITests/DocumentScannerUITestsLaunchTests.swift`

These are template noise generated by Xcode when the UI test target was created. `testLaunchPerformance()` is slow and provides no value.

- [ ] **Step 1: Delete the files**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  rm DocumentScanner/DocumentScannerUITests/DocumentScannerUITests.swift
  rm DocumentScanner/DocumentScannerUITests/DocumentScannerUITestsLaunchTests.swift
  ```

- [ ] **Step 2: Run all tests**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | grep -E "Test case.*(passed|failed)|TEST (SUCCEEDED|FAILED)" | tail -10
  ```

  Expected: all unit tests still pass, plus the 2 new UI tests.

- [ ] **Step 3: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScannerUITests
  git commit -m "Remove default Xcode UI test stubs

  Task 5 of plan-5: the template-generated testExample and
  testLaunchPerformance provided no value (the perf test was
  slow noise). Our golden-path + edit-mode tests cover the
  meaningful flows.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 6: Verify on simulator

The XCUI tests run on the simulator (not on device), so the "smoke test" here is just running the full suite once and confirming everything passes.

- [ ] **Step 1: Full sweep**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)" | tail -3
  ```

  Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Commit milestone**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git commit --allow-empty -m "Milestone: Plan 5 verified in simulator"
  ```

---

## After Plan 5

What lands:

- `-UITestMode` launch arg + StubDocumentScanner for hermetic UI testing.
- 2 XCUITest golden-path tests (scan/save/view, edit mode).
- Default Xcode UI-test noise removed.

That's the original spec complete. All 5 plans (plus 2b, 2c, 4b extensions) shipped.

## Self-review notes

- Spec coverage from the original design doc's Testing section: golden-path UI test ✓, edit-mode happy-path ✓. App-lock UI test (Face ID mocking) skipped — `LAContext` isn't easily mockable through XCUITest without invasive product changes; the existing unit tests for `AppLockSettings` cover the state-machine logic, and the device smoke tests cover the integration.
- Risk: XCUITests can be flaky. Animations, timing, and accessibility-tree updates make them more fragile than unit tests. Generous `waitForExistence(timeout:)` calls mitigate most flakes.
- Risk: `InMemoryLibraryStore` regaining `@Observable` may resurface the deinit-on-MainActor crash if the project ever re-adds `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Linked back in commit message + a code comment.
- Follow-ups: app-lock interaction tests (would require an LAContext seam), error-path tests (camera denied, conflict resolution), filter visual regression tests (would need snapshot infra).
