# Instant Scan Implementation Plan

**Status:** FOLDED into TODO.md

**Status:** COMPLETE — 2026-10-22 (confirmed in daily review)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One "Scan Document" App Intent (Action button, Siri/Spotlight, Control Center, lock screen) opens straight into the camera, silently saves the scan to Main Library, and opens it, with Face ID after capture when the lock is on.

**Architecture:** A main-actor `InstantScanCoordinator` (pure state machine) is the single hand-off point. The intent sets it to "requested". The app root presents the camera with UIKit on the top-most view controller, so it sits above the lock screen and above any open sheet without dismissing anything. `SilentScanSaver` does OCR, naming and the write outside `NameDocumentSheet`. `LockGate` holds back its automatic Face ID prompt while a scan is in flight, and `LibraryView` *pushes* the new document once the app is unlocked. The Controls live in a new iOS 18 widget extension that shares the intent file.

**Tech Stack:** Swift, SwiftUI, UIKit (presentation), VisionKit (existing scanner), App Intents (`OpenIntent`, `AppEnum`, `AppShortcutsProvider`), WidgetKit Controls (`ControlWidget`, `ControlWidgetButton`), XCTest.

**Spec:** `docs/superpowers/specs/2026-10-20-instant-scan-design.md`. Read its "Apple documentation check" section before Task 6.

## Global Constraints

- App deployment target stays **iOS 17.6**; the Controls extension is **iOS 18.0**.
- Use **`OpenIntent`**, not `openAppWhenRun` (deprecated in iOS 26) or `supportedModes` (iOS 26+ only).
- Destination is always **Main Library** (the storage root, `storage.documentsURL`).
- Filter = `@AppStorage("defaultScanFilter")`, paper size = `@AppStorage("scanPaperSize")`, name = `DefaultDocumentName.suggest(from:) ?? DefaultDocumentName.fallback()`.
- With the lock on: **camera → Saving… → saved → Face ID → document**. Nothing from the library, and no page content, is visible before Face ID succeeds.
- **The scan is saved before Face ID.**
- **Never discard unsaved user work.** Never pop the navigation path or dismiss a presented sheet to make room for an instant scan.
- **Nothing leaves the device.** No new network access, no app group, no new entitlements.
- All new user-facing strings ship in **en, es, fr, de, it, zh-Hans** (`scripts/verify-localization.py` `REQUIRED`), and de/it/zh-Hans get a back-translation QA file under `docs/superpowers/qa/`.
- **Never open a target's General tab** (`docs/dev-build.md`, FB24809836). Edit Build Settings only.
- UI-test mode (`-UITestMode`) stays hermetic: `StubDocumentScanner`, no lock gate.
- Unit tests: `./scripts/test.sh` (runs the whole `DocumentScannerTests` target).

## Review Focus

1. **Cold launch with the lock on:** `LockGate`'s launch-time Face ID prompt may already be in flight when the intent's request arrives. Expected: the camera still appears, and at most one Face ID prompt follows after the save. Pinned by `test_autoPrompt_suppressedWhileInstantScanBusy` (Task 3) plus device check D2 (Task 9).
2. **The intent fires while a sheet is open** (naming sheet, signature placement, an alert). Expected: the camera appears on top, and the open sheet and its unsaved state are still there afterwards. Pinned by `test_topMost_walksPresentedChain` (Task 4) plus device check D5.
3. **Face ID cancelled or failed after the save.** Expected: the document is in Main Library, the app stays locked, and the document opens after the next successful unlock. Pinned by `test_documentToOpen_heldUntilUnlocked` (Task 1).
4. **A save that fails** (e.g. a write error). Expected: a "Couldn't save" alert with Retry, the captured images kept for the retry, and no half-written document. Pinned by `test_failure_returnsToCapturedWithImagesKept` (Task 1) and `test_save_writeFailure_throwsAndWritesNothing` (Task 2).
5. **A second request while one is in flight** (a double press of the Action button). Expected: ignored, with one camera and one document. Pinned by `test_request_ignoredWhileBusy` (Task 1).

---

## File map

