# Mobile Document Scanner — Plan 1: Foundation & MVP

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up an iOS app that can scan a document with VisionKit, OCR it on-device, save it as a searchable PDF in iCloud Drive, list it on the home screen, and open it in a viewer.

**Architecture:** SwiftUI app, iOS 17+. VisionKit captures pages, `Vision` runs OCR, PDFKit assembles a searchable PDF, the iCloud ubiquity container stores it, `NSMetadataQuery` powers the library list. This plan covers the read-only happy path; edit mode, app lock, and error edge cases are deferred to later plans.

**Tech Stack:** Swift 5.9+, SwiftUI, VisionKit, Vision, PDFKit, NSMetadataQuery, NSFileCoordinator. XCTest for unit tests.

**Spec:** [`docs/superpowers/specs/2026-05-21-mobile-document-scanner-design.md`](../specs/2026-05-21-mobile-document-scanner-design.md)

**Plans in this series:**

- Plan 1 (this doc): Foundation, capture, OCR, save, list, viewer
- Plan 2: Edit mode (reorder, delete, append, crop/rotate)
- Plan 3: Settings + app lock + backgrounding blur
- Plan 4: Error edge cases (iCloud unavailable, conflicts, corrupt PDFs)
- Plan 5: UI tests (XCUITest with mocked scanner)

---

## A note for a first-time iOS developer

You're a strong web developer, new to native iOS. A few quick translations the rest of the plan assumes:

- **Xcode project** ≈ a `package.json` + monorepo + build config in one. The `.xcodeproj` file owns target settings (deployment target, entitlements, signing). Open it in Xcode (the IDE).
- **Targets** ≈ separate build outputs. We'll have three: app, unit tests, UI tests.
- **Entitlements** ≈ a declarative file the OS reads to grant the app capabilities (iCloud, push, Face ID). You add capabilities via the Xcode "Signing & Capabilities" tab; Xcode writes the `.entitlements` plist for you.
- **Info.plist** ≈ app manifest. Usage description strings (Camera, Face ID) live here.
- **Simulator** runs the app on your Mac. Note: **the camera does not work in Simulator.** We'll abstract VisionKit behind a protocol so dev iteration is in Simulator and real capture is tested on a device.
- **SwiftUI `@State`** ≈ `useState`. `@Observable` class (iOS 17+) ≈ a small store.
- **`actor`** ≈ a self-contained event loop you `await` into; only one task can mutate its state at a time. We use it for the scan pipeline.

## File structure (target end-state of Plan 1)

```text
DocumentScanner.xcodeproj/                  # Xcode project file (binary, generated)
DocumentScanner/
  App/
    DocumentScannerApp.swift                # @main, root WindowGroup
  Library/
    LibraryView.swift                       # SwiftUI list, "+" button, search
    LibraryStore.swift                      # @Observable, owns NSMetadataQuery, publishes summaries
    DocumentSummary.swift                   # value type: url, displayName, createdAt, pageCount, ocrSnippet, thumbnail
    DocumentRow.swift                       # row view
  Capture/
    DocumentScannerProtocol.swift           # abstraction over VisionKit for testability
    SystemDocumentScanner.swift             # real impl wrapping VNDocumentCameraViewController
    CaptureSheet.swift                      # SwiftUI sheet hosting the scanner
    NameDocumentSheet.swift                 # text-field + Save/Cancel
  Pipeline/
    ScanPipeline.swift                      # actor: pages → OCR → PDFDocument
    OCREngine.swift                         # Vision wrapper, async API
    PDFAssembler.swift                      # build PDFDocument from images + observations
    ScannedPage.swift                       # value type passed through pipeline
  Viewer/
    DocumentViewerView.swift                # PDFView host (read-only in Plan 1)
  Storage/
    DocumentStorage.swift                   # NSFileCoordinator writes, filename collision resolution
    ICloudContainer.swift                   # URL helpers for ubiquity Documents folder
  Resources/
    Info.plist
    DocumentScanner.entitlements
DocumentScannerTests/
  PDFAssemblerTests.swift
  OCREngineTests.swift
  ScanPipelineTests.swift
  DocumentStorageTests.swift
  LibraryStoreTests.swift
  Fixtures/
    page-with-text.png                      # a known image with readable text
DocumentScannerUITests/                     # empty target for Plan 5
```

After Plan 1, the app launches, shows an empty Documents list, opens VisionKit on "+", processes the scan, prompts for a name, writes the PDF to iCloud Drive, the new row appears in the list, and tapping it shows the PDF.

---

## Task 1: Create the Xcode project

**Files:**

- Create: `DocumentScanner.xcodeproj/` (Xcode does this)
- Create: `DocumentScanner/DocumentScannerApp.swift` (Xcode does this)

