# Filter rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the four `ImageFilter` presets visibly distinct in the per-page editor by replacing `CIPhotoEffectNoir` and the existing tuned values with a single `CIColorControls`-based path driven by a per-case parameter table.

**Architecture:** All work happens in one file: `DocumentScanner/DocumentScanner/PageEditor/ImageFilter.swift`. Add a computed property `colorControls` on the `ImageFilter` enum returning `(saturation, contrast, brightness)` (or `nil` for `.none`). Collapse `ImageFilterEngine.filteredImage(_:input:)` to one branch that reads from that table. The public `apply(_:to:)` signature is unchanged, so no caller (`PageEditorView`) needs editing.

**Tech Stack:** Swift 5+, Core Image (`CIFilter.colorControls()`), XCTest.

**Spec:** `docs/superpowers/specs/2026-06-02-filter-rework-design.md`

---

## Background for the engineer

You will edit one Swift file and re-run an existing XCTest target. Two things you need to know about this codebase:

1. **`ImageFilter`** is a small enum with four cases — `.none`, `.greyscale`, `.blackAndWhite`, `.photo` — paired with a separate `ImageFilterEngine` struct that does the actual Core Image work via `apply(_:to:)`.
2. **`PageEditorView`** is the only caller of `ImageFilterEngine`. It calls `apply(_:to:)` from three sites (thumbnails, the final-page output, and the apply-to-all-pages action). You will not edit `PageEditorView`.

**Existing test file:** `DocumentScanner/DocumentScannerTests/ImageFilterTests.swift`. The tests only assert output dimensions — they do not look at pixels. They should continue to pass after this change with no edits.

**Project structure:**
- App code: `DocumentScanner/DocumentScanner/`
- Tests: `DocumentScanner/DocumentScannerTests/`
- Xcode project: `DocumentScanner/DocumentScanner.xcodeproj`

**How to run the tests:** From the repo root:

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:DocumentScannerTests/ImageFilterTests
```

If the simulator name differs on your machine, run `xcrun simctl list devices available` and pick an iPhone in iOS 17+.

---

## File Structure

- **Modify:** `DocumentScanner/DocumentScanner/PageEditor/ImageFilter.swift` — add the `colorControls` extension and replace the body of `ImageFilterEngine.filteredImage(_:input:)`.
- **Unchanged:** `DocumentScanner/DocumentScannerTests/ImageFilterTests.swift` — existing dimension tests stay relevant.
- **Unchanged:** `DocumentScanner/DocumentScanner/PageEditor/PageEditorView.swift` — caller signature stable.

No new files. No deletions.

---

### Task 1: Replace `ImageFilter.swift` with the parameter-table version

**Files:**
- Modify: `DocumentScanner/DocumentScanner/PageEditor/ImageFilter.swift` (full body)
- Test: `DocumentScanner/DocumentScannerTests/ImageFilterTests.swift` (no changes — these are the regression net)

- [ ] **Step 1: Confirm existing tests pass on the current code**

Run:

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:DocumentScannerTests/ImageFilterTests
```

Expected: All four tests in `ImageFilterTests` pass. This baseline tells you the build works before you make changes.

- [ ] **Step 2: Replace the contents of `ImageFilter.swift`**

Open `DocumentScanner/DocumentScanner/PageEditor/ImageFilter.swift` and replace the entire file with:

```swift
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Visual filter applied to a page image in the editor. Preset-style;
/// no continuous sliders.
enum ImageFilter: String, CaseIterable, Identifiable {
    case none, greyscale, blackAndWhite, photo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Color"
        case .greyscale: return "Greyscale"
        case .blackAndWhite: return "B&W"
        case .photo: return "Photo"
        }
    }

    /// Color-controls parameters (saturation, contrast, brightness)
    /// or nil for the identity / pass-through case.
    var colorControls: (saturation: Float, contrast: Float, brightness: Float)? {
        switch self {
        case .none:          return nil
        case .greyscale:     return (saturation: 0,   contrast: 1.3, brightness: 0)
        case .blackAndWhite: return (saturation: 0,   contrast: 1.8, brightness: 0.15)
        case .photo:         return (saturation: 1.5, contrast: 1.3, brightness: 0)
        }
    }
}

struct ImageFilterEngine {

    private let context = CIContext()

    /// Apply `filter` to `source`. Returns the filtered UIImage or nil if
    /// the source has no cgImage.
    func apply(_ filter: ImageFilter, to source: UIImage) -> UIImage? {
        guard filter != .none else { return source }
        guard let cgImage = source.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        guard let output = filteredImage(filter, input: ciImage),
              let outCG = context.createCGImage(output, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: outCG, scale: source.scale, orientation: source.imageOrientation)
    }

    private func filteredImage(_ filter: ImageFilter, input: CIImage) -> CIImage? {
        guard let params = filter.colorControls else { return input }
        let f = CIFilter.colorControls()
        f.inputImage = input
        f.saturation = params.saturation
        f.contrast = params.contrast
        f.brightness = params.brightness
        return f.outputImage
    }
}
```