| File | Responsibility |
|---|---|
| Create `DocumentScanner/DocumentScanner/InstantScan/InstantScanCoordinator.swift` | State machine; the single hand-off between intent, presenter, lock and library |
| Create `DocumentScanner/DocumentScanner/InstantScan/SilentScanSaver.swift` | OCR → name → filter → write to root, no UI |
| Create `DocumentScanner/DocumentScanner/InstantScan/InstantScanPresenter.swift` | UIKit presentation: permission, camera, Saving… view, failure alert |
| Create `DocumentScanner/DocumentScanner/InstantScan/SavingView.swift` | The opaque "Saving…" screen (no page content) |
| Create `DocumentScanner/DocumentScanner/InstantScan/ScanDocumentIntent.swift` | `OpenIntent` + `ScanTarget` `AppEnum`. **Member of the app AND the Controls extension.** |
| Create `DocumentScanner/DocumentScanner/InstantScan/PocketScannerShortcuts.swift` | `AppShortcutsProvider` (app only) |
| Create `DocumentScanner/DocumentScanner/AppShortcuts.xcstrings` | Localized Siri/Spotlight phrases |
| Create `DocumentScanner/PocketScannerControls/` (new target) | `ScanControl.swift`, `PocketScannerControlsBundle.swift`, `Info.plist` |
| Modify `App/DocumentScannerApp.swift` | Own the coordinator; trigger the presenter; drop requests during onboarding |
| Modify `App/LockGate.swift` | Hold back the auto-prompt while busy; prompt once the save lands |
| Modify `Library/LibraryView.swift` | Push the saved document after unlock; review prompt |
| Modify `Settings/Tip.swift`, `Localizable.xcstrings` | New "instant-scan" tip |
| Tests: `DocumentScannerTests/InstantScanCoordinatorTests.swift`, `SilentScanSaverTests.swift`, `InstantScanPresenterTests.swift`, `LockGateAutoPromptTests.swift`, `ScanDocumentIntentTests.swift`; modify `TipTests.swift`; `DocumentScannerUITests/InstantScanTests.swift` | |

The project uses file-system-synchronized groups, so new files in `DocumentScanner/DocumentScanner/` join the app target automatically. Only Task 7 touches target membership.

---

### Task 1: InstantScanCoordinator

**Files:**
- Create: `DocumentScanner/DocumentScanner/InstantScan/InstantScanCoordinator.swift`
- Test: `DocumentScanner/DocumentScannerTests/InstantScanCoordinatorTests.swift`

