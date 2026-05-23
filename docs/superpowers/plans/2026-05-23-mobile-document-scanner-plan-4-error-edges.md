# Mobile Document Scanner — Plan 4: Error edges + cleanup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app resilient in failure modes that the happy path doesn't see. iCloud unavailable, camera permission denied, storage full, multi-device conflicts, corrupt PDFs. Plus one known cleanup: strip search-highlight annotations before saving so they don't bake into the on-disk PDF.

**Architecture:** A small `AlertCenter` (`@MainActor @Observable` singleton-style) gives any view a path to surface a user-facing error alert without prop-drilling. A new `Errors/` module groups the pieces. iCloud-unavailable onboarding gates the app shell behind an `@AppStorage` first-launch flag. Camera permission is checked before presenting `CaptureSheet`. Conflicts are detected via `NSFileVersion.unresolvedConflictVersionsOfItem(at:)` on document open. Corrupt PDFs are surfaced as a distinct `DocumentSummary` variant rather than silently dropped.

**Tech Stack:** SwiftUI, `LocalAuthentication` (already), `AVFoundation` (`AVCaptureDevice.authorizationStatus(for:)`), `Foundation` (`NSFileVersion`, `NSFileCoordinator`), `OSLog`.

**Spec:** [`docs/superpowers/specs/2026-05-21-mobile-document-scanner-design.md`](../specs/2026-05-21-mobile-document-scanner-design.md) — Error handling section.

**Prerequisite plans:** Plans 1, 2a, 2b, 3, 2c all completed and verified on device.

---

## A note for the first-time iOS developer

A few new iOS pieces here:

- **`AVCaptureDevice.authorizationStatus(for: .video)`** returns one of `.notDetermined / .authorized / .denied / .restricted`. We can check before showing the scanner; if denied/restricted, show an explainer with an "Open Settings" button.
- **`UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`** deep-links to the user's per-app Settings page where they can flip the camera switch.
- **`NSFileVersion`** is iOS's wrapper around iCloud version metadata. When two devices edit a file at once, iCloud doesn't merge — it stores conflict versions. `unresolvedConflictVersionsOfItem(at:)` returns them; we present a picker, then mark the user's choice with `.replaceItem(at:)` or `.isResolved = true`.
- **`@AppStorage`** persists a small value into `UserDefaults`. Useful for first-launch flags like "did the user dismiss the onboarding."

## File structure (target end-state of Plan 4)

```text
DocumentScanner/
  Errors/                                   # NEW module
    AppAlert.swift                          # value type: title + message + buttons
    AlertCenter.swift                       # @MainActor @Observable, view-mounted via .alert
  Onboarding/                               # NEW module
    ICloudOnboardingView.swift              # first-launch explainer + "Try anyway"
  Capture/
    CameraPermission.swift                  # NEW: AVCaptureDevice auth status wrapper
    CameraDeniedView.swift                  # NEW: explainer + Open Settings button
    CaptureSheet.swift                      # MODIFY: gate on CameraPermission
  Viewer/
    ConflictResolutionView.swift            # NEW: picker for NSFileVersion conflicts
    DocumentSession.swift                   # MODIFY: detect conflicts; strip highlights before save
  Library/
    DocumentSummary.swift                   # MODIFY: corrupt-PDF variant
    DocumentRow.swift                       # MODIFY: warning icon + context menu for corrupt
    LibraryStore.swift                      # MODIFY: don't drop corrupt PDFs
  App/
    DocumentScannerApp.swift                # MODIFY: gate behind ICloudOnboardingView + mount AlertCenter
DocumentScannerTests/
  AlertCenterTests.swift                    # NEW
  DocumentSummaryCorruptTests.swift         # NEW
  DocumentSessionStripHighlightsTests.swift # NEW
```

After Plan 4:

- First launch without iCloud → onboarding sheet with "Open Settings" and "Try anyway (local only)".
- Tap + with camera denied → in-sheet explainer with Open Settings button instead of immediate dismissal.
- Save fails for any reason → toast/alert with Retry; in-memory PDF held.
- Open a doc that has iCloud conflicts → picker before the viewer renders.
- Corrupt PDFs show in the library with 🚫 + context-menu delete/recover.
- Search highlights never bake into saved PDFs.

---

## Task 1: AppAlert + AlertCenter

**Files:**
- Create: `DocumentScanner/DocumentScanner/Errors/AppAlert.swift`
- Create: `DocumentScanner/DocumentScanner/Errors/AlertCenter.swift`
- Create: `DocumentScanner/DocumentScannerTests/AlertCenterTests.swift`

Small infrastructure that any code path can use to surface a user-facing error without dragging a `@State var someError: ...` through every view layer.