What changed from the previous version:
- Added the `colorControls` computed property on `ImageFilter`.
- `ImageFilterEngine.filteredImage(_:input:)` no longer switches on the filter — it reads parameters from the table and runs a single `CIColorControls` filter.
- `CIPhotoEffectNoir` is removed (no other call sites in the project).

The early return `guard filter != .none else { return source }` in `apply(_:to:)` is retained so the no-filter path still skips the Core Image round-trip entirely.

- [ ] **Step 3: Run the existing tests against the new code**

Run the same command as Step 1:

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:DocumentScannerTests/ImageFilterTests
```

Expected: All four tests still pass. They assert output dimensions, which are unaffected by changing the filter math. If a test fails, the most likely cause is a typo in the new file — re-read Step 2 carefully.

- [ ] **Step 4: Run the full test target as a smoke check**

The change is contained, but `ImageFilterEngine` is shared, so confirm nothing else regresses:

```bash
xcodebuild test \
  -project DocumentScanner/DocumentScanner.xcodeproj \
  -scheme DocumentScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Expected: All test targets pass. (If unrelated, pre-existing tests fail, note it but don't block on it.)

- [ ] **Step 5: Manual verification in the simulator**

This change is visual. Tests cover correctness of the function-call surface; they don't tell you the filters look right.

1. Launch the app in the simulator: `xcodebuild -project DocumentScanner/DocumentScanner.xcodeproj -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build` then run from Xcode, or use the `run` skill.
2. Scan or open an existing multi-page document.
3. Open a page in the per-page editor.
4. Cycle the filter picker through Color → Greyscale → B&W → Photo.

Confirm:
- Each preset looks visibly different from the others at thumbnail size.
- B&W looks like Apple Notes' B&W scanner output (paper-white background, solid-black text).
- Greyscale is clean and high-contrast, not muddy grey.
- Photo has obvious extra saturation and contrast versus Color.

If something looks wrong (e.g., B&W blowing out highlights, Photo over-saturating), the fix is to adjust the values in the `colorControls` table — no other code changes needed. Tuning notes are in the spec's "Risks / open questions" section.

- [ ] **Step 6: Commit**

```bash
git add DocumentScanner/DocumentScanner/PageEditor/ImageFilter.swift
git commit -m "$(cat <<'EOF'
ImageFilter: rework presets for visible distinction

Move per-filter parameters into a colorControls table on the enum
and collapse the engine to a single CIColorControls path. Drops
CIPhotoEffectNoir; greyscale gets a contrast lift; B&W goes
high-contrast (sat 0, contrast 1.8, brightness 0.15) to match
Apple Notes' look; Photo gets noticeable saturation+contrast pop.

Spec: docs/superpowers/specs/2026-06-02-filter-rework-design.md
EOF
)"
```

---

## Self-review

- **Spec coverage:** Spec sections — Goal, Non-goals, Parameter table, Engine, Removed code, Callers, Testing, Risks, Rollout. Every one maps to Task 1's steps (build/parameter-table/engine in Step 2; callers untouched per File Structure; tests in Steps 3-4; manual verification + tuning callouts in Step 5).
- **Placeholder scan:** No TBDs, no "add appropriate error handling," no "similar to Task N." Every code block is complete.
- **Type consistency:** `colorControls` tuple — `(saturation: Float, contrast: Float, brightness: Float)` — is consistent between the spec, the property declaration, and the consumer in `filteredImage`. `CIFilter.colorControls()` returns a type whose `saturation`, `contrast`, `brightness` properties are `Float`, matching the tuple.