**Interfaces:**
- Produces:
  ```swift
  @MainActor @Observable final class InstantScanCoordinator {
      static let shared: InstantScanCoordinator
      enum Phase: Equatable { case idle, requested, capturing, saving, saved(URL) }
      private(set) var phase: Phase
      var isBusy: Bool { get }            // requested, capturing or saving
      func request()                      // idle → requested; otherwise ignored
      func beginCapture() -> Bool         // requested → capturing; false otherwise
      func cancel()                       // requested/capturing/saving → idle
      func beginSaving(images: [UIImage]) // capturing → saving; keeps images
      private(set) var capturedImages: [UIImage]
      func saveSucceeded(url: URL)        // saving → saved(url); clears images
      func saveFailed()                   // saving → capturing; capturedImages kept for Retry
      func documentToOpen(isLocked: Bool) -> URL?   // saved(url) && !isLocked → url
      func markOpened()                   // saved → idle
  }
  ```
  After `saveFailed()`, Retry calls `beginSaving(images: capturedImages)` again and Cancel calls `cancel()`. `isBusy` is false in `.idle` and `.saved`.

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor final class InstantScanCoordinatorTests: XCTestCase {
    let url = URL(fileURLWithPath: "/tmp/a.pdf")
    func test_request_fromIdle_becomesRequested() { let c = InstantScanCoordinator(); c.request(); XCTAssertEqual(c.phase, .requested); XCTAssertTrue(c.isBusy) }
    func test_request_ignoredWhileBusy() { let c = InstantScanCoordinator(); c.request(); _ = c.beginCapture(); c.request(); XCTAssertEqual(c.phase, .capturing) }
    func test_beginCapture_onlyFromRequested() { let c = InstantScanCoordinator(); XCTAssertFalse(c.beginCapture()); c.request(); XCTAssertTrue(c.beginCapture()) }
    func test_cancel_returnsToIdle() { let c = InstantScanCoordinator(); c.request(); _ = c.beginCapture(); c.cancel(); XCTAssertEqual(c.phase, .idle); XCTAssertFalse(c.isBusy) }
    func test_failure_returnsToCapturedWithImagesKept() {
        let c = InstantScanCoordinator(); c.request(); _ = c.beginCapture()
        c.beginSaving(images: [UIImage(), UIImage()]); c.saveFailed()
        XCTAssertEqual(c.phase, .capturing); XCTAssertEqual(c.capturedImages.count, 2)
    }
    func test_documentToOpen_heldUntilUnlocked() {
        let c = InstantScanCoordinator(); c.request(); _ = c.beginCapture(); c.beginSaving(images: [UIImage()]); c.saveSucceeded(url: url)
        XCTAssertNil(c.documentToOpen(isLocked: true)); XCTAssertFalse(c.isBusy)
        XCTAssertEqual(c.documentToOpen(isLocked: false), url)
        c.markOpened(); XCTAssertEqual(c.phase, .idle); XCTAssertTrue(c.capturedImages.isEmpty)
    }
}
```

- [ ] **Step 2: Run `./scripts/test.sh`.** Expected: FAIL, "cannot find 'InstantScanCoordinator' in scope".
- [ ] **Step 3: Implement `InstantScanCoordinator`** per the Interfaces block. Give it an `internal init()` for tests; `shared` is the app's instance. Transitions that don't apply are no-ops.
- [ ] **Step 4: Run `./scripts/test.sh`.** Expected: all pass (`** TEST SUCCEEDED **`).
- [ ] **Step 5: Commit** `feat: InstantScanCoordinator state machine for instant scan`

---

### Task 2: SilentScanSaver

**Files:**
- Create: `DocumentScanner/DocumentScanner/InstantScan/SilentScanSaver.swift`
- Test: `DocumentScanner/DocumentScannerTests/SilentScanSaverTests.swift`

**Interfaces:**
- Consumes: `ScanPipeline.recognize(images:)`, `ScanPipeline.assemble(pages:filter:paperSize:createdAt:)`, `DocumentStorage.write(_:preferredName:) -> URL`, `DefaultDocumentName.suggest(from:now:)` / `.fallback(now:)`.
- Produces: `struct SilentScanSaver { let pipeline: ScanPipeline; let storage: DocumentStorage; func save(images: [UIImage], filter: ImageFilter, paperSize: PaperSize, now: Date = .init()) async throws -> URL }`. It writes to `storage.documentsURL` (root). The name comes from the OCR text through `suggest`, falling back to `fallback(now:)`.

- [ ] **Step 1: Write the failing tests.** Define a local `StubOCR: OCRProviding` that returns fixed strings, like the private one in `ScanPipelineTests`. Use a temp directory for `DocumentStorage`.
  - `test_save_writesPDFAtRootNamedFromOCR`: OCR text that `DefaultDocumentName.suggest` maps to a known name (take a fixture from `DefaultDocumentNameTests`). Assert the returned URL's parent is the temp root, `lastPathComponent == "<that name>.pdf"`, and that `PDFDocument(url:)` has a page count equal to the image count.
  - `test_save_noSuggestion_usesFallbackName`: OCR returns `[]`; with a fixed `now`, assert the name equals `DefaultDocumentName.fallback(now: now) + ".pdf"`.
  - `test_save_writeFailure_throwsAndWritesNothing`: storage rooted at a non-existent, unwritable path (`/dev/null/x`). `XCTAssertThrowsError`, and assert the temp root has no `.pdf` files.
- [ ] **Step 2: Run `./scripts/test.sh`.** Expected: FAIL, "cannot find 'SilentScanSaver'".
- [ ] **Step 3: Implement `save`.** Call `recognize` first, then `assemble`, in the same order as `NameDocumentSheet.save()`.
- [ ] **Step 4: Run `./scripts/test.sh`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: SilentScanSaver: OCR, auto-name and save to Main Library without the sheet`