- [ ] **Step 1: Write the failing tests**

  ```swift
  import XCTest
  @testable import DocumentScanner

  @MainActor
  final class AlertCenterTests: XCTestCase {

      func test_present_setsCurrent() {
          let center = AlertCenter()
          XCTAssertNil(center.current)
          center.present(AppAlert(title: "Hi", message: "Hello"))
          XCTAssertNotNil(center.current)
          XCTAssertEqual(center.current?.title, "Hi")
      }

      func test_dismiss_clearsCurrent() {
          let center = AlertCenter()
          center.present(AppAlert(title: "Hi", message: "Hello"))
          center.dismiss()
          XCTAssertNil(center.current)
      }

      func test_present_replacesExistingAlert() {
          let center = AlertCenter()
          center.present(AppAlert(title: "First", message: ""))
          center.present(AppAlert(title: "Second", message: ""))
          XCTAssertEqual(center.current?.title, "Second")
      }
  }
  ```

- [ ] **Step 2: Run, see failure**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild test -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' -only-testing:DocumentScannerTests/AlertCenterTests 2>&1 | tail -10
  ```

- [ ] **Step 3: Implement**

  `Errors/AppAlert.swift`:

  ```swift
  import Foundation

  /// A user-facing alert. `primary` is the default action; `secondary` is
  /// optional (e.g., for a destructive choice in a confirmation alert).
  struct AppAlert: Identifiable, Equatable {
      let id = UUID()
      let title: String
      let message: String
      let primary: Action
      let secondary: Action?

      static func == (lhs: AppAlert, rhs: AppAlert) -> Bool { lhs.id == rhs.id }

      struct Action: Equatable {
          let title: String
          let role: Role
          let handler: (@MainActor () -> Void)?

          enum Role { case `default`, cancel, destructive }

          static func == (lhs: Action, rhs: Action) -> Bool {
              lhs.title == rhs.title && lhs.role == rhs.role
          }
      }

      init(title: String,
           message: String,
           primary: Action = Action(title: "OK", role: .default, handler: nil),
           secondary: Action? = nil) {
          self.title = title
          self.message = message
          self.primary = primary
          self.secondary = secondary
      }
  }
  ```

  `Errors/AlertCenter.swift`:

  ```swift
  import Foundation
  import Observation

  /// Thin presenter for user-facing alerts. A single instance lives at the
  /// app root and is bound by a `.alert` modifier. Any view or service that
  /// needs to surface an error reaches it via `@Environment` or by passing
  /// it explicitly.
  @MainActor
  @Observable
  final class AlertCenter {
      private(set) var current: AppAlert?

      func present(_ alert: AppAlert) { current = alert }
      func dismiss() { current = nil }
  }
  ```

- [ ] **Step 4: Tests pass**

- [ ] **Step 5: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Errors/AppAlert.swift DocumentScanner/DocumentScanner/Errors/AlertCenter.swift DocumentScanner/DocumentScannerTests/AlertCenterTests.swift
  git commit -m "Add AppAlert + AlertCenter: app-wide error surface

  Task 1 of plan-4: a small value type for user-facing alerts and
  a @MainActor @Observable presenter. The view layer mounts a
  .alert modifier bound to AlertCenter.current; any service or view
  can call present(_:) to surface an error without prop-drilling.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 2: Mount AlertCenter in the app shell

**Files:**
- Modify: `DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift`

Wire `AlertCenter` as an `@State` at the App level and inject it as an `@Environment` value so any descendant view can present alerts.

- [ ] **Step 1: Add an environment key for AlertCenter**

  Append to `Errors/AlertCenter.swift`:

  ```swift
  import SwiftUI

  private struct AlertCenterKey: EnvironmentKey {
      @MainActor static let defaultValue = AlertCenter()
  }

  extension EnvironmentValues {
      var alertCenter: AlertCenter {
          get { self[AlertCenterKey.self] }
          set { self[AlertCenterKey.self] = newValue }
      }
  }
  ```

- [ ] **Step 2: Inject + mount at root**

  In `DocumentScannerApp.swift`, add a new `@State`:

  ```swift
  @State private var alertCenter = AlertCenter()
  ```

  Wrap the body's content in an `.environment(\.alertCenter, alertCenter)` modifier, and add a global `.alert(item:)` that drives off `alertCenter.current`:

  ```swift
  WindowGroup {
      LockGate(lockSettings: lockSettings) {
          PrivacyBlurOverlay {
              LibraryView(
                  store: store,
                  scannerPresenter: scannerPresenter,
                  storage: DocumentStorage(documentsURL: container.resolveDocumentsURL()),
                  pipeline: pipeline,
                  lockSettings: lockSettings
              )
          }
      }
      .environment(\.alertCenter, alertCenter)
      .alert(item: Binding(
          get: { alertCenter.current },
          set: { _ in alertCenter.dismiss() }
      )) { alert in
          appAlert(alert)
      }
  }
  ```

  Add a helper outside the `body`:

  ```swift
  @MainActor
  private func appAlert(_ alert: AppAlert) -> Alert {
      let primaryButton = button(from: alert.primary)
      if let secondary = alert.secondary {
          return Alert(title: Text(alert.title),
                       message: Text(alert.message),
                       primaryButton: primaryButton,
                       secondaryButton: button(from: secondary))
      }
      return Alert(title: Text(alert.title),
                   message: Text(alert.message),
                   dismissButton: primaryButton)
  }

  private func button(from action: AppAlert.Action) -> Alert.Button {
      switch action.role {
      case .cancel:
          return .cancel(Text(action.title)) { action.handler?() }
      case .destructive:
          return .destructive(Text(action.title)) { action.handler?() }
      case .default:
          return .default(Text(action.title)) { action.handler?() }
      }
  }
  ```

  Note: SwiftUI's `Alert` is deprecated in iOS 15+ in favor of `.alert(_:isPresented:actions:message:)` but the `.alert(item:)` flavor is still supported and is the easiest for our identified-alert pattern. If the build flags a deprecation warning, swap to the actions-based variant.

- [ ] **Step 3: Build**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner/DocumentScanner
  xcodebuild build -scheme DocumentScanner -destination 'id=B762C669-0A64-4665-8C00-10BD6628CBA2' 2>&1 | grep -E "warning:|error:|BUILD (SUCCEEDED|FAILED)" | grep -v "^ld:\|appintentsmetadataprocessor" | head -10
  ```

