# Pocket Scanner

A no-subscription iOS document scanner. Scan paper to searchable PDF, synced to your own iCloud Drive. No accounts, no ads, no tracking.

> Available on the App Store: [Pocket Scanner](https://apps.apple.com/app/pocket-scanner/id6773036432)

## What it does

- **Capture** documents with Apple's VisionKit scanner — automatic edge detection, perspective correction, multi-page in one shot.
- **OCR** every page on-device via Apple's Vision framework. Resulting PDFs are fully searchable in any reader.
- **Sync** through your own iCloud Drive — the "Pocket Scanner" folder appears in the Files app on every device signed into your Apple ID.
- **Organize** scans into folders — create, rename, delete; move documents between folders; scan straight into a folder.
- **Edit** any page after the fact: re-crop, rotate, apply preset filters (Color / Greyscale / B&W / Photo). Re-OCRs after each edit.
- **Bulk edit** pages — multi-select thumbnails in edit mode to delete several at once, or apply a single filter to every page of a document.
- **Search** across all your scans by name or by text inside the document; matches highlight on the page with prev/next navigation.
- **Smart names** — receipts, invoices, and recipes get descriptive default names from on-device OCR.
- **Lock** the library behind optional Face ID with a 30-second background re-lock; app-switcher snapshots are always blurred.

## What it doesn't do

- No analytics, telemetry, or third-party SDKs.
- No backend server. The app has no idea who you are.
- No subscription. No "Pro" tier. No upsells.
- No ads.

## Stack

- **iOS 17.6+**, native Swift / SwiftUI
- **VisionKit** for capture
- **Vision** for on-device OCR + document segmentation
- **PDFKit** for PDF assembly and rendering
- **Core Image** (`CIPerspectiveCorrection`, `CIColorControls`, `CIPhotoEffectNoir`) for per-page editing
- **`NSMetadataQuery`** for iCloud Drive library indexing
- **`NSFileCoordinator`** for safe writes
- **`LocalAuthentication`** for Face ID / passcode lock
- **XCTest + XCUITest** for unit and UI coverage

No third-party Swift packages. No CocoaPods. No Carthage. Just Apple's frameworks.

## Project layout

```
DocumentScanner/                            # Xcode project
├── DocumentScanner/                        # App source
│   ├── App/                                # Root scene, LockGate, PrivacyBlurOverlay
│   ├── Library/                            # Document list, NSMetadataQuery-backed store
│   ├── Capture/                            # VisionKit wrapper, NameDocumentSheet
│   ├── Pipeline/                           # OCR engine, PDF assembler, ScanPipeline actor
│   ├── PageEditor/                         # Per-page crop/rotate/filter editor
│   ├── Viewer/                             # PDFView host, edit mode, search highlighting
│   ├── Storage/                            # iCloud + local file coordination
│   ├── Settings/                           # Settings screen, AppLock state machine
│   ├── Onboarding/                         # iCloud-unavailable explainer
│   └── Errors/                             # AlertCenter + AppAlert
├── DocumentScannerTests/                   # 87 unit tests
└── DocumentScannerUITests/                 # Hermetic XCUITests with stub scanner

docs/
├── superpowers/                            # Design specs and implementation plans
├── privacy-policy.md                       # App Store-required privacy policy
└── app-store-metadata.md                   # Submission copy draft
```

## Architecture notes

A few decisions worth calling out:

- **All PDFs are self-contained.** OCR text is embedded as invisible glyphs in the page content stream (CGContext + Core Text + `.invisible` text rendering mode), positioned at the Vision observation bounding boxes. AirDropping a scan out of the app preserves searchability in any reader.
- **No database.** The library is an `NSMetadataQuery` over the iCloud Documents container. Documents are the source of truth; no separate index to drift.
- **`PDFDocument` is reference-typed, so observation requires care.** A `revision: Int` counter on `DocumentSession` lets SwiftUI views react to in-place page mutations.
- **Hermetic UI tests.** A `-UITestMode` launch arg swaps in `StubDocumentScanner` + `InMemoryLibraryStore` + a temp-directory `DocumentStorage`, so XCUITests don't depend on iCloud sync or the simulator's camera.

## Privacy policy

[https://peterajones.github.io/PocketScanner/privacy-policy](https://peterajones.github.io/PocketScanner/privacy-policy)

## Building from source

Requires Xcode 26 (or later) and an iOS 17.6+ deployment target.

```bash
git clone https://github.com/peterajones/PocketScanner.git
cd PocketScanner/DocumentScanner
open DocumentScanner.xcodeproj
```

The project uses Xcode's "Automatically manage signing" — you'll need to switch the Team to your own Apple ID. The iCloud capability requires a paid Apple Developer Program membership; in its absence, the app falls back to local-only storage on the device.

To run the test suite (from inside `PocketScanner/DocumentScanner`, the directory that contains `DocumentScanner.xcodeproj`):

```bash
xcodebuild test -project DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

If you get `'DocumentScanner.xcodeproj' does not exist`, you're a level too high — `cd DocumentScanner` and re-run. To list valid simulators on your machine:

```bash
xcodebuild -showdestinations -project DocumentScanner.xcodeproj -scheme DocumentScanner | grep iPhone
```

## About

Built by [Peter Jones](https://peter-jones.ca) as a first foray into native iOS, with AI pair-programming via Claude. The full design history — specs, implementation plans, and per-commit rationale — lives under [`docs/superpowers/`](docs/superpowers/) and in the commit log.

## License

All rights reserved. Source is public for transparency and reference; the app is sold on the App Store and is not licensed for redistribution. If you're interested in adapting parts of it for your own learning, get in touch.