---

### Task 3: LockGate defers its auto-prompt during an instant scan

**Files:**
- Modify: `DocumentScanner/DocumentScanner/App/LockGate.swift`
- Test: `DocumentScanner/DocumentScannerTests/LockGateAutoPromptTests.swift`

**Interfaces:**
- Consumes: `InstantScanCoordinator.isBusy`.
- Produces: `LockGate` gains `let instantScan: InstantScanCoordinator`, plus a pure `static func shouldAutoPrompt(isLocked: Bool, instantScanBusy: Bool) -> Bool` (`isLocked && !instantScanBusy`).

- [ ] **Step 1: Write the failing tests**

```swift
func test_autoPrompt_whenLockedAndIdle() { XCTAssertTrue(LockGate<EmptyView>.shouldAutoPrompt(isLocked: true, instantScanBusy: false)) }
func test_autoPrompt_suppressedWhileInstantScanBusy() { XCTAssertFalse(LockGate<EmptyView>.shouldAutoPrompt(isLocked: true, instantScanBusy: true)) }
func test_autoPrompt_neverWhenUnlocked() { XCTAssertFalse(LockGate<EmptyView>.shouldAutoPrompt(isLocked: false, instantScanBusy: false)) }
```

- [ ] **Step 2: Run `./scripts/test.sh`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Change `.task(id: lockSettings.isLocked)` to key on a `Hashable` pair `(isLocked, instantScan.isBusy)` and prompt only when `shouldAutoPrompt` is true. That way, when the save finishes (`isBusy` turns false) and the app is still locked, the prompt fires once. Update both `LockGate(...)` call sites in `DocumentScannerApp.swift` to pass `InstantScanCoordinator.shared`.
- [ ] **Step 4: Run `./scripts/test.sh`.** Expected: PASS, including the existing `AppLockSettingsTests`.
- [ ] **Step 5: Commit** `feat: LockGate holds Face ID until an instant scan has saved`

---

### Task 4: InstantScanPresenter and root wiring

**Files:**
- Create: `InstantScan/InstantScanPresenter.swift`, `InstantScan/SavingView.swift`
- Modify: `App/DocumentScannerApp.swift`
- Test: `DocumentScanner/DocumentScannerTests/InstantScanPresenterTests.swift`

**Interfaces:**
- Consumes: Task 1 (coordinator), Task 2 (`SilentScanSaver`), `DocumentScannerPresenting.makeViewController(onFinish:onCancel:)`, `CameraPermission.request()`, `CameraDeniedView(onDismiss:)`, `AlertCenter`.
- Produces:
  - `@MainActor struct InstantScanPresenter { let scanner: DocumentScannerPresenting; let saver: SilentScanSaver; let coordinator: InstantScanCoordinator; let alertCenter: AlertCenter; func start(from root: UIViewController) async }`
  - `static func topMost(from root: UIViewController) -> UIViewController` follows `presentedViewController` to the end of the chain.
  - `SavingView`: an opaque `systemBackground` screen with a `ProgressView` and the text "Saving…" (`String(localized: "Saving…", comment: "Instant scan: shown while the scan is recognised and saved")`). It shows no image.

- [ ] **Step 1: Write the failing test** `test_topMost_walksPresentedChain`. Build a `UIWindow` with root A, present B from A and C from B, all `animated: false`, then wait for the presentations to complete. Assert `topMost(from: A) === C`, and that `topMost` of a controller with nothing presented returns itself.
- [ ] **Step 2: Run `./scripts/test.sh`.** Expected: FAIL.
- [ ] **Step 3: Implement `start(from:)`:**
  1. `guard coordinator.beginCapture() else { return }`.
  2. Run `CameraPermission.request()`. If `.denied`, present a `UIHostingController(CameraDeniedView)` on `topMost`, then call `coordinator.cancel()` on dismiss.
  3. Present the scanner's view controller **full screen** on `topMost(from: root)`.
  4. `onCancel`: dismiss, then `coordinator.cancel()`.
  5. `onFinish(images)`: replace the camera with `UIHostingController(SavingView())` (dismiss the camera without animation and present Saving in the same run-loop turn, so the lock screen behind never flashes), then `coordinator.beginSaving(images:)`. Next, `try await saver.save(images:filter:paperSize:)` with the Global Constraints values read from `UserDefaults`.
     - Success: `coordinator.saveSucceeded(url:)`, then dismiss Saving.
     - Failure: `coordinator.saveFailed()`, dismiss Saving, then present the "Couldn't save" alert through `alertCenter`, with Retry re-running the save from `coordinator.capturedImages` and Cancel → `coordinator.cancel()`. Reuse the existing strings from `NameDocumentSheet` ("Couldn't save", "Retry", "Cancel").