- [ ] **Step 4: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift DocumentScanner/DocumentScanner/Errors/AlertCenter.swift
  git commit -m "Mount AlertCenter at the app root and expose via @Environment

  Task 2 of plan-4: a single AlertCenter @State at the App level
  drives a .alert(item:) modifier above the lock gate and privacy
  blur. Descendant views receive the center via the new
  \\.alertCenter environment key.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 3: Strip search-highlight annotations before save

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift`
- Create: `DocumentScanner/DocumentScannerTests/DocumentSessionStripHighlightsTests.swift`

Plan 2c added `PDFAnnotation`s with a custom `userName` tag for search highlights. They're meant to be view-only — strip them in `DocumentSession.save()` so they never persist to disk.

- [ ] **Step 1: Add a public tag constant + write the failing test**

  We need to share the annotation tag between the viewer and the session. Add a static constant to `DocumentSession`:

  Test:

  ```swift
  import XCTest
  import PDFKit
  @testable import DocumentScanner

  @MainActor
  final class DocumentSessionStripHighlightsTests: XCTestCase {

      func test_save_stripsSearchHighlightAnnotations() throws {
          // Build a PDF with both a user annotation and one of our search-highlight
          // annotations. After save, only the user annotation should remain.
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
          let page = try XCTUnwrap(pdf.page(at: 0))
          let pageBounds = page.bounds(for: .mediaBox)

          // User annotation (untagged) — should survive.
          let userAnnotation = PDFAnnotation(bounds: pageBounds, forType: .highlight, withProperties: nil)
          userAnnotation.userName = "user-added"
          page.addAnnotation(userAnnotation)

          // Search-highlight annotation (tagged) — should be stripped on save.
          let searchAnnotation = PDFAnnotation(bounds: pageBounds, forType: .highlight, withProperties: nil)
          searchAnnotation.userName = DocumentSession.searchHighlightAnnotationName
          page.addAnnotation(searchAnnotation)

          let storage = DocumentStorage(documentsURL: tempDir)
          let initialURL = try storage.write(pdf, preferredName: "Test")

          let summary = DocumentSummary(url: initialURL, displayName: "Test",
                                        createdAt: Date(), pageCount: 1, ocrSnippet: "")
          let session = try DocumentSession(summary: summary, storage: storage)

          // Re-attach a search annotation to the session's in-memory PDF (mimics what
          // the viewer's highlight code does).
          let sessionPage = try XCTUnwrap(session.pdf.page(at: 0))
          let highlight = PDFAnnotation(bounds: pageBounds, forType: .highlight, withProperties: nil)
          highlight.userName = DocumentSession.searchHighlightAnnotationName
          sessionPage.addAnnotation(highlight)

          // Sanity: in-memory PDF has both kinds of annotation now.
          XCTAssertEqual(sessionPage.annotations.count, 2)

          _ = try session.save()

          // Reload from disk and check what survived.
          let reloaded = try XCTUnwrap(PDFDocument(url: initialURL))
          let reloadedPage = try XCTUnwrap(reloaded.page(at: 0))
          let usernames = reloadedPage.annotations.compactMap(\.userName)
          XCTAssertTrue(usernames.contains("user-added"))
          XCTAssertFalse(usernames.contains(DocumentSession.searchHighlightAnnotationName))
      }
  }
  ```

- [ ] **Step 2: Run, see failure**

- [ ] **Step 3: Implement**

  In `DocumentSession.swift`:

  (a) Add the constant inside the class:

  ```swift
  /// Annotation `userName` that marks PDFAnnotations added by the search-highlight
  /// view layer. `save()` strips these before writing so they don't persist.
  static let searchHighlightAnnotationName = "DocumentScanner.searchHighlight"
  ```

  (b) Update `save()` to strip them:

  ```swift
  @discardableResult
  func save() throws -> URL {
      stripSearchHighlightAnnotations()
      let newURL = try storage.write(pdf, replacing: url, withName: displayName)
      self.url = newURL
      return newURL
  }

  private func stripSearchHighlightAnnotations() {
      for i in 0..<pdf.pageCount {
          guard let page = pdf.page(at: i) else { continue }
          for annotation in page.annotations
              where annotation.userName == Self.searchHighlightAnnotationName {
              page.removeAnnotation(annotation)
          }
      }
  }
  ```

  (c) Update `Viewer/DocumentViewerView.swift` `PDFKitView.annotationUserName` to use the same constant:

  Find:
  ```swift
  private static let annotationUserName = "DocumentScanner.searchHighlight"
  ```

  Replace with:
  ```swift
  private static let annotationUserName = DocumentSession.searchHighlightAnnotationName
  ```

- [ ] **Step 4: Tests pass; full suite stays green**

- [ ] **Step 5: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift DocumentScanner/DocumentScannerTests/DocumentSessionStripHighlightsTests.swift
  git commit -m "Strip search-highlight annotations in DocumentSession.save

  Task 3 of plan-4: PDFAnnotations our viewer adds for search results
  carry a known tag (DocumentSession.searchHighlightAnnotationName).
  save() removes them before writing so they don't bake into the
  on-disk PDF — the highlights are presentation-only.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 4: Camera permission gating

**Files:**
- Create: `DocumentScanner/DocumentScanner/Capture/CameraPermission.swift`
- Create: `DocumentScanner/DocumentScanner/Capture/CameraDeniedView.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/LibraryView.swift`

Check `AVCaptureDevice.authorizationStatus(for: .video)` before presenting the scanner. If denied/restricted, show an explainer with an Open Settings button instead of opening the sheet.

- [ ] **Step 1: Implement `CameraPermission`**

  ```swift
  import AVFoundation

  /// Lightweight wrapper around AVFoundation's camera authorization API.
  struct CameraPermission {

      enum Status { case authorized, denied, notDetermined }

      /// Synchronous current status. Use this when deciding which UI to show.
      static var current: Status {
          switch AVCaptureDevice.authorizationStatus(for: .video) {
          case .authorized: return .authorized
          case .notDetermined: return .notDetermined
          case .denied, .restricted: return .denied
          @unknown default: return .denied
          }
      }

      /// Trigger the system permission prompt when status is .notDetermined.
      /// Returns the resulting status. Has no effect if status is already
      /// .authorized or .denied.
      static func request() async -> Status {
          if current != .notDetermined { return current }
          _ = await AVCaptureDevice.requestAccess(for: .video)
          return current
      }
  }
  ```

- [ ] **Step 2: Implement `CameraDeniedView`**

  ```swift
  import SwiftUI
  import UIKit

  struct CameraDeniedView: View {
      let onDismiss: () -> Void

      var body: some View {
          VStack(spacing: 16) {
              Image(systemName: "camera.fill")
                  .font(.system(size: 56))
                  .foregroundStyle(.secondary)
              Text("Camera access needed")
                  .font(.title2.weight(.semibold))
              Text("Mobile Scanner uses your camera to capture documents. Enable access in Settings.")
                  .multilineTextAlignment(.center)
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 32)
              Button("Open Settings") {
                  if let url = URL(string: UIApplication.openSettingsURLString) {
                      UIApplication.shared.open(url)
                  }
              }
              .buttonStyle(.borderedProminent)
              Button("Cancel", action: onDismiss)
                  .buttonStyle(.bordered)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(.systemBackground))
      }
  }
  ```

- [ ] **Step 3: Gate `LibraryView`'s capture presentation**

  In `LibraryView.swift`, add:

  ```swift
  @State private var showingCameraDenied = false
  ```

  Change the `+` button to consult permission first. Find the existing toolbar `Button { showingCapture = true } label: { ... }` and replace with:

  ```swift
  Button {
      Task {
          switch await CameraPermission.request() {
          case .authorized: showingCapture = true
          case .denied: showingCameraDenied = true
          case .notDetermined: break  // unreachable after request()
          }
      }
  } label: {
      Image(systemName: "plus")
  }
  ```

  Add a `.fullScreenCover` alongside the existing one:

  ```swift
  .fullScreenCover(isPresented: $showingCameraDenied) {
      CameraDeniedView(onDismiss: { showingCameraDenied = false })
  }
  ```

- [ ] **Step 4: Build**

- [ ] **Step 5: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Capture/CameraPermission.swift DocumentScanner/DocumentScanner/Capture/CameraDeniedView.swift DocumentScanner/DocumentScanner/Library/LibraryView.swift
  git commit -m "Gate scanner presentation on camera permission status

  Task 4 of plan-4: CameraPermission wraps AVCaptureDevice
  authorizationStatus; the library + button now requests/checks
  before opening VisionKit. If denied or restricted, presents
  CameraDeniedView with an Open Settings link instead of the
  scanner.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 5: iCloud-unavailable onboarding

**Files:**
- Create: `DocumentScanner/DocumentScanner/Onboarding/ICloudOnboardingView.swift`
- Modify: `DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift`

If `ICloudContainer.isICloudAvailable` is false on first launch and the user hasn't dismissed the onboarding, show an explainer. After they dismiss (either route — Settings or Try Anyway), set an `@AppStorage` flag so it never shows again.

- [ ] **Step 1: Implement `ICloudOnboardingView`**

  ```swift
  import SwiftUI
  import UIKit

  struct ICloudOnboardingView: View {
      let onTryAnyway: () -> Void

      var body: some View {
          VStack(spacing: 16) {
              Image(systemName: "icloud.slash")
                  .font(.system(size: 56))
                  .foregroundStyle(.secondary)
              Text("iCloud Drive recommended")
                  .font(.title2.weight(.semibold))
              Text("Mobile Scanner syncs your documents across devices through iCloud Drive. You can use the app without it — scans will stay on this device only.")
                  .multilineTextAlignment(.center)
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 32)
              Button("Open Settings") {
                  if let url = URL(string: UIApplication.openSettingsURLString) {
                      UIApplication.shared.open(url)
                  }
              }
              .buttonStyle(.borderedProminent)
              Button("Try anyway (local only)", action: onTryAnyway)
                  .buttonStyle(.bordered)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(.systemBackground))
      }
  }
  ```

- [ ] **Step 2: Gate the app shell**

  In `DocumentScannerApp.swift`, add:

  ```swift
  @AppStorage("iCloudOnboardingDismissed") private var iCloudOnboardingDismissed = false
  ```

  And change the body to:

  ```swift
  var body: some Scene {
      WindowGroup {
          if !iCloudOnboardingDismissed && !container.isICloudAvailable {
              ICloudOnboardingView(onTryAnyway: { iCloudOnboardingDismissed = true })
                  .environment(\.alertCenter, alertCenter)
          } else {
              LockGate(lockSettings: lockSettings) {
                  PrivacyBlurOverlay {
                      LibraryView(
                          store: store,
                          scannerPresenter: scannerPresenter,
                          storage: DocumentStorage(documentsURL: container.resolveDocumentsURL()),
                          pipeline: pipeline,
                          lockSettings: lockSettings
                      )
                  }
              }
              .environment(\.alertCenter, alertCenter)
              .alert(item: Binding(
                  get: { alertCenter.current },
                  set: { _ in alertCenter.dismiss() }
              )) { alert in
                  appAlert(alert)
              }
          }
      }
  }
  ```

- [ ] **Step 3: Build**

- [ ] **Step 4: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Onboarding/ICloudOnboardingView.swift DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift
  git commit -m "Add iCloud-unavailable onboarding screen for first launch

  Task 5 of plan-4: when ICloudContainer.isICloudAvailable is false
  and the user hasn't dismissed onboarding, show a one-time
  explainer with Open Settings and Try Anyway options. Storing the
  dismissal in @AppStorage means returning users skip straight to
  the library.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 6: Storage-full + write-error routing

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift`