- [ ] **Step 1: Launch Xcode and create a new project**

  - Open Xcode → File → New → Project.
  - Template: iOS → App. Click Next.
  - Product Name: `DocumentScanner`
  - Team: your Apple ID (set this up if you haven't — Xcode → Settings → Accounts → +)
  - Organization Identifier: something you control (e.g., `ca.peter-jones`). The bundle identifier becomes `ca.peter-jones.DocumentScanner`.
  - Interface: **SwiftUI**
  - Language: **Swift**
  - Storage: **None** (we manage files ourselves; we are not using Core Data or SwiftData)
  - Include Tests: **YES** (creates the unit test + UI test targets)
  - Click Next, set save location to **`/Users/pjones/Desktop/mobileDocumentScanner`**. **Uncheck "Create Git repository"** — the repo already exists.

- [ ] **Step 2: Verify the project structure**

  In the Xcode left sidebar (Project Navigator) you should see:

  - `DocumentScanner` group with `DocumentScannerApp.swift`, `ContentView.swift`, `Assets.xcassets`
  - `DocumentScannerTests` group with `DocumentScannerTests.swift`
  - `DocumentScannerUITests` group with `DocumentScannerUITests.swift` and `DocumentScannerUITestsLaunchTests.swift`

- [ ] **Step 3: Set deployment target to iOS 17**

  - Click the blue `DocumentScanner` project icon at the top of the Project Navigator.
  - Select the `DocumentScanner` **target** (not the project) in the editor.
  - General tab → **Minimum Deployments**: **iOS 17.0**.
  - Repeat for `DocumentScannerTests` and `DocumentScannerUITests` targets.

- [ ] **Step 4: Build and run in Simulator to verify the skeleton works**

  - Top-bar device selector → choose **iPhone 15** (or any iOS 17+ simulator).
  - Press Cmd+R.
  - The Simulator boots and shows the default "Hello, world!" screen.
  - Quit the simulator (Cmd+Q on the simulator app) when satisfied.

- [ ] **Step 5: Commit**

  ```bash
  git add -A
  git status   # confirm we're adding the Xcode project + Swift sources, not build artifacts
  git commit -m "Add Xcode project skeleton (iOS 17, SwiftUI)"
  ```

  Note: `build/`, `DerivedData/`, `.swiftpm/`, `*.xcuserstate` are already in `.gitignore`. If you see anything unexpected staged, stop and ask.

## Task 2: Configure capabilities, entitlements, and Info.plist usage strings

**Files:**

- Modify: `DocumentScanner.xcodeproj/project.pbxproj` (via Xcode UI)
- Create: `DocumentScanner/DocumentScanner.entitlements` (Xcode writes this)
- Modify: `DocumentScanner/Info.plist` (or target Info settings — Xcode 14+ inlines this in the project file by default; either is fine)

- [ ] **Step 1: Add iCloud capability**

  - Project Navigator → `DocumentScanner` target → **Signing & Capabilities** tab.
  - Click **+ Capability**, search for **iCloud**, double-click.
  - In the iCloud capability section that appears:
    - Check **iCloud Documents**.
    - Under Containers, click **+** and pick **Specify custom containers**. Add a container with identifier `iCloud.ca.peter-jones.DocumentScanner` (substitute your actual reverse-domain). This must be globally unique; if Xcode complains, prepend `iCloud.` followed by a unique reverse-DNS string.
  - This action causes Xcode to create `DocumentScanner.entitlements` automatically.

- [ ] **Step 2: Make the iCloud Documents folder visible to Files.app**

  Edit `Info.plist` (in Xcode, right-click `Info.plist` → Open As → Source Code; if you don't see an `Info.plist` file, target → Info tab does the same thing). Add these keys:

  ```xml
  <key>NSUbiquitousContainerIsDocumentScopePublic</key>
  <true/>
  <key>NSUbiquitousContainerSupportedFolderLevels</key>
  <string>Any</string>
  <key>NSUbiquitousContainerName</key>
  <string>Document Scanner</string>
  ```

  These keys must be nested under a parent `NSUbiquitousContainers` dictionary keyed by the **container identifier** you set above. The complete fragment is:

  ```xml
  <key>NSUbiquitousContainers</key>
  <dict>
    <key>iCloud.ca.peter-jones.DocumentScanner</key>
    <dict>
      <key>NSUbiquitousContainerIsDocumentScopePublic</key>
      <true/>
      <key>NSUbiquitousContainerSupportedFolderLevels</key>
      <string>Any</string>
      <key>NSUbiquitousContainerName</key>
      <string>Document Scanner</string>
    </dict>
  </dict>
  ```

- [ ] **Step 3: Add usage description strings**

  In Info.plist add:

  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Document Scanner uses the camera to scan paper documents.</string>
  <key>NSFaceIDUsageDescription</key>
  <string>Document Scanner can lock your library behind Face ID.</string>
  ```

  (Face ID isn't used in Plan 1 but iOS will crash if we omit the string when we use it later. Adding now is free.)

- [ ] **Step 4: Build to verify Info.plist parses**

  Cmd+B. If Info.plist is malformed Xcode will say so. Fix and re-build until clean.

- [ ] **Step 5: Commit**

  ```bash
  git add -A
  git commit -m "Enable iCloud Documents capability and usage description strings"
  ```

## Task 3: Create folder groups in Xcode matching the planned module layout

**Files:**

- Create: `DocumentScanner/App/`, `Library/`, `Capture/`, `Pipeline/`, `Viewer/`, `Storage/` (Xcode "New Group" inside the `DocumentScanner` group)

- [ ] **Step 1: Make the groups**

  In Xcode Project Navigator, right-click the `DocumentScanner` group → **New Group**. Create one each named: `App`, `Library`, `Capture`, `Pipeline`, `Viewer`, `Storage`.

  Move `DocumentScannerApp.swift` and `ContentView.swift` into the `App` group (drag).

- [ ] **Step 2: Delete the placeholder**

  Delete `ContentView.swift` (right-click → Delete → Move to Trash). We'll replace it with `LibraryView`. Update `DocumentScannerApp.swift`:

  ```swift
  import SwiftUI

  @main
  struct DocumentScannerApp: App {
      var body: some Scene {
          WindowGroup {
              Text("Library coming soon")
                  .padding()
          }
      }
  }
  ```

  This will compile and run — we want a green build between every task.

- [ ] **Step 3: Build and run**

  Cmd+R. Simulator shows "Library coming soon".

- [ ] **Step 4: Commit**

  ```bash
  git add -A
  git commit -m "Establish module folder structure"
  ```

## Task 4: ICloudContainer URL helpers

**Files:**

- Create: `DocumentScanner/Storage/ICloudContainer.swift`
- Test: `DocumentScannerTests/ICloudContainerTests.swift` (covers fallback logic only — iCloud presence itself requires a device test)

The helper resolves the iCloud Documents folder URL (or `nil` if iCloud is unavailable) and a fallback local Documents URL.

- [ ] **Step 1: Write the failing test**

  Create `DocumentScannerTests/ICloudContainerTests.swift`:

  ```swift
  import XCTest
  @testable import DocumentScanner

  final class ICloudContainerTests: XCTestCase {

      func test_localDocumentsURL_returnsCachesDirectoryUnderTestsDocuments() {
          let container = ICloudContainer()
          let url = container.localDocumentsURL
          XCTAssertTrue(url.path.hasSuffix("/Documents"),
                        "expected path ending in /Documents, got \(url.path)")
      }

      func test_resolveDocumentsURL_returnsLocalWhenICloudUnavailable() {
          let container = ICloudContainer(iCloudURLProvider: { nil })
          XCTAssertEqual(container.resolveDocumentsURL(), container.localDocumentsURL)
      }

      func test_resolveDocumentsURL_returnsICloudWhenAvailable() {
          let stubURL = URL(fileURLWithPath: "/tmp/fake-icloud/Documents")
          let container = ICloudContainer(iCloudURLProvider: { stubURL })
          XCTAssertEqual(container.resolveDocumentsURL(), stubURL)
      }
  }
  ```

  Don't add Swift files via Finder — in Xcode right-click `DocumentScannerTests` → New File → Swift File → name it `ICloudContainerTests.swift`. **Make sure the file is added to the `DocumentScannerTests` target only.** (Check the target membership checkboxes in the file inspector — right pane.)

- [ ] **Step 2: Run the test and watch it fail**

  In Xcode, Cmd+U runs all tests. To run just this file, open it and click the diamond next to the class declaration.

  Expected: compile failure — `ICloudContainer` doesn't exist yet.

- [ ] **Step 3: Implement `ICloudContainer`**

  Create `DocumentScanner/Storage/ICloudContainer.swift`:

  ```swift
  import Foundation

  /// Resolves the URL to write documents into.
  ///
  /// Primary: the app's iCloud Documents container (synced, visible in Files.app).
  /// Fallback: the app's local Documents directory (when the user is signed out of iCloud
  /// or the device is offline at first launch). Plan 4 adds migration of local files to
  /// iCloud when it becomes available.
  struct ICloudContainer {
      var iCloudURLProvider: () -> URL?
      var localDocumentsURL: URL

      init(
          iCloudURLProvider: @escaping () -> URL? = ICloudContainer.defaultICloudURLProvider,
          localDocumentsURL: URL = ICloudContainer.defaultLocalDocumentsURL
      ) {
          self.iCloudURLProvider = iCloudURLProvider
          self.localDocumentsURL = localDocumentsURL
      }

      func resolveDocumentsURL() -> URL {
          iCloudURLProvider() ?? localDocumentsURL
      }

      var isICloudAvailable: Bool { iCloudURLProvider() != nil }

      // MARK: - Defaults

      private static var defaultICloudURLProvider: () -> URL? {
          {
              FileManager.default
                  .url(forUbiquityContainerIdentifier: nil)?
                  .appendingPathComponent("Documents", isDirectory: true)
          }
      }

      private static var defaultLocalDocumentsURL: URL {
          FileManager.default
              .urls(for: .documentDirectory, in: .userDomainMask)
              .first!
      }
  }
  ```

  Add the file to the **app target** only (not the test target) — uncheck `DocumentScannerTests` membership in the file inspector.

- [ ] **Step 4: Run the tests, watch them pass**

  Cmd+U. All three should be green.

- [ ] **Step 5: Commit**

  ```bash
  git add -A
  git commit -m "Add ICloudContainer URL resolver with local fallback"
  ```

## Task 5: PDFAssembler — build a searchable PDF from images + OCR observations

**Files:**

- Create: `DocumentScanner/Pipeline/ScannedPage.swift`
- Create: `DocumentScanner/Pipeline/PDFAssembler.swift`
- Test: `DocumentScannerTests/PDFAssemblerTests.swift`
- Test fixture: `DocumentScannerTests/Fixtures/page-with-text.png` (any image you have; we won't OCR it here, we'll feed canned observations)

- [ ] **Step 1: Add the fixture**

  Save any small PNG (a screenshot of text works) into `DocumentScannerTests/Fixtures/page-with-text.png`. In Xcode, drag it into the `DocumentScannerTests` group. In the dialog: **Copy items if needed: yes**, **Target: DocumentScannerTests only**.

- [ ] **Step 2: Write the failing test**

  Create `DocumentScannerTests/PDFAssemblerTests.swift`:

  ```swift
  import XCTest
  import PDFKit
  import UIKit
  @testable import DocumentScanner

  final class PDFAssemblerTests: XCTestCase {

      func test_assemble_singlePage_producesPDFWithOnePage() throws {
          let image = try loadFixture()
          let page = ScannedPage(image: image, recognizedStrings: [])
          let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
          XCTAssertEqual(pdf.pageCount, 1)
      }

      func test_assemble_multiplePages_producesCorrectPageCount() throws {
          let image = try loadFixture()
          let pages = (0..<3).map { _ in ScannedPage(image: image, recognizedStrings: []) }
          let pdf = try PDFAssembler().assemble(pages: pages, createdAt: Date())
          XCTAssertEqual(pdf.pageCount, 3)
      }

      func test_assemble_embedsRecognizedTextSoStringIsSearchable() throws {
          let image = try loadFixture()
          let page = ScannedPage(
              image: image,
              recognizedStrings: ["The quick brown fox", "jumps over the lazy dog"]
          )
          let pdf = try PDFAssembler().assemble(pages: [page], createdAt: Date())
          let text = pdf.string ?? ""
          XCTAssertTrue(text.contains("quick brown fox"), "got: \(text)")
          XCTAssertTrue(text.contains("lazy dog"), "got: \(text)")
      }

      func test_assemble_setsCreatedAtMetadata() throws {
          let image = try loadFixture()
          let date = Date(timeIntervalSince1970: 1_700_000_000)
          let pdf = try PDFAssembler().assemble(
              pages: [ScannedPage(image: image, recognizedStrings: [])],
              createdAt: date
          )
          let attrs = pdf.documentAttributes ?? [:]
          XCTAssertEqual(attrs[PDFDocumentAttribute.creationDateAttribute] as? Date, date)
      }

      // MARK: - Helpers

      private func loadFixture() throws -> UIImage {
          let url = Bundle(for: type(of: self))
              .url(forResource: "page-with-text", withExtension: "png")
          let resolvedURL = try XCTUnwrap(url, "fixture not in bundle")
          let data = try Data(contentsOf: resolvedURL)
          return try XCTUnwrap(UIImage(data: data))
      }
  }
  ```

- [ ] **Step 3: Run the test and watch it fail**

  Cmd+U. Expected: compile failure — `ScannedPage` and `PDFAssembler` don't exist.

- [ ] **Step 4: Implement `ScannedPage`**

  Create `DocumentScanner/Pipeline/ScannedPage.swift`:

  ```swift
  import UIKit

  struct ScannedPage {
      let image: UIImage
      /// Lines of OCR-recognized text in document reading order. Passed in by the OCR engine.
      let recognizedStrings: [String]
  }
  ```

- [ ] **Step 5: Implement `PDFAssembler`**

  Create `DocumentScanner/Pipeline/PDFAssembler.swift`:

  ```swift
  import PDFKit
  import UIKit

  enum PDFAssemblerError: Error {
      case pageCreationFailed
  }

  struct PDFAssembler {

      func assemble(pages: [ScannedPage], createdAt: Date) throws -> PDFDocument {
          let document = PDFDocument()

          for (index, page) in pages.enumerated() {
              guard let pdfPage = PDFPage(image: page.image) else {
                  throw PDFAssemblerError.pageCreationFailed
              }
              if !page.recognizedStrings.isEmpty {
                  attachInvisibleText(page.recognizedStrings, to: pdfPage)
              }
              document.insert(pdfPage, at: index)
          }

          var attrs = document.documentAttributes ?? [:]
          attrs[PDFDocumentAttribute.creationDateAttribute] = createdAt
          attrs[PDFDocumentAttribute.producerAttribute] = "DocumentScanner"
          document.documentAttributes = attrs

          return document
      }

      /// Embeds OCR text as a single PDFAnnotation whose contents are searchable.
      ///
      /// For Plan 1 we attach all recognized strings as one block — coarse but enough to
      /// make `pdf.string` return the right text. Plan 4 can refine this to per-line
      /// position-anchored annotations matching Apple's PDFKit "searchable PDF" recipe
      /// (one annotation per VNRecognizedTextObservation bounding box).
      private func attachInvisibleText(_ lines: [String], to page: PDFPage) {
          let bounds = page.bounds(for: .mediaBox)
          let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
          annotation.contents = lines.joined(separator: "\n")
          annotation.color = .clear
          annotation.fontColor = .clear
          annotation.font = .systemFont(ofSize: 1)
          page.addAnnotation(annotation)
      }
  }
  ```

  > Web-dev framing: `PDFAnnotation` ≈ a positioned `<span>` overlay on a PDF page. `freeText` with clear colors keeps it invisible visually while contributing to `pdf.string`.

- [ ] **Step 6: Run the tests, watch them pass**

  Cmd+U. All four PDFAssembler tests should be green.

- [ ] **Step 7: Commit**

  ```bash
  git add -A
  git commit -m "Add PDFAssembler with embedded OCR text layer"
  ```

## Task 6: OCREngine — async wrapper around `VNRecognizeTextRequest`

**Files:**

- Create: `DocumentScanner/Pipeline/OCREngine.swift`
- Test: `DocumentScannerTests/OCREngineTests.swift`

Vision runs in unit tests on macOS — these tests will execute under `xcodebuild test`.

- [ ] **Step 1: Write the failing test**

  Create `DocumentScannerTests/OCREngineTests.swift`:

  ```swift
  import XCTest
  import UIKit
  @testable import DocumentScanner

  final class OCREngineTests: XCTestCase {

      func test_recognizeText_emptyImage_returnsEmptyArray() async throws {
          let image = UIImage.fromColor(.white, size: CGSize(width: 100, height: 100))
          let engine = OCREngine()
          let strings = try await engine.recognizeText(in: image)
          XCTAssertTrue(strings.isEmpty)
      }

      func test_recognizeText_imageWithText_returnsRecognizedStrings() async throws {
          let image = UIImage.renderingText("Hello World", size: CGSize(width: 800, height: 200))
          let engine = OCREngine()
          let strings = try await engine.recognizeText(in: image)
          let joined = strings.joined(separator: " ")
          XCTAssertTrue(joined.localizedCaseInsensitiveContains("hello"),
                        "expected to recognize 'hello' in \(strings)")
      }
  }

  private extension UIImage {
      static func fromColor(_ color: UIColor, size: CGSize) -> UIImage {
          UIGraphicsBeginImageContextWithOptions(size, true, 1)
          color.setFill()
          UIRectFill(CGRect(origin: .zero, size: size))
          let img = UIGraphicsGetImageFromCurrentImageContext()!
          UIGraphicsEndImageContext()
          return img
      }

      static func renderingText(_ text: String, size: CGSize) -> UIImage {
          UIGraphicsBeginImageContextWithOptions(size, true, 1)
          UIColor.white.setFill()
          UIRectFill(CGRect(origin: .zero, size: size))
          let attrs: [NSAttributedString.Key: Any] = [
              .font: UIFont.boldSystemFont(ofSize: 96),
              .foregroundColor: UIColor.black
          ]
          (text as NSString).draw(at: CGPoint(x: 20, y: 40), withAttributes: attrs)
          let img = UIGraphicsGetImageFromCurrentImageContext()!
          UIGraphicsEndImageContext()
          return img
      }
  }
  ```

- [ ] **Step 2: Run the test and watch it fail**

  Cmd+U. Expected: compile failure — `OCREngine` doesn't exist.

- [ ] **Step 3: Implement `OCREngine`**

  Create `DocumentScanner/Pipeline/OCREngine.swift`:

  ```swift
  import Vision
  import UIKit

  enum OCREngineError: Error {
      case invalidImage
  }

  struct OCREngine {

      /// Recognize text in the supplied image. Returns one string per
      /// `VNRecognizedTextObservation`'s top candidate, in Vision's natural reading order.
      func recognizeText(in image: UIImage) async throws -> [String] {
          guard let cgImage = image.cgImage else { throw OCREngineError.invalidImage }

          return try await withCheckedThrowingContinuation { continuation in
              let request = VNRecognizeTextRequest { request, error in
                  if let error = error {
                      continuation.resume(throwing: error)
                      return
                  }
                  let observations = request.results as? [VNRecognizedTextObservation] ?? []
                  let strings = observations.compactMap { $0.topCandidates(1).first?.string }
                  continuation.resume(returning: strings)
              }
              request.recognitionLevel = .accurate
              request.usesLanguageCorrection = true

              let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
              DispatchQueue.global(qos: .userInitiated).async {
                  do {
                      try handler.perform([request])
                  } catch {
                      continuation.resume(throwing: error)
                  }
              }
          }
      }
  }
  ```

  > Web-dev framing: `withCheckedThrowingContinuation` ≈ wrapping a callback-style API in a `Promise` so you can `await` it.

- [ ] **Step 4: Run the tests**

  Cmd+U. The "Hello World" test confirms Vision actually recognizes text — if it returns garbage, the rendered fixture might be too small. The font size of 96 was picked because Vision tends to fail on tiny rasterized text.

- [ ] **Step 5: Commit**

  ```bash
  git add -A
  git commit -m "Add async OCREngine over VNRecognizeTextRequest"
  ```

## Task 7: ScanPipeline actor — compose OCR + assembly

**Files:**

- Create: `DocumentScanner/Pipeline/ScanPipeline.swift`
- Test: `DocumentScannerTests/ScanPipelineTests.swift`

- [ ] **Step 1: Write the failing test**

  Create `DocumentScannerTests/ScanPipelineTests.swift`:

  ```swift
  import XCTest
  import UIKit
  @testable import DocumentScanner

  final class ScanPipelineTests: XCTestCase {

      func test_process_returnsPDFWithSamePageCount() async throws {
          let images = [whiteImage(), whiteImage(), whiteImage()]
          let pipeline = ScanPipeline(ocr: StubOCR(returning: []))
          let result = try await pipeline.process(images: images)
          XCTAssertEqual(result.pdf.pageCount, 3)
      }

      func test_process_failsGracefully_whenOCRFailsForOnePage() async throws {
          let images = [whiteImage(), whiteImage()]
          let pipeline = ScanPipeline(ocr: FailingOnceOCR())
          let result = try await pipeline.process(images: images)
          XCTAssertEqual(result.pdf.pageCount, 2,
                         "page should be included even if OCR fails")
      }

      func test_process_returnsConcatenatedOCRText() async throws {
          let images = [whiteImage(), whiteImage()]
          let pipeline = ScanPipeline(ocr: StubOCR(returning: ["hello", "world"]))
          let result = try await pipeline.process(images: images)
          XCTAssertTrue(result.ocrText.contains("hello"))
          XCTAssertTrue(result.ocrText.contains("world"))
      }

      // MARK: - Helpers

      private func whiteImage() -> UIImage {
          UIGraphicsBeginImageContextWithOptions(CGSize(width: 100, height: 100), true, 1)
          UIColor.white.setFill()
          UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
          let img = UIGraphicsGetImageFromCurrentImageContext()!
          UIGraphicsEndImageContext()
          return img
      }

      private struct StubOCR: OCRProviding {
          let strings: [String]
          init(returning strings: [String]) { self.strings = strings }
          func recognizeText(in image: UIImage) async throws -> [String] { strings }
      }

      private struct FailingOnceOCR: OCRProviding {
          func recognizeText(in image: UIImage) async throws -> [String] {
              throw NSError(domain: "test", code: 1)
          }
      }
  }
  ```

- [ ] **Step 2: Run the tests and watch them fail**

  Cmd+U. Expected: compile failure — `ScanPipeline`, `OCRProviding`, etc. don't exist.

- [ ] **Step 3: Add `OCRProviding` protocol and conform `OCREngine`**

  Edit `DocumentScanner/Pipeline/OCREngine.swift` — add at the top:

  ```swift
  protocol OCRProviding {
      func recognizeText(in image: UIImage) async throws -> [String]
  }
  ```

  And on `OCREngine` add `: OCRProviding`:

  ```swift
  struct OCREngine: OCRProviding { /* ... existing body ... */ }
  ```

- [ ] **Step 4: Implement `ScanPipeline`**

  Create `DocumentScanner/Pipeline/ScanPipeline.swift`:

  ```swift
  import UIKit
  import PDFKit

  struct ScanResult {
      let pdf: PDFDocument
      let ocrText: String
  }

  /// Orchestrates OCR + PDF assembly. Implemented as an actor so concurrent calls
  /// (rare but possible if the user kicks off two scans quickly) are serialized.
  actor ScanPipeline {
      private let ocr: OCRProviding
      private let assembler: PDFAssembler

      init(ocr: OCRProviding = OCREngine(), assembler: PDFAssembler = PDFAssembler()) {
          self.ocr = ocr
          self.assembler = assembler
      }

      func process(images: [UIImage], createdAt: Date = .init()) async throws -> ScanResult {
          var pages: [ScannedPage] = []
          pages.reserveCapacity(images.count)

          for image in images {
              let strings: [String]
              do {
                  strings = try await ocr.recognizeText(in: image)
              } catch {
                  // Per spec: a failed OCR on one page does not block the document.
                  strings = []
              }
              pages.append(ScannedPage(image: image, recognizedStrings: strings))
          }

          let pdf = try assembler.assemble(pages: pages, createdAt: createdAt)
          let ocrText = pages
              .flatMap(\.recognizedStrings)
              .joined(separator: "\n")
          return ScanResult(pdf: pdf, ocrText: ocrText)
      }
  }
  ```

- [ ] **Step 5: Run the tests**

  Cmd+U. All three ScanPipeline tests pass.

- [ ] **Step 6: Commit**

  ```bash
  git add -A
  git commit -m "Add ScanPipeline actor composing OCR and PDF assembly"
  ```

## Task 8: DocumentStorage — coordinated writes with filename collision resolution

**Files:**

- Create: `DocumentScanner/Storage/DocumentStorage.swift`
- Test: `DocumentScannerTests/DocumentStorageTests.swift`

We write into a temporary directory in tests; iCloud-specific behavior is tested manually in Task 14.

- [ ] **Step 1: Write the failing test**

  Create `DocumentScannerTests/DocumentStorageTests.swift`:

  ```swift
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
  ```

- [ ] **Step 2: Run the test, watch it fail**

  Cmd+U. Expected: compile failure.

- [ ] **Step 3: Implement `DocumentStorage`**

  Create `DocumentScanner/Storage/DocumentStorage.swift`:

  ```swift
  import Foundation
  import PDFKit

  enum DocumentStorageError: Error {
      case writeFailed
      case emptyName
  }

  struct DocumentStorage {
      let documentsURL: URL

      func write(_ pdf: PDFDocument, preferredName: String) throws -> URL {
          let sanitized = Self.sanitize(preferredName)
          guard !sanitized.isEmpty else { throw DocumentStorageError.emptyName }

          let url = try uniqueURL(base: sanitized)

          guard let data = pdf.dataRepresentation() else {
              throw DocumentStorageError.writeFailed
          }

          var coordinatorError: NSError?
          var writeError: Error?
          let coordinator = NSFileCoordinator()
          coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { writeURL in
              do {
                  try data.write(to: writeURL, options: .atomic)
              } catch {
                  writeError = error
              }
          }
          if let error = coordinatorError ?? (writeError as NSError?) {
              throw error
          }
          return url
      }

      // MARK: - Private

      private func uniqueURL(base: String) throws -> URL {
          let candidate = documentsURL.appendingPathComponent("\(base).pdf")
          if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
          for index in 2...999 {
              let suffixed = documentsURL.appendingPathComponent("\(base) (\(index)).pdf")
              if !FileManager.default.fileExists(atPath: suffixed.path) { return suffixed }
          }
          throw DocumentStorageError.writeFailed
      }

      private static func sanitize(_ name: String) -> String {
          let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
          let cleaned = name
              .components(separatedBy: illegal)
              .joined(separator: "-")
              .trimmingCharacters(in: .whitespacesAndNewlines)
          return cleaned
      }
  }
  ```

  > Web-dev framing: `NSFileCoordinator` ≈ a per-file mutex coordinated with the OS. It exists because iCloud may be syncing the same file concurrently; if we wrote with plain `Data.write` we could race. In Plan 1 the practical effect is "write atomically and politely."

- [ ] **Step 4: Run the tests, watch them pass**

  Cmd+U. All three pass.

- [ ] **Step 5: Commit**

  ```bash
  git add -A
  git commit -m "Add DocumentStorage with NSFileCoordinator writes and collision resolution"
  ```

## Task 9: DocumentSummary value type + LibraryStore protocol

**Files:**

- Create: `DocumentScanner/Library/DocumentSummary.swift`
- Create: `DocumentScanner/Library/LibraryStore.swift`
- Test: `DocumentScannerTests/LibraryStoreTests.swift`

We separate `LibraryStoring` (protocol) from `MetadataQueryLibraryStore` (real, NSMetadataQuery-backed) and `InMemoryLibraryStore` (testable). LibraryView depends on the protocol.

- [ ] **Step 1: Write the failing test**

  Create `DocumentScannerTests/LibraryStoreTests.swift`:

  ```swift
  import XCTest
  import PDFKit
  @testable import DocumentScanner

  final class LibraryStoreTests: XCTestCase {

      func test_summary_fromPDFURL_readsTitlePageCountAndText() throws {
          let url = try writeFixturePDF()
          let summary = try DocumentSummary.fromFile(at: url)
          XCTAssertEqual(summary.displayName, "Test Doc")
          XCTAssertEqual(summary.pageCount, 1)
          XCTAssertTrue(summary.ocrSnippet.localizedCaseInsensitiveContains("hello"))
      }

      func test_inMemoryStore_appendAndRemove() async {
          let store = InMemoryLibraryStore()
          let one = DocumentSummary.stub(name: "A", date: .init(timeIntervalSince1970: 100))
          let two = DocumentSummary.stub(name: "B", date: .init(timeIntervalSince1970: 200))
          await store.append(one)
          await store.append(two)
          let summaries = await store.summaries
          XCTAssertEqual(summaries.map(\.displayName), ["B", "A"]) // newest first
      }

      // MARK: - Helpers

      private func writeFixturePDF() throws -> URL {
          let pdf = PDFDocument()
          UIGraphicsBeginImageContextWithOptions(CGSize(width: 100, height: 100), true, 1)
          UIColor.white.setFill()
          UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
          let img = UIGraphicsGetImageFromCurrentImageContext()!
          UIGraphicsEndImageContext()
          let page = PDFPage(image: img)!
          let annotation = PDFAnnotation(bounds: page.bounds(for: .mediaBox), forType: .freeText, withProperties: nil)
          annotation.contents = "hello world"
          annotation.color = .clear
          annotation.fontColor = .clear
          page.addAnnotation(annotation)
          pdf.insert(page, at: 0)

          let url = FileManager.default.temporaryDirectory
              .appendingPathComponent("Test Doc.pdf")
          try? FileManager.default.removeItem(at: url)
          pdf.write(to: url)
          return url
      }
  }

  private extension DocumentSummary {
      static func stub(name: String, date: Date) -> DocumentSummary {
          DocumentSummary(
              url: URL(fileURLWithPath: "/tmp/\(name).pdf"),
              displayName: name,
              createdAt: date,
              pageCount: 1,
              ocrSnippet: ""
          )
      }
  }
  ```

- [ ] **Step 2: Run the tests, watch them fail**

- [ ] **Step 3: Implement `DocumentSummary`**

  Create `DocumentScanner/Library/DocumentSummary.swift`:

  ```swift
  import Foundation
  import PDFKit

  struct DocumentSummary: Identifiable, Hashable {
      let url: URL
      let displayName: String
      let createdAt: Date
      let pageCount: Int
      let ocrSnippet: String

      var id: URL { url }

      enum LoadError: Error { case unreadablePDF }

      static func fromFile(at url: URL) throws -> DocumentSummary {
          guard let pdf = PDFDocument(url: url) else { throw LoadError.unreadablePDF }
          let attrs = pdf.documentAttributes ?? [:]
          let created = (attrs[PDFDocumentAttribute.creationDateAttribute] as? Date)
              ?? (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
              ?? Date()
          return DocumentSummary(
              url: url,
              displayName: url.deletingPathExtension().lastPathComponent,
              createdAt: created,
              pageCount: pdf.pageCount,
              ocrSnippet: pdf.string ?? ""
          )
      }
  }
  ```

- [ ] **Step 4: Implement `LibraryStoring` and `InMemoryLibraryStore`**

  Create `DocumentScanner/Library/LibraryStore.swift`:

  ```swift
  import Foundation
  import Observation

  protocol LibraryStoring: AnyObject {
      var summaries: [DocumentSummary] { get async }
      func refresh() async
  }

  /// Testable in-memory store. Real implementation (NSMetadataQuery-backed) lands in Task 10.
  @Observable
  final class InMemoryLibraryStore: LibraryStoring {
      private(set) var summaries: [DocumentSummary] = []

      func append(_ summary: DocumentSummary) async {
          summaries.append(summary)
          summaries.sort { $0.createdAt > $1.createdAt }
      }

      func refresh() async { /* no-op for in-memory */ }
  }
  ```

  > Web-dev framing: `@Observable` ≈ a reactive store. Views that read its properties re-render when those properties change. The protocol exists so `LibraryView` can be backed by either the real iCloud-backed store or the in-memory stub in tests.

- [ ] **Step 5: Run the tests, watch them pass**

- [ ] **Step 6: Commit**

  ```bash
  git add -A
  git commit -m "Add DocumentSummary and InMemoryLibraryStore"
  ```

## Task 10: MetadataQueryLibraryStore — real iCloud-backed library

**Files:**

- Create: `DocumentScanner/Library/MetadataQueryLibraryStore.swift`

No unit test — `NSMetadataQuery` only delivers results against a real iCloud container, which means a manual smoke test on a signed-in device. We verify in Task 14.

- [ ] **Step 1: Implement `MetadataQueryLibraryStore`**

  Create `DocumentScanner/Library/MetadataQueryLibraryStore.swift`:

  ```swift
  import Foundation
  import Observation

  @Observable
  final class MetadataQueryLibraryStore: NSObject, LibraryStoring {
      private(set) var summaries: [DocumentSummary] = []

      private let query: NSMetadataQuery = {
          let q = NSMetadataQuery()
          q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
          q.predicate = NSPredicate(format: "%K LIKE '*.pdf'", NSMetadataItemFSNameKey)
          q.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSCreationDateKey, ascending: false)]
          return q
      }()

      override init() {
          super.init()
          NotificationCenter.default.addObserver(
              self, selector: #selector(queryDidUpdate(_:)),
              name: .NSMetadataQueryDidFinishGathering, object: query
          )
          NotificationCenter.default.addObserver(
              self, selector: #selector(queryDidUpdate(_:)),
              name: .NSMetadataQueryDidUpdate, object: query
          )
          query.start()
      }

      deinit {
          query.stop()
          NotificationCenter.default.removeObserver(self)
      }

      func refresh() async {
          query.disableUpdates()
          query.enableUpdates()
      }

      @objc private func queryDidUpdate(_ note: Notification) {
          query.disableUpdates()
          defer { query.enableUpdates() }

          let items = (query.results as? [NSMetadataItem]) ?? []
          let urls = items.compactMap { $0.value(forAttribute: NSMetadataItemURLKey) as? URL }
          let built = urls.compactMap { try? DocumentSummary.fromFile(at: $0) }
              .sorted(by: { $0.createdAt > $1.createdAt })
          // Hop to main since `@Observable` notifies SwiftUI on whatever queue mutates the value.
          DispatchQueue.main.async {
              self.summaries = built
          }
      }
  }
  ```

- [ ] **Step 2: Build to verify it compiles**

  Cmd+B.

- [ ] **Step 3: Commit**

  ```bash
  git add -A
  git commit -m "Add NSMetadataQuery-backed library store"
  ```

## Task 11: LibraryView with a "+" button and document rows

**Files:**

- Create: `DocumentScanner/Library/DocumentRow.swift`
- Create: `DocumentScanner/Library/LibraryView.swift`
- Modify: `DocumentScanner/App/DocumentScannerApp.swift`

For now "+" tap will log to console; we wire actual capture in Task 13.

- [ ] **Step 1: Create the row view**

  Create `DocumentScanner/Library/DocumentRow.swift`:

  ```swift
  import SwiftUI
  import PDFKit

  struct DocumentRow: View {
      let summary: DocumentSummary

      var body: some View {
          HStack(spacing: 12) {
              ThumbnailView(url: summary.url)
                  .frame(width: 44, height: 56)
                  .background(Color(.systemGray6))
                  .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.systemGray4)))

              VStack(alignment: .leading, spacing: 2) {
                  Text(summary.displayName)
                      .font(.body.weight(.semibold))
                      .lineLimit(1)
                  Text(formattedSubtitle)
                      .font(.footnote)
                      .foregroundStyle(.secondary)
              }
              Spacer()
          }
          .padding(.vertical, 4)
      }

      private var formattedSubtitle: String {
          let date = summary.createdAt.formatted(date: .abbreviated, time: .omitted)
          let pages = summary.pageCount == 1 ? "1 page" : "\(summary.pageCount) pages"
          return "\(date) · \(pages)"
      }
  }

  private struct ThumbnailView: View {
      let url: URL

      @State private var image: UIImage?

      var body: some View {
          Group {
              if let image {
                  Image(uiImage: image).resizable().scaledToFit()
              } else {
                  Color.clear
              }
          }
          .task(id: url) {
              image = await Self.render(url: url)
          }
      }

      private static func render(url: URL) async -> UIImage? {
          await Task.detached(priority: .userInitiated) {
              guard let pdf = PDFDocument(url: url), let page = pdf.page(at: 0) else { return nil }
              let size = CGSize(width: 88, height: 112)
              return page.thumbnail(of: size, for: .mediaBox)
          }.value
      }
  }
  ```

- [ ] **Step 2: Create LibraryView**

  Create `DocumentScanner/Library/LibraryView.swift`:

  ```swift
  import SwiftUI

  struct LibraryView<Store: LibraryStoring & Observable>: View {
      @Bindable var store: Store
      @State private var searchText: String = ""

      var body: some View {
          NavigationStack {
              Group {
                  if store.summaries.isEmpty {
                      ContentUnavailableView(
                          "No documents yet",
                          systemImage: "doc.viewfinder",
                          description: Text("Tap + to scan a document.")
                      )
                  } else {
                      List(filtered) { summary in
                          DocumentRow(summary: summary)
                      }
                      .searchable(text: $searchText, prompt: "Search documents")
                      .refreshable { await store.refresh() }
                  }
              }
              .navigationTitle("Documents")
              .toolbar {
                  ToolbarItem(placement: .topBarTrailing) {
                      Button {
                          // Wired in Task 13
                          print("[+] tap")
                      } label: {
                          Image(systemName: "plus")
                      }
                  }
              }
          }
      }

      private var filtered: [DocumentSummary] {
          guard !searchText.isEmpty else { return store.summaries }
          let needle = searchText.lowercased()
          return store.summaries.filter {
              $0.displayName.lowercased().contains(needle)
              || $0.ocrSnippet.lowercased().contains(needle)
          }
      }
  }
  ```

  > Web-dev framing: `NavigationStack` ≈ a router. `.searchable` ≈ a built-in search bar bound to state. `ContentUnavailableView` is iOS 17's standard empty-state component.

- [ ] **Step 3: Wire `LibraryView` into the app**

  Edit `DocumentScanner/App/DocumentScannerApp.swift`:

  ```swift
  import SwiftUI

  @main
  struct DocumentScannerApp: App {
      @State private var store = MetadataQueryLibraryStore()

      var body: some Scene {
          WindowGroup {
              LibraryView(store: store)
          }
      }
  }
  ```

- [ ] **Step 4: Build and run**

  Cmd+R. You should see "Documents" with the empty state. Tapping "+" prints `[+] tap` in the Xcode console.

- [ ] **Step 5: Commit**

  ```bash
  git add -A
  git commit -m "Add LibraryView with empty state, search bar, and + button"
  ```

## Task 12: Capture sheet — wrap `VNDocumentCameraViewController`

**Files:**

- Create: `DocumentScanner/Capture/DocumentScannerProtocol.swift`
- Create: `DocumentScanner/Capture/SystemDocumentScanner.swift`
- Create: `DocumentScanner/Capture/CaptureSheet.swift`

VisionKit's `VNDocumentCameraViewController` is UIKit, so we use `UIViewControllerRepresentable`.

- [ ] **Step 1: Define `DocumentScannerProtocol`**

  Create `DocumentScanner/Capture/DocumentScannerProtocol.swift`:

  ```swift
  import UIKit

  /// Abstraction over VisionKit's document scanner so UI tests can inject fixture pages.
  /// In Plan 1 only the system implementation exists; Plan 5 adds a `StubDocumentScanner`.
  protocol DocumentScannerPresenting {
      func makeViewController(
          onFinish: @escaping ([UIImage]) -> Void,
          onCancel: @escaping () -> Void
      ) -> UIViewController
  }
  ```

- [ ] **Step 2: Implement `SystemDocumentScanner`**

  Create `DocumentScanner/Capture/SystemDocumentScanner.swift`:

  ```swift
  import UIKit
  import VisionKit

  struct SystemDocumentScanner: DocumentScannerPresenting {
      func makeViewController(
          onFinish: @escaping ([UIImage]) -> Void,
          onCancel: @escaping () -> Void
      ) -> UIViewController {
          let vc = VNDocumentCameraViewController()
          let coordinator = Coordinator(onFinish: onFinish, onCancel: onCancel)
          vc.delegate = coordinator
          // Keep coordinator alive for the lifetime of the controller.
          objc_setAssociatedObject(vc, &Coordinator.key, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
          return vc
      }

      private final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
          static var key: UInt8 = 0
          let onFinish: ([UIImage]) -> Void
          let onCancel: () -> Void
          init(onFinish: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
              self.onFinish = onFinish
              self.onCancel = onCancel
          }
          func documentCameraViewController(_ vc: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
              var images: [UIImage] = []
              for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
              onFinish(images)
          }
          func documentCameraViewControllerDidCancel(_ vc: VNDocumentCameraViewController) {
              onCancel()
          }
          func documentCameraViewController(_ vc: VNDocumentCameraViewController, didFailWithError error: Error) {
              onCancel() // Treat error as cancellation for Plan 1; Plan 4 surfaces it.
          }
      }
  }
  ```

- [ ] **Step 3: Implement `CaptureSheet`**

  Create `DocumentScanner/Capture/CaptureSheet.swift`:

  ```swift
  import SwiftUI
  import UIKit

  struct CaptureSheet: UIViewControllerRepresentable {
      let presenter: DocumentScannerPresenting
      let onFinish: ([UIImage]) -> Void
      let onCancel: () -> Void

      func makeUIViewController(context: Context) -> UIViewController {
          presenter.makeViewController(onFinish: onFinish, onCancel: onCancel)
      }
      func updateUIViewController(_ vc: UIViewController, context: Context) {}
  }
  ```

- [ ] **Step 4: Build to verify it compiles**

  Cmd+B.

- [ ] **Step 5: Commit**

  ```bash
  git add -A
  git commit -m "Add document scanner UIViewControllerRepresentable wrapper"
  ```

## Task 13: NameDocumentSheet + wire capture → pipeline → save → library

**Files:**

- Create: `DocumentScanner/Capture/NameDocumentSheet.swift`
- Modify: `DocumentScanner/Library/LibraryView.swift`
- Modify: `DocumentScanner/App/DocumentScannerApp.swift`

This is the central wiring task: tap "+" → capture → process → name → save to disk → row appears in the library.

- [ ] **Step 1: Implement `NameDocumentSheet`**

  Create `DocumentScanner/Capture/NameDocumentSheet.swift`:

  ```swift
  import SwiftUI
  import PDFKit

  /// Modal shown after capture. Lets the user name the document while the pipeline
  /// processes in the background. Save waits for the pipeline (showing a spinner)
  /// before writing to disk.
  struct NameDocumentSheet: View {
      let pipelineTask: Task<ScanResult, Error>
      let storage: DocumentStorage
      let onSaved: () -> Void
      let onCancel: () -> Void

      @State private var name: String = NameDocumentSheet.defaultName()
      @State private var isWorking = false
      @State private var errorMessage: String?

      var body: some View {
          NavigationStack {
              Form {
                  Section("Name") {
                      TextField("Name", text: $name)
                          .textInputAutocapitalization(.words)
                          .disabled(isWorking)
                  }
                  if let errorMessage {
                      Section { Text(errorMessage).foregroundStyle(.red) }
                  }
              }
              .navigationTitle("Save Scan")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") {
                          pipelineTask.cancel()
                          onCancel()
                      }.disabled(isWorking)
                  }
                  ToolbarItem(placement: .confirmationAction) {
                      if isWorking {
                          ProgressView()
                      } else {
                          Button("Save") { Task { await save() } }
                              .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                      }
                  }
              }
          }
          .interactiveDismissDisabled(isWorking)
      }

      private func save() async {
          isWorking = true
          defer { isWorking = false }
          do {
              let result = try await pipelineTask.value
              _ = try storage.write(result.pdf, preferredName: name)
              onSaved()
          } catch is CancellationError {
              onCancel()
          } catch {
              errorMessage = error.localizedDescription
          }
      }

      private static func defaultName() -> String {
          let f = DateFormatter()
          f.dateFormat = "'Scan' yyyy-MM-dd HH:mm"
          return f.string(from: Date())
      }
  }
  ```

- [ ] **Step 2: Update `LibraryView` to host the capture flow**

  Replace `DocumentScanner/Library/LibraryView.swift` with:

  ```swift
  import SwiftUI

  struct LibraryView<Store: LibraryStoring & Observable>: View {
      @Bindable var store: Store

      let scannerPresenter: DocumentScannerPresenting
      let storage: DocumentStorage
      let pipeline: ScanPipeline

      @State private var searchText = ""
      @State private var showingCapture = false
      @State private var nameSheet: NameSheetContext?

      private struct NameSheetContext: Identifiable {
          let id = UUID()
          let task: Task<ScanResult, Error>
      }

      var body: some View {
          NavigationStack {
              Group {
                  if store.summaries.isEmpty {
                      ContentUnavailableView(
                          "No documents yet",
                          systemImage: "doc.viewfinder",
                          description: Text("Tap + to scan a document.")
                      )
                  } else {
                      List(filtered) { DocumentRow(summary: $0) }
                          .searchable(text: $searchText, prompt: "Search documents")
                          .refreshable { await store.refresh() }
                  }
              }
              .navigationTitle("Documents")
              .toolbar {
                  ToolbarItem(placement: .topBarTrailing) {
                      Button { showingCapture = true } label: { Image(systemName: "plus") }
                  }
              }
              .fullScreenCover(isPresented: $showingCapture) {
                  CaptureSheet(
                      presenter: scannerPresenter,
                      onFinish: { images in
                          showingCapture = false
                          let task = Task { try await pipeline.process(images: images) }
                          nameSheet = NameSheetContext(task: task)
                      },
                      onCancel: { showingCapture = false }
                  )
                  .ignoresSafeArea()
              }
              .sheet(item: $nameSheet) { ctx in
                  NameDocumentSheet(
                      pipelineTask: ctx.task,
                      storage: storage,
                      onSaved: {
                          nameSheet = nil
                          Task { await store.refresh() }
                      },
                      onCancel: { nameSheet = nil }
                  )
              }
          }
      }

      private var filtered: [DocumentSummary] {
          guard !searchText.isEmpty else { return store.summaries }
          let needle = searchText.lowercased()
          return store.summaries.filter {
              $0.displayName.lowercased().contains(needle)
              || $0.ocrSnippet.lowercased().contains(needle)
          }
      }
  }
  ```

- [ ] **Step 3: Update the app entry point**

  Replace `DocumentScanner/App/DocumentScannerApp.swift`:

  ```swift
  import SwiftUI

  @main
  struct DocumentScannerApp: App {
      @State private var store = MetadataQueryLibraryStore()

      private let container = ICloudContainer()
      private let pipeline = ScanPipeline()
      private let scannerPresenter: DocumentScannerPresenting = SystemDocumentScanner()

      var body: some Scene {
          WindowGroup {
              LibraryView(
                  store: store,
                  scannerPresenter: scannerPresenter,
                  storage: DocumentStorage(documentsURL: container.resolveDocumentsURL()),
                  pipeline: pipeline
              )
          }
      }
  }
  ```

- [ ] **Step 4: Build to verify it compiles**

  Cmd+B.

- [ ] **Step 5: Commit**

  ```bash
  git add -A
  git commit -m "Wire capture → pipeline → name → save → library refresh"
  ```

## Task 14: Read-only DocumentViewerView and navigation from list

**Files:**

- Create: `DocumentScanner/Viewer/DocumentViewerView.swift`
- Modify: `DocumentScanner/Library/LibraryView.swift`

A minimal `PDFView`-backed viewer that opens when a row is tapped. Edit / share / delete are deferred to Plan 2; we just need to confirm in Task 15 that the user can tap a row and see the PDF render inside our app.

- [ ] **Step 1: Implement `DocumentViewerView`**

  Create `DocumentScanner/Viewer/DocumentViewerView.swift`:

  ```swift
  import SwiftUI
  import PDFKit

  struct DocumentViewerView: View {
      let summary: DocumentSummary

      var body: some View {
          PDFKitView(url: summary.url)
              .ignoresSafeArea(edges: .bottom)
              .navigationTitle(summary.displayName)
              .navigationBarTitleDisplayMode(.inline)
      }
  }

  private struct PDFKitView: UIViewRepresentable {
      let url: URL
      func makeUIView(context: Context) -> PDFView {
          let view = PDFView()
          view.autoScales = true
          view.displayMode = .singlePageContinuous
          view.usePageViewController(false)
          return view
      }
      func updateUIView(_ view: PDFView, context: Context) {
          view.document = PDFDocument(url: url)
      }
  }
  ```

- [ ] **Step 2: Add navigation from `LibraryView`**

  In `DocumentScanner/Library/LibraryView.swift`, replace the `List(filtered) { DocumentRow(summary: $0) }` block with:

  ```swift
  List(filtered) { summary in
      NavigationLink(value: summary) {
          DocumentRow(summary: summary)
      }
  }
  .navigationDestination(for: DocumentSummary.self) { summary in
      DocumentViewerView(summary: summary)
  }
  ```

  (Add `.searchable(...)` and `.refreshable(...)` directly after, as they were before.)

- [ ] **Step 3: Build and run**

  Cmd+R. The app should still launch with an empty state. (No saved docs to view yet — Task 15 exercises this.)

- [ ] **Step 4: Commit**

  ```bash
  git add -A
  git commit -m "Add read-only DocumentViewerView reachable from library rows"
  ```

## Task 15: Manual end-to-end smoke test on a device

VisionKit needs a real camera, so this last task is hands-on. You'll need an iPhone running iOS 17+ signed into iCloud.

- [ ] **Step 1: Configure code signing**

  - Xcode → `DocumentScanner` target → **Signing & Capabilities** tab.
  - Team: your Apple ID. "Automatically manage signing" checked.
  - The bundle ID should be the one you set in Task 1.
  - First-time signing for an Apple ID: Xcode will register the bundle ID with Apple. If it complains about the iCloud container, click "Create Container" in the iCloud capability section.

- [ ] **Step 2: Run on device**

  - Connect iPhone, trust the computer.
  - Top-bar device selector → choose your phone.
  - Cmd+R.
  - On first launch on the device: Settings → General → VPN & Device Management → trust your developer profile.
  - The app launches showing "No documents yet".

- [ ] **Step 3: Scan a document**

  - Tap **+**. iOS asks for camera permission — allow.
  - Scan any page (a printed receipt, a book page, anything with text).
  - Tap "Save" (VisionKit's own save button).
  - The Name & Save sheet appears with a default name. Type a name. Tap **Save**.
  - The sheet dismisses. Wait a few seconds. The row appears in the library.
  - Tap the row. The `DocumentViewerView` opens and renders the PDF. Back arrow returns to the list.

- [ ] **Step 4: Verify iCloud + Files.app visibility**

  - Open the Files app on the same iPhone → iCloud Drive. You should see a "Document Scanner" folder containing your PDF.
  - On another iCloud-signed-in device (Mac, iPad), open Files / Finder → iCloud Drive → Document Scanner. Same PDF appears after sync.

- [ ] **Step 5: Verify OCR**

  - In Files.app, tap the PDF. Long-press a word — iOS shows the selection menu (Copy / Look Up). This confirms the text layer is real and searchable in any PDF viewer.

- [ ] **Step 6: If anything is broken, diagnose**

  Common issues and where to look:

  - **Empty list never updates** — `MetadataQueryLibraryStore` predicate or scope is wrong. Add `print()` in `queryDidUpdate(_:)` to see whether updates are firing.
  - **"+" does nothing in simulator** — expected; the simulator has no camera. Run on device.
  - **iCloud container creation error in Xcode** — the identifier `iCloud.<bundle-id>` must match exactly between entitlements and the iCloud capability UI.
  - **PDF saves but doesn't appear in Files.app** — check the `NSUbiquitousContainers` Info.plist fragment from Task 2 is present and the keys are nested correctly.

- [ ] **Step 7: Commit the milestone marker**

  ```bash
  git commit --allow-empty -m "Milestone: Plan 1 verified end-to-end on device"
  ```

---

## After Plan 1

You now have an app that scans → OCRs → saves → lists → syncs through iCloud.

What it can't do yet, and what subsequent plans will add:

- **Plan 2**: open a document into a real viewer, then edit it (reorder/delete/append/crop pages)
- **Plan 3**: optional Face ID app lock and Settings screen
- **Plan 4**: graceful handling of iCloud-unavailable, conflicts, storage full, corrupt PDFs
- **Plan 5**: XCUITest golden-path tests with a mocked scanner

Before starting Plan 2, kick off the writing-plans skill again and reference this plan's outcome. Each plan stands on the prior plan's working state.

## Self-review notes (recorded after writing)

- Spec coverage in scope of Plan 1: capture (VisionKit) ✓, OCR (Vision) ✓, searchable PDF assembly ✓, iCloud storage with filename collision resolution ✓, library list with search ✓, naming on save ✓.
- Out of scope by design: edit mode, app lock, error edge cases beyond OCR-fails-per-page, UI tests. Each is covered by a named follow-up plan.
- Viewer scope: Plan 1 ships a *read-only* viewer (Task 14) so the user can verify scans inside the app. Toolbar (share / rename / delete) and Edit mode are deferred to Plan 2.
- Placeholder scan: no TBD / TODO / "fill in" markers in any task.
- Type consistency: `DocumentSummary` fields used identically across `LibraryStoreTests`, `DocumentSummary.fromFile`, `LibraryView`, `DocumentRow`. `ScanResult` has the same shape everywhere it appears (`pdf`, `ocrText`). `OCRProviding` protocol matches the `OCREngine` method signature.