- [ ] **Step 4: Wire it in `DocumentScannerApp`.**
  - Hold `@State private var instantScan = InstantScanCoordinator.shared`.
  - Add `.task(id: instantScan.phase == .requested)` at the root `Group`. When the phase is requested:
    - If the onboarding branch is showing (`!iCloudOnboardingDismissed && !iCloudAvailable`), call `instantScan.cancel()` (the spec allows dropping the request).
    - Otherwise find the key window's root view controller (`UIApplication.shared.connectedScenes` → `UIWindowScene` → `keyWindow?.rootViewController`) and call `InstantScanPresenter(...).start(from:)`.
  - Build the saver from the same `DocumentStorage` the visible branch passes to `LibraryView`: `resolvedDocumentsURL` (iCloud), `container.localDocumentsURL` (local-only), or `testStorage` (UI-test mode).
- [ ] **Step 5: Run `./scripts/test.sh`.** Expected: PASS. Build with `xcodebuild build -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'generic/platform=iOS Simulator'`. Expected: `** BUILD SUCCEEDED **`, no new warnings.
- [ ] **Step 6: Commit** `feat: present instant scan camera above everything and save silently`

---

### Task 5: Open the saved document, plus an end-to-end UI test

**Files:**
- Modify: `Library/LibraryView.swift`, `App/DocumentScannerApp.swift` (UI-test hook)
- Test: `DocumentScanner/DocumentScannerUITests/InstantScanTests.swift`

**Interfaces:**
- Consumes: `InstantScanCoordinator.documentToOpen(isLocked:)`, `.markOpened()`, `DocumentSummary.fromFile(at:)`, `DocumentRoute(summary:term:scope:)`.
- Produces: launch argument `-InstantScanOnLaunch`, honoured **only together with `-UITestMode`**, which calls `InstantScanCoordinator.shared.request()` on launch.

- [ ] **Step 1: Write the failing UI test** `test_instantScan_savesToMainLibrary_andOpensViewer`:
  - Launch with `["-UITestMode", "-InstantScanOnLaunch"]`, using the `TestHelpers` launch pattern.
  - Complete the `StubDocumentScanner` capture the way `GoldenPathTests` does.
  - Assert the viewer is showing with no `NameSheet.Save` button ever appearing.
  - Tap Back, then assert the library lists exactly one document.
- [ ] **Step 2: Run** `xcodebuild test -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination '<booted sim id>' -only-testing:DocumentScannerUITests/InstantScanTests`. Expected: FAIL (the viewer never opens).
- [ ] **Step 3: Implement in `LibraryView`.**
  - Observe `InstantScanCoordinator.shared`. On `.onChange` of `(phase, lockSettings.isLocked)`, if `documentToOpen(isLocked:)` returns a URL, **append** `DocumentRoute(summary: .fromFile(at: url), term: "", scope: .library)` to `path`. Never reset the path.
  - Only append if the window's root view controller has no `presentedViewController`. If a sheet is open, skip the append and just call `markOpened()`: the document is in Main Library and opening it isn't worth disturbing the sheet.
  - Then call `store.refresh()`, `markOpened()` and `reviewPrompt.recordSuccessAndMaybeRequest(using: requestReview)`.
  - Add the `-InstantScanOnLaunch` hook in `DocumentScannerApp`.
- [ ] **Step 4: Run the UI test again, then `./scripts/test.sh`.** Expected: both PASS.
- [ ] **Step 5: Commit** `feat: open the instant-scanned document once unlocked`