`DocumentStorage.write` already throws on failure. Currently `NameDocumentSheet` swallows that into a local `errorMessage`. Route through `AlertCenter` so users see a real alert with a Retry button.

- [ ] **Step 1: Wire NameDocumentSheet to AlertCenter**

  In `NameDocumentSheet.swift`, add:

  ```swift
  @Environment(\.alertCenter) private var alertCenter
  ```

  Change the `save()` method's `catch` block:

  ```swift
  } catch is CancellationError {
      onCancel()
  } catch {
      alertCenter.present(AppAlert(
          title: "Couldn't save",
          message: error.localizedDescription,
          primary: AppAlert.Action(title: "Retry", role: .default, handler: {
              Task { await save() }
          }),
          secondary: AppAlert.Action(title: "Cancel", role: .cancel, handler: {
              onCancel()
          })
      ))
  }
  ```

  Remove the now-unused `errorMessage` state if you wish, OR keep it as a secondary inline indicator.

- [ ] **Step 2: Build**

- [ ] **Step 3: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Capture/NameDocumentSheet.swift
  git commit -m "Route save failures through AlertCenter with Retry

  Task 6 of plan-4: NameDocumentSheet's save() catch block now
  presents an AppAlert via AlertCenter with Retry/Cancel buttons
  instead of just setting a local error string. The in-memory PDF
  remains held until the user dismisses, so Retry can re-attempt
  the write.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 7: Corrupt PDF row + recovery

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Library/DocumentSummary.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/DocumentRow.swift`
- Modify: `DocumentScanner/DocumentScanner/Library/MetadataQueryLibraryStore.swift`
- Create: `DocumentScanner/DocumentScannerTests/DocumentSummaryCorruptTests.swift`

`DocumentSummary.fromFile` currently throws when PDFKit can't parse a file. The store then drops the file entirely with `compactMap`. Make `fromFile` return a "corrupt" placeholder so the file still appears in the library; let the user delete or attempt recovery.

- [ ] **Step 1: Write the failing test**

  ```swift
  import XCTest
  @testable import DocumentScanner

  final class DocumentSummaryCorruptTests: XCTestCase {

      func test_fromFile_corruptPDF_returnsCorruptVariant() throws {
          let url = FileManager.default.temporaryDirectory
              .appendingPathComponent("corrupt-\(UUID()).pdf")
          let garbage = Data("not actually a pdf".utf8)
          try garbage.write(to: url)
          defer { try? FileManager.default.removeItem(at: url) }

          let summary = DocumentSummary.fromFile(at: url)
          XCTAssertTrue(summary.isCorrupt)
          XCTAssertEqual(summary.displayName, url.deletingPathExtension().lastPathComponent)
      }

      func test_fromFile_realPDF_returnsHealthySummary() throws {
          let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in
              UIColor.white.setFill()
              UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
          }
          let pdf = try PDFAssembler().assemble(
              pages: [ScannedPage(image: image, observations: [])],
              createdAt: Date()
          )
          let url = FileManager.default.temporaryDirectory
              .appendingPathComponent("healthy-\(UUID()).pdf")
          try XCTUnwrap(pdf.dataRepresentation()).write(to: url)
          defer { try? FileManager.default.removeItem(at: url) }

          let summary = DocumentSummary.fromFile(at: url)
          XCTAssertFalse(summary.isCorrupt)
          XCTAssertEqual(summary.pageCount, 1)
      }
  }
  ```

- [ ] **Step 2: Update `DocumentSummary`**

  Change `fromFile` to a non-throwing function returning either a healthy or corrupt summary:

  ```swift
  struct DocumentSummary: Identifiable, Hashable {
      let url: URL
      let displayName: String
      let createdAt: Date
      let pageCount: Int
      let ocrSnippet: String
      let isCorrupt: Bool

      var id: URL { url }

      static func fromFile(at url: URL) -> DocumentSummary {
          let displayName = url.deletingPathExtension().lastPathComponent
          guard let pdf = PDFDocument(url: url) else {
              let fsCreated = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
              return DocumentSummary(url: url, displayName: displayName,
                                     createdAt: fsCreated, pageCount: 0, ocrSnippet: "",
                                     isCorrupt: true)
          }
          let attrs = pdf.documentAttributes ?? [:]
          let created = (attrs[PDFDocumentAttribute.creationDateAttribute] as? Date)
              ?? (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
              ?? Date()
          return DocumentSummary(url: url, displayName: displayName,
                                 createdAt: created, pageCount: pdf.pageCount,
                                 ocrSnippet: pdf.string ?? "", isCorrupt: false)
      }
  }
  ```

  Remove the `LoadError` enum (no longer needed). Anywhere it was thrown, callers should now handle `isCorrupt`.

- [ ] **Step 3: Update `MetadataQueryLibraryStore`**

  `compactMap { try? DocumentSummary.fromFile(at: $0) }` becomes:

  ```swift
  let built = urls.map { DocumentSummary.fromFile(at: $0) }
      .sorted(by: { $0.createdAt > $1.createdAt })
  ```

  (No more `try?` filtering — corrupts are kept.)

- [ ] **Step 4: Update `DocumentRow`**

  Render the corrupt state distinctively:

  ```swift
  HStack(spacing: 12) {
      if summary.isCorrupt {
          ZStack {
              RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray6))
              Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.orange)
          }
          .frame(width: 44, height: 56)
      } else {
          ThumbnailView(url: summary.url)
              .frame(width: 44, height: 56)
              .background(Color(.systemGray6))
              .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.systemGray4)))
      }
      VStack(alignment: .leading, spacing: 2) {
          Text(summary.displayName)
              .font(.body.weight(.semibold))
              .lineLimit(1)
          Text(formattedSubtitle)
              .font(.footnote)
              .foregroundStyle(summary.isCorrupt ? .orange : .secondary)
      }
      Spacer()
  }
  ```

  And update `formattedSubtitle`:

  ```swift
  private var formattedSubtitle: String {
      if summary.isCorrupt { return "Couldn't read this file" }
      let date = summary.createdAt.formatted(date: .abbreviated, time: .omitted)
      let pages = summary.pageCount == 1 ? "1 page" : "\(summary.pageCount) pages"
      return "\(date) · \(pages)"
  }
  ```

- [ ] **Step 5: Update `LibraryView` to handle corrupt rows**

  Wrap the `DocumentRow` in a way that the tap behavior differs for corrupt files. Quickest approach: don't push to viewer on tap; instead, show a context menu (long-press) with `Delete`.

  Find:

  ```swift
  List(filtered) { summary in
      NavigationLink(value: summary) {
          DocumentRow(summary: summary)
      }
  }
  ```

  Replace with:

  ```swift
  List(filtered) { summary in
      if summary.isCorrupt {
          DocumentRow(summary: summary)
              .contextMenu {
                  Button(role: .destructive) {
                      try? storage.delete(at: summary.url)
                      store.refresh()
                  } label: {
                      Label("Delete", systemImage: "trash")
                  }
              }
      } else {
          NavigationLink(value: summary) {
              DocumentRow(summary: summary)
          }
      }
  }
  ```

- [ ] **Step 6: Test passes**

- [ ] **Step 7: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Library/DocumentSummary.swift DocumentScanner/DocumentScanner/Library/DocumentRow.swift DocumentScanner/DocumentScanner/Library/MetadataQueryLibraryStore.swift DocumentScanner/DocumentScanner/Library/LibraryView.swift DocumentScanner/DocumentScannerTests/DocumentSummaryCorruptTests.swift
  git commit -m "Surface corrupt PDFs in library with warning row + delete

  Task 7 of plan-4: DocumentSummary.fromFile now returns an
  isCorrupt: true variant instead of throwing when PDFKit can't
  parse the file. The library no longer drops corrupt files;
  DocumentRow shows a warning icon and orange status text; tapping
  doesn't push to the viewer (which would crash) — a context-menu
  Delete is the recovery path.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 8: NSFileVersion conflict picker

**Files:**
- Create: `DocumentScanner/DocumentScanner/Viewer/ConflictResolutionView.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift`
- Modify: `DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift`

When iCloud detects two devices edited the same file, it stores conflicting versions and `NSFileVersion.unresolvedConflictVersionsOfItem(at:)` returns them. Detect on session init; if conflicts exist, present a picker first.

- [ ] **Step 1: Add conflict detection to `DocumentSession`**

  Add a property:

  ```swift
  private(set) var conflicts: [NSFileVersion]
  ```

  In `init`, populate it:

  ```swift
  init(summary: DocumentSummary, storage: DocumentStorage) throws {
      guard let pdf = PDFDocument(url: summary.url) else { throw InitError.unreadablePDF }
      self.url = summary.url
      self.pdf = pdf
      self.displayName = summary.displayName
      self.storage = storage
      self.conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: summary.url) ?? []
  }

  func resolveConflict(keeping chosen: NSFileVersion?) throws {
      // chosen == nil means "keep this device's current version" (i.e., do nothing
      // with the conflict version, just mark resolved).
      // chosen != nil means "replace with that version".
      if let chosen {
          try chosen.replaceItem(at: url, options: [])
      }
      for version in conflicts {
          version.isResolved = true
      }
      conflicts = []
      // Reload PDF from the (possibly replaced) file.
      if let reloaded = PDFDocument(url: url) {
          pdf = reloaded
      }
  }
  ```

- [ ] **Step 2: Implement `ConflictResolutionView`**

  ```swift
  import SwiftUI

  struct ConflictResolutionView: View {
      @Bindable var session: DocumentSession
      let onResolved: () -> Void

      var body: some View {
          NavigationStack {
              List {
                  Section("This device's version") {
                      Button {
                          do {
                              try session.resolveConflict(keeping: nil)
                              onResolved()
                          } catch { }
                      } label: {
                          Label("Keep this version", systemImage: "iphone")
                      }
                  }
                  Section("Other devices") {
                      ForEach(session.conflicts, id: \.self) { version in
                          Button {
                              do {
                                  try session.resolveConflict(keeping: version)
                                  onResolved()
                              } catch { }
                          } label: {
                              VStack(alignment: .leading) {
                                  Text(version.localizedName ?? "Unknown device")
                                  if let date = version.modificationDate {
                                      Text(date.formatted(date: .abbreviated, time: .shortened))
                                          .font(.footnote)
                                          .foregroundStyle(.secondary)
                                  }
                              }
                          }
                      }
                  }
              }
              .navigationTitle("Two versions exist")
              .navigationBarTitleDisplayMode(.inline)
          }
      }
  }
  ```

- [ ] **Step 3: Gate `DocumentViewerView` on conflict resolution**

  In `loadedBody`, ahead of the main VStack, check `session.conflicts`:

  ```swift
  @ViewBuilder
  private func loadedBody(session: DocumentSession) -> some View {
      if !session.conflicts.isEmpty {
          ConflictResolutionView(session: session, onResolved: {
              // No-op — once session.conflicts is empty, this view rebuilds
              // and falls through to the main body.
          })
      } else {
          // ... existing main body ...
      }
  }
  ```

- [ ] **Step 4: Build**

- [ ] **Step 5: Commit**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git add DocumentScanner/DocumentScanner/Viewer/ConflictResolutionView.swift DocumentScanner/DocumentScanner/Viewer/DocumentSession.swift DocumentScanner/DocumentScanner/Viewer/DocumentViewerView.swift
  git commit -m "Detect + resolve iCloud version conflicts in DocumentSession

  Task 8 of plan-4: NSFileVersion.unresolvedConflictVersionsOfItem
  populates DocumentSession.conflicts on init. When non-empty, the
  viewer shows ConflictResolutionView instead of the PDF — listing
  this device's version and each conflicting version (with the
  device's localized name + modification date), and lets the user
  pick which to keep. The chosen version replaces the file via
  NSFileVersion.replaceItem; the others are marked resolved.

  Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
  ```

