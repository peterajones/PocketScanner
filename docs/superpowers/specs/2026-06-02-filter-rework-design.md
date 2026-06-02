# Filter rework — design

**Date:** 2026-06-02
**Status:** Spec approved; ready for implementation plan
**Related:** `docs/FutureEnhancements.md` → "Make all filter presets more pronounced"

## Background

Live use of v1.1 surfaced that all four filter presets (`Color`, `Greyscale`, `B&W`, `Photo`) look near-identical in the per-page editor, especially at thumbnail size. The picker exists but isn't pulling its weight because users can't visually tell the options apart.

Current behaviour (`DocumentScanner/DocumentScanner/PageEditor/ImageFilter.swift`):

- `.greyscale` — `CIColorControls` saturation=0
- `.blackAndWhite` — `CIPhotoEffectNoir` (Apple preset, low-contrast film stock)
- `.photo` — `CIColorControls` saturation=1.2, contrast=1.15

The shared problem: all three are subtle. `Noir` in particular looks muddy on plain document scans; it was tuned for photographs, not paper.

## Goal

When a user cycles through `Color → Greyscale → B&W → Photo` in the per-page editor, each preset should be visibly distinct even at thumbnail size. B&W in particular should match Apple Notes' scanner output: paper-white backgrounds, solid-black text.

## Non-goals

- "Filter at scan time" UX (separate v1.2 item; deferred).
- Continuous sliders or user-tunable filter parameters.
- New filter presets.
- Pixel-level regression tests.

## Design

Single file change in `DocumentScanner/DocumentScanner/PageEditor/ImageFilter.swift`. Move the per-filter parameters into a table on the enum, then collapse the engine to one path.

### Parameter table

A computed property on `ImageFilter` returns the three `CIColorControls` inputs, or `nil` for the pass-through case:

```swift
extension ImageFilter {
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
```

Values come from the FutureEnhancements spec. Rationale per filter:

- **Greyscale** — saturation 0 (unchanged), contrast 1.3 lifts text off the page so it isn't muddy.
- **B&W** — saturation 0 plus aggressive contrast 1.8 with a brightness lift of 0.15 pushes most paper backgrounds to pure white and most text to solid black, matching Apple Notes' look.
- **Photo** — saturation 1.5 and contrast 1.3 give glossy/colour pages obvious pop versus Color.

### Engine

`filteredImage(_:input:)` collapses from a four-case switch to one branch:

```swift
private func filteredImage(_ filter: ImageFilter, input: CIImage) -> CIImage? {
    guard let params = filter.colorControls else { return input }
    let f = CIFilter.colorControls()
    f.inputImage = input
    f.saturation = params.saturation
    f.contrast = params.contrast
    f.brightness = params.brightness
    return f.outputImage
}
```

The public `apply(_:to:)` signature is unchanged.

### What gets removed

- The `CIPhotoEffectNoir` call site (last use in the project).
- The per-case bodies inside `filteredImage`.

### Callers

No changes required in `PageEditorView.swift`. The three call sites — thumbnails (line 179), final-page output (line 229), and apply-to-all (line 241) — all use `ImageFilterEngine.apply(filter, to:)`, which is unchanged.

## Testing

`DocumentScannerTests/ImageFilterTests.swift` already covers each case for output dimensions; those tests continue to pass with no edits required.

No new pixel-sampling tests in this rework (per scope decision). Verification is manual: build, run in simulator, scan a sample document, cycle the four filters in the per-page editor, confirm each looks visibly distinct at both thumbnail and full size.

## Risks / open questions

- **B&W brightness=0.15 may blow out very light scans.** If a scan is already paper-white, the lift could clip highlights. If observed during manual verification, drop brightness to 0.1 or 0.05.
- **Photo saturation=1.5 may over-saturate already-vivid scans.** If observed, drop to 1.3.
- Both are tuning decisions that don't change the structure of the code — adjust the parameter table values, no other edits.

## Rollout

Ship as part of the next release (v1.2 or interim point release; release scope TBD separately). No migration, no flags, no feature gate.