---

### Task 6: ScanDocumentIntent and App Shortcuts

**Files:**
- Create: `InstantScan/ScanDocumentIntent.swift`, `InstantScan/PocketScannerShortcuts.swift`, `DocumentScanner/DocumentScanner/AppShortcuts.xcstrings`
- Test: `DocumentScanner/DocumentScannerTests/ScanDocumentIntentTests.swift`

**Interfaces:**
- Consumes: `InstantScanCoordinator.shared.request()`.
- Produces:
  - `enum ScanTarget: String, AppEnum { case scanner }`, display "Scanner".
  - `struct ScanDocumentIntent: OpenIntent`, with title `"Scan Document"`, `@Parameter(title: "Target") var target: ScanTarget`, and `init()` defaulting to `.scanner`.
  - `perform()` runs `await InstantScanCoordinator.shared.request()` and returns `.result()`. Wrap that body in `#if !CONTROLS_EXTENSION`; the extension's copy just returns `.result()`, because the system runs `OpenIntent` in the app.
  - `struct PocketScannerShortcuts: AppShortcutsProvider`, with one `AppShortcut(intent: ScanDocumentIntent(), phrases: ["Scan with \(.applicationName)", "Scan a document with \(.applicationName)"], shortTitle: "Scan Document", systemImageName: "doc.viewfinder")`.

- [ ] **Step 1: Write the failing test** `test_perform_requestsInstantScan`: reset `shared` to idle (add an `internal func resetForTesting()` to the coordinator in this task), run `_ = try await ScanDocumentIntent().perform()`, then assert `shared.phase == .requested`.
- [ ] **Step 2: Run `./scripts/test.sh`.** Expected: FAIL.
- [ ] **Step 3: Implement both types.** Add `AppShortcuts.xcstrings` with the two phrases and the short title in es, fr, de, it and zh-Hans. Each phrase must keep the `${applicationName}` token.
- [ ] **Step 4: Run `./scripts/test.sh` and the Step 5 build from Task 4.** Expected: PASS, and the build log shows `appintentsmetadataprocessor` with no errors.
- [ ] **Step 5: Commit** `feat: Scan Document App Intent and Siri/Spotlight shortcut`

---

### Task 7: Controls widget extension (Control Center, lock screen, Action button)

**Files:**
- Create (Xcode): target `PocketScannerControls` at `DocumentScanner/PocketScannerControls/`
- Create: `PocketScannerControls/ScanControl.swift`, `PocketScannerControls/PocketScannerControlsBundle.swift`
- Modify: target membership of `InstantScan/ScanDocumentIntent.swift` (app **and** extension)

**Interfaces:**
- Consumes: `ScanDocumentIntent`, `ScanTarget` (Task 6).
- Produces:
  - `struct ScanControl: ControlWidget`, using `StaticControlConfiguration(kind: "ca.peter-jones.DocumentScanner.ScanControl")` → `ControlWidgetButton(action: ScanDocumentIntent()) { Label("Scan Document", systemImage: "doc.viewfinder") }`, plus `.displayName("Scan Document")` and `.description("Open Pocket Scanner straight into the camera.")`.
  - `@main struct PocketScannerControlsBundle: WidgetBundle { var body: some Widget { ScanControl() } }`.

- [ ] **Step 1 (Peter, in Xcode):** File ▸ New ▸ Target ▸ Widget Extension. Name it `PocketScannerControls`, tick **Include Control**, untick Live Activity and Configuration Intent, and embed it in DocumentScanner. **When Xcode opens the new target's General tab, close it immediately without touching anything**, then check the app target with Step 3 below. Delete the template's sample widget and control files.
- [ ] **Step 2: Build Settings for `PocketScannerControls`** (Build Settings only):
  - `IPHONEOS_DEPLOYMENT_TARGET = 18.0`.
  - `PRODUCT_BUNDLE_IDENTIFIER` = `ca.peter-jones.DocumentScanner.Controls` (Release) and `ca.peter-jones.DocumentScanner.dev.Controls` (Debug).
  - `SWIFT_ACTIVE_COMPILATION_CONDITIONS` += `CONTROLS_EXTENSION`.
  - No entitlements file.
  - Add `ScanDocumentIntent.swift` to the extension through a `PBXFileSystemSynchronizedBuildFileExceptionSet` membership exception, or the File Inspector's Target Membership.