## Task 9: Device smoke test

This is the hardest plan to smoke-test — most paths require forcing failure modes. Cover what you can.

- [ ] **Step 1: Cmd+R to iPhone**

- [ ] **Step 2: Strip-on-save (likely to verify)**
  - Open a doc, search for a term so highlights appear.
  - With highlights visible, enter Edit mode, rearrange pages, exit Edit.
  - Background the app, foreground, search again — highlights should re-render fresh (not show old yellow rectangles baked in).
  - Open the PDF in Files.app — no yellow/blue overlays should be present.

- [ ] **Step 3: Camera permission denied**
  - iPhone Settings → Mobile Scanner → Camera → toggle OFF.
  - Tap + in the library. Instead of the scanner, you should see the "Camera access needed" screen with Open Settings + Cancel.
  - Tap Open Settings → iOS Settings opens to the app's page.
  - Re-enable Camera. Return to the app. Tap + again → scanner opens normally.

- [ ] **Step 4: Storage full save error**
  - This is hard to provoke; if you can fill iCloud or rename a doc such that the directory write fails, do so. Skip if not easy to repro.

- [ ] **Step 5: Corrupt PDF**
  - On your Mac, drop a junk text file with a `.pdf` extension into iCloud Drive → Document Scanner. (e.g., `echo not-a-pdf > corrupt.pdf` and move to the folder.)
  - Wait for sync; return to the iPhone library.
  - The row should appear with a triangle/warning icon and "Couldn't read this file" subtitle.
  - Long-press → Delete should remove it.

- [ ] **Step 6: iCloud-unavailable onboarding**
  - Sign out of iCloud Drive on the iPhone (Settings → Apple ID → iCloud → toggle off Mobile Scanner OR toggle off iCloud Drive entirely).
  - Force-quit the app, relaunch.
  - You should see the onboarding screen ("iCloud Drive recommended") with Open Settings + Try Anyway.
  - Tap Try Anyway → app continues to library (now local-only).
  - Re-enable iCloud + relaunch — app should now start straight to library (no onboarding repeat).

- [ ] **Step 7: NSFileVersion conflict** (hardest)
  - Edit a doc on the iPhone (rename, say).
  - Without letting it sync, on the Mac open the same doc in Preview and add an annotation, save.
  - Force both devices to sync at once → iCloud should detect the conflict.
  - On iPhone, open the doc → conflict picker should appear listing both versions; pick one and the viewer should show that version.

- [ ] **Step 8: Sanity — no regressions**
  - All prior features (scan, edit mode, per-page editor, app lock, search highlighting) still work.

- [ ] **Step 9: Commit milestone**

  ```
  cd /Users/pjones/Desktop/mobileDocumentScanner
  git commit --allow-empty -m "Milestone: Plan 4 verified end-to-end on device"
  ```

---

## After Plan 4

What lands:

- AppAlert + AlertCenter infrastructure for centralized error UI
- Highlights stripped before save (no on-disk leakage)
- Camera permission gating
- iCloud onboarding for first-launch fallback
- Save failures routed to Retry alert
- Corrupt PDFs surfaced + recoverable
- iCloud conflict resolution UI

What remains:

- **Plan 5** — XCUITest golden-path tests with mocked scanner

## Self-review notes

- Spec coverage: AppAlert ✓, iCloud onboarding ✓, storage full ✓, camera denied ✓, NSFileVersion conflict ✓, corrupt PDF ✓, Vision OCR fail (already in Plan 1) ✓, app backgrounded mid-pipeline (already in Plan 1) ✓. Plus the strip-highlights-on-save fix.
- Placeholder scan: none.
- Type consistency: `AlertCenter`, `AppAlert`, `CameraPermission`, `DocumentSummary.isCorrupt`, `DocumentSession.conflicts` — signatures match across consumers.
- Test coverage: AlertCenter (3), DocumentSummary corrupt path (2), DocumentSession strip-on-save (1). NSFileVersion + camera permission + iCloud onboarding paths are device-only.
- Risk: NSFileVersion behavior on simulator is unreliable; the conflict picker is essentially smoke-tested only.