- [ ] **Step 3: Verify identity.** Run `xcodebuild -project DocumentScanner/DocumentScanner.xcodeproj -target DocumentScanner -configuration Release -showBuildSettings | grep -E "PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_NAME|CODE_SIGN_ENTITLEMENTS"`. Expected: `ca.peter-jones.DocumentScanner` and `DocumentScanner.entitlements`, unchanged. Repeat with `-target PocketScannerControls` for both configurations. Expected: the two `.Controls` IDs above.
- [ ] **Step 4: Write `ScanControl` and the bundle.** Then build both configurations: Debug with `xcodebuild build … -configuration Debug -destination 'generic/platform=iOS Simulator'`, and Release with `-configuration Release`. Release runs the "Verify Release identity" phase. Expected: `** BUILD SUCCEEDED **` for both, with the guard passing.
- [ ] **Step 5: Run `./scripts/test.sh`.** Expected: PASS.
- [ ] **Step 6: Commit** `feat: Scan Document control for Control Center, lock screen and Action button`

---

### Task 8: Tip and localization QA

**Files:**
- Modify: `Settings/Tip.swift`, `Localizable.xcstrings`, `DocumentScannerTests/TipTests.swift`
- Create: `docs/superpowers/qa/2026-10-20-instant-scan-back-translation.md`

- [ ] **Step 1: Write the failing test** `test_instantScanTip_isPresent`: `XCTAssertTrue(Tip.all.contains { $0.id == "instant-scan" })`.
- [ ] **Step 2: Run `./scripts/test.sh`.** Expected: FAIL.
- [ ] **Step 3: Add the tip at the top of `Tip.all`** (it's the newest "everyday trick"):
  - title: "Scan in one press"
  - body: "Add Scan Document to the Action button, Control Center or the Lock Screen, or say “Scan with Pocket Scanner” to Siri. The camera opens straight away and the scan saves to Main Library."
  - Use `comment: "Tip title"` and `"Tip body"`. Translate it, plus "Saving…", into es, fr, de, it and zh-Hans in `Localizable.xcstrings`.
- [ ] **Step 4: Run `./scripts/test.sh` and `python3 scripts/verify-localization.py`.** Expected: PASS and no missing keys.
- [ ] **Step 5: Write the back-translation QA file** for de, it and zh-Hans. Cover the tip, "Saving…", the two App Shortcut phrases, "Scan Document", and the control description. Follow the format of `docs/superpowers/qa/2026-09-25-zh-Hans-back-translation.md`, and flag anything that back-translates oddly.
- [ ] **Step 6: Commit** `feat: instant scan tip, localized in six languages, with back-translation QA`

---

### Task 9: Device verification (Peter, on iPhone, Dev build)

No code. Record the results in the PR or commit message. Each check is pass/fail:

- **D1 Warm, lock off:** with the app in the background, press the Action button (assigned to Scan Document). The camera appears, Saving… shows, the document opens in the viewer, and Back lands on the library.
- **D2 Cold, lock on:** force-quit the app, then press the Action button. The camera appears with no Face ID first. Then Saving…, exactly one Face ID prompt, and the document opens.
- **D3 Face ID cancelled after the save:** the app stays on the lock screen and nothing is visible. Unlock with the button: the scanned document opens and is in Main Library.
- **D4 Camera cancelled:** no document is created, and the app shows its normal state (locked, if the lock is on).
- **D5 Sheet open:** start Sign on a document so placement is showing, then press the Action button. The camera appears on top. After the save, the placement sheet is still there, unchanged, and the new document is in Main Library.
- **D6 Control Center and lock-screen buttons (iOS 18+):** both start the same flow. From a locked phone, iOS asks for the phone's unlock first (expected).
- **D7 Siri:** "Scan with Pocket Scanner Dev" starts the same flow.
- **D8 Tip:** it appears first under Settings ▸ About ▸ Tips, in English and in one other language.
