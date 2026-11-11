# Page Eraser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Crop / Erase switch in the page editor. Rectangles drawn on the page as it will be saved are painted out in the sampled paper colour on Apply, and the page is OCR'd again so erased text leaves search.

**Architecture:** A pure `PageEraser` fills rects in an image with a paper colour sampled around each rect. A pure `PageEditPipeline` runs correct → rotate → erase → filter in one place, used by both the Erase-mode preview and Apply. An `EraseSelection` value type holds the boxes (add, undo, clear, view-to-image mapping). `PageEditorView` gets the mode picker and a new `EraseOverlay` view for drawing.

**Tech Stack:** Swift, SwiftUI, UIKit (`UIGraphicsImageRenderer`), Core Image (existing corrector and filters), Vision (existing `OCREngine`), XCTest.

**Spec:** `docs/superpowers/specs/2026-11-11-page-eraser-design.md`. Read it first; this plan argues from it.

## Global Constraints

- Deployment target stays **iOS 17.6**. No new dependencies, no new entitlements, nothing leaves the device.
- Images are **1 pt = 1 px**: every new `UIGraphicsImageRenderer` sets `format.scale = 1` (see `PageImageRenderer.rotated`). Output image size equals input size.
- **Order on Apply:** perspective-correct → rotate → erase (sample + fill) → filter → OCR → assemble at the **existing page size**.
- Erase rects live in the **corrected-and-rotated image's pixel space**.
- **Fill colour:** per-channel median of the pixels in a band **6 px** wide just outside the rect, clipped to the image, sampled **before** the filter. No band pixels → white.
- **Changing the crop or rotation clears the boxes.** Changing the filter keeps them.
- **"Apply <filter> to all pages"** erases only the current page.
- A drag shorter than **8 pt** on screen in either dimension adds no box. Boxes are clipped to the image.
- Erasing is permanent: pixels are replaced in the image. Never implement it as a `PDFAnnotation`.
- New strings ship in **en, es, fr, de, it, zh-Hans**; `scripts/verify-localization.py` passes; de/it/zh-Hans get a back-translation QA file in `docs/superpowers/qa/`. FR/ES go to Peter for review.
- **Never open a target's General tab in Xcode** (FB24809836). No project-setting changes are needed for this plan.
- Unit tests: `./scripts/test.sh` (whole `DocumentScannerTests` target; its Passed/Failed line is authoritative). The project uses file-system-synchronized groups, so new files join their target automatically.
- Work on branch `feature/page-eraser`. Never push.

## Review Focus

1. **A box over a staple hole in the very corner**, so most of its band is off the image. Expected: the colour is sampled only from pixels inside the image and matches the paper. Pinned by `test_paperColor_boxAtCorner_samplesOnlyInsideImage` (Task 1).
2. **A box drawn tight against print or handwriting**, so part of the band is dark. Expected: the fill is still the paper colour, not grey. Pinned by `test_paperColor_bandPartlyDark_returnsPaper` (Task 1).
3. **A box covering the whole page**, so there is no band. Expected: filled white, no crash. Pinned by `test_erase_rectCoversWholeImage_fillsWhite` (Task 1).
4. **A drag from bottom-right to top-left, or ending off the page.** Expected: a normal box, clipped to the image. Pinned by `test_imageRect_reversedDrag_isNormalised` and `test_imageRect_dragPastEdge_isClipped` (Task 2).
5. **A rotated page.** Expected: the box erases where it was drawn on the rotated view. Pinned by `test_render_quarterTurn_erasesInRotatedSpace` (Task 3).

---

## File map

| File | Responsibility |
|---|---|
| Create `DocumentScanner/DocumentScanner/PageEditor/PageEraser.swift` | Sample paper colour; fill rects. Pure. |
| Create `DocumentScanner/DocumentScanner/PageEditor/EraseSelection.swift` | The boxes: add / undo / clear, view-to-image mapping. Pure. |
| Create `DocumentScanner/DocumentScanner/PageEditor/PageEditPipeline.swift` | correct → rotate → erase → filter. |
| Create `DocumentScanner/DocumentScanner/PageEditor/EraseOverlay.swift` | SwiftUI: shows the preview, draws boxes, reports new ones. |
| Modify `DocumentScanner/DocumentScanner/PageEditor/PageEditorView.swift` | Mode picker, Undo/count row, clear-on-crop note, use the pipeline. |
| Modify `DocumentScanner/DocumentScanner/Localizable.xcstrings` | New strings, 6 languages. |
| Create `DocumentScanner/DocumentScannerTests/TestImages.swift` | Shared test image and pixel helpers (moved out of `OCREngineTests.swift`). |
| Tests: `PageEraserTests.swift`, `EraseSelectionTests.swift`, `PageEditPipelineTests.swift` | |
| Create `docs/superpowers/qa/<date>-page-eraser-back-translation.md` | de/it/zh-Hans QA. |

---

### Task 1: `PageEraser`, sampling and filling

**Files:**
- Create: `DocumentScanner/DocumentScanner/PageEditor/PageEraser.swift`
- Create: `DocumentScanner/DocumentScannerTests/TestImages.swift`
- Modify: `DocumentScanner/DocumentScannerTests/OCREngineTests.swift` (delete its `private extension UIImage`; the helpers move to `TestImages.swift`)
- Test: `DocumentScanner/DocumentScannerTests/PageEraserTests.swift`

**Interfaces:**
- Produces:
  - `enum PageEraser { static let bandWidth: CGFloat = 6 }`
  - `static func paperColor(around rect: CGRect, in image: UIImage) -> UIColor`
  - `static func erase(_ rects: [CGRect], in image: UIImage) -> UIImage` (returns `image` itself when `rects` is empty or every rect is off the image)
  - Test helpers in `TestImages.swift` (internal, `extension UIImage`): `fromColor(_:size:)`, `renderingText(_:size:)`, `renderingLines(_:size:)` (moved unchanged), plus `func rgb(atX:y:) -> (r: Int, g: Int, b: Int)` that draws the image's `cgImage` into a 1×1 RGBA8 context offset to that pixel.

- [ ] **Step 1: Move the helpers.** Cut `fromColor`, `renderingText`, `renderingLines` from `OCREngineTests.swift` into `TestImages.swift` as a non-private `extension UIImage`; add `rgb(atX:y:)`. Run `./scripts/test.sh`. Expected: same Passed count as before the move, Failed 0.

- [ ] **Step 2: Write the failing tests** in `PageEraserTests.swift`. Use `cream = UIColor(red: 245/255, green: 240/255, blue: 224/255, alpha: 1)`; "matches" means each channel within ±2.

```swift
func test_paperColor_uniformCream_returnsCream()          // 200×200 cream, rect (80,80,40,40) → cream
func test_paperColor_bandPartlyDark_returnsPaper()        // cream 200×200 with black fill at x 120..130 (crosses right band of rect (80,80,40,40)) → cream
func test_paperColor_boxAtCorner_samplesOnlyInsideImage() // cream 200×200, rect (-10,-10,30,30) → cream
func test_erase_fillsInsideWithPaper_leavesOutsideAlone() // cream 200×200 + black 10×10 at (50,50); erase [(45,45,20,20)] → rgb(55,55) cream; rgb(5,5) cream; a black pixel elsewhere at (150,150) (drawn) stays black
func test_erase_keepsSizeAndScaleOne()                    // 300×200 in → cgImage 300×200, scale 1
func test_erase_rectPartlyOffImage_isClipped()            // rect (190,190,50,50) on 200×200: no crash, rgb(195,195) == paper, size unchanged
func test_erase_rectCoversWholeImage_fillsWhite()         // rect (-5,-5,210,210) on grey image → rgb(100,100) == (255,255,255)
func test_erase_noRects_returnsSameImage()                // XCTAssertTrue(PageEraser.erase([], in: img) === img)
```

- [ ] **Step 3: Run `./scripts/test.sh`.** Expected: build fails with "cannot find 'PageEraser' in scope".

- [ ] **Step 4: Implement `PageEraser`.** Band = the four strips `bandWidth` wide around `rect` (outset rect minus rect), intersected with the image bounds. Read pixels once from a scale-1 RGBA8 copy of the image; per-channel median of the band pixels; no pixels → white. `erase` draws the original then fills each `rect.intersection(imageBounds)` with its own `paperColor` (sampled from the **original**, not from earlier fills), in a `UIGraphicsImageRenderer` with `format.scale = 1`, `format.opaque = true`.

- [ ] **Step 5: Run `./scripts/test.sh`.** Expected: all pass, Failed 0.

- [ ] **Step 6: Commit** `feat(editor): PageEraser samples the paper colour and fills rects`.

---

### Task 2: `EraseSelection`, the boxes

**Files:**
- Create: `DocumentScanner/DocumentScanner/PageEditor/EraseSelection.swift`
- Test: `DocumentScanner/DocumentScannerTests/EraseSelectionTests.swift`

**Interfaces:**
- Produces:
  - `struct EraseSelection: Equatable { private(set) var rects: [CGRect]; var count: Int; var isEmpty: Bool }`
  - `mutating func add(_ imageRect: CGRect)`, `mutating func undo()` (removes last; no-op when empty), `mutating func clear()`
  - `static let minimumDragPoints: CGFloat = 8`
  - `static func imageRect(from start: CGPoint, to end: CGPoint, scale: CGFloat, offset: CGPoint, imageSize: CGSize) -> CGRect?` — maps two view points (same geometry as `QuadOverlay`: `image = (view - offset) / scale`) to a normalised image rect clipped to `imageSize`; `nil` when the on-screen drag is under `minimumDragPoints` in width or height, or the clipped rect is empty.

- [ ] **Step 1: Write the failing tests.**

```swift
func test_add_undo_clear()                     // add 2 → count 2; undo → rects == [first]; clear → isEmpty
func test_undo_whenEmpty_doesNothing()
func test_imageRect_mapsViewToImage()          // scale 0.5, offset (10,20), start (10,20) end (60,70), image 400×400 → (0,0,100,100)
func test_imageRect_reversedDrag_isNormalised() // start (60,70) end (10,20) → same as above
func test_imageRect_dragPastEdge_isClipped()   // scale 1, offset .zero, image 100×100, start (80,80) end (150,150) → (80,80,20,20)
func test_imageRect_shortDrag_isNil()          // scale 1, start (10,10) end (15,40) (5 pt wide) → nil
func test_imageRect_entirelyOffImage_isNil()   // scale 1, image 100×100, start (120,120) end (150,150) → nil
```

- [ ] **Step 2: Run `./scripts/test.sh`.** Expected: build fails, "cannot find 'EraseSelection'".
- [ ] **Step 3: Implement `EraseSelection`.**
- [ ] **Step 4: Run `./scripts/test.sh`.** Expected: all pass.
- [ ] **Step 5: Commit** `feat(editor): EraseSelection holds and maps erase boxes`.

---

### Task 3: `PageEditPipeline`, and erased text leaves OCR

**Files:**
- Create: `DocumentScanner/DocumentScanner/PageEditor/PageEditPipeline.swift`
- Modify: `DocumentScanner/DocumentScanner/PageEditor/PageEditorView.swift` (`processAndReplaceCurrentPage` and `displayedImage` call the pipeline; behaviour with no rects is unchanged)
- Test: `DocumentScanner/DocumentScannerTests/PageEditPipelineTests.swift`

**Interfaces:**
- Consumes: `PageEraser.erase(_:in:)` (Task 1); `PerspectiveCorrector.correct(_:quad:)`, `PageImageRenderer.rotated(_:quarterTurns:)`, `ImageFilterEngine.apply(_:to:)` (existing).
- Produces:
  - `struct PageEditPipeline { var corrector = PerspectiveCorrector(); var filterEngine = ImageFilterEngine() }`
  - `func straightened(_ pageImage: UIImage, quad: Quad, quarterTurns: Int) -> UIImage?` — correct then rotate (the space erase rects live in).
  - `func render(_ pageImage: UIImage, quad: Quad, quarterTurns: Int, eraseRects: [CGRect], filter: ImageFilter) -> UIImage?` — `straightened` → erase → filter (filter failure falls back to the unfiltered image, as today).

- [ ] **Step 1: Write the failing tests.** Source images are cream unless stated; `quad = Quad.fullRect(in: size)`.

```swift
func test_render_noRects_matchesCorrectRotateFilter()    // output size equals straightened size; rgb at centre equal to straightened+filtered within ±2
func test_render_erasesBeforeFilter()                    // cream 300×300 + black 20×20 at (100,100); rect (95,95,30,30); filter .blackAndWhite → rgb(110,110) within ±3 of rgb(200,200)
func test_render_quarterTurn_erasesInRotatedSpace()      // 300×200 with black 20×20 at source (0,0); quarterTurns 1 → black sits at output (180..200, 0..20); rect (170,0,30,30) → rgb(190,10) cream; same call with [] → rgb(190,10) dark (r < 60)
func test_render_erasedTextIsNotRecognised() async throws // UIImage.renderingLines(["Keep this line", "Erase me please"], size: 1400×300); rect (0,140,1400,110); filter .none; OCR joined text contains "Keep" and not "Erase"
```

- [ ] **Step 2: Run `./scripts/test.sh`.** Expected: build fails, "cannot find 'PageEditPipeline'".
- [ ] **Step 3: Implement `PageEditPipeline`**, then switch `PageEditorView.processAndReplaceCurrentPage(pageImage:quad:)` to `pipeline.render(..., eraseRects: [], ...)` (Task 4 passes the real rects) and keep throwing `PageEditError.cropFailed` on `nil`. `displayedImage` keeps showing the **uncorrected** rotated + filtered image for Crop mode; do not route it through `straightened`.
- [ ] **Step 4: Run `./scripts/test.sh`.** Expected: all pass, including the existing `PageImageRendererTests` and `PerspectiveCorrectorTests`.
- [ ] **Step 5: Commit** `refactor(editor): one pipeline for correct, rotate, erase and filter`.

---

### Task 4: Erase mode in the page editor

**Files:**
- Create: `DocumentScanner/DocumentScanner/PageEditor/EraseOverlay.swift`
- Modify: `DocumentScanner/DocumentScanner/PageEditor/PageEditorView.swift`

**Interfaces:**
- Consumes: `EraseSelection` (Task 2), `PageEditPipeline` (Task 3).
- Produces: `struct EraseOverlay: View { let image: UIImage; let rects: [CGRect]; let onAdd: (CGRect) -> Void }` — same fit/scale/offset geometry as `QuadOverlay`; a `DragGesture(minimumDistance: 0)` shows the in-progress box and on end calls `EraseSelection.imageRect(...)`, calling `onAdd` only for non-nil; committed rects drawn as `Color.red` stroke 2 pt with `Color.red.opacity(0.18)` fill.

Behaviour in `PageEditorView` (all from the spec; this task has no unit tests because every rule it adds is a view binding over Tasks 1–3, so verification is the build, the existing suite and the device check in Task 6):

- [ ] **Step 1: Add the mode picker.** `private enum EditMode { case crop, erase }`, `@State private var mode: EditMode = .crop`, `@State private var selection = EraseSelection()`, `@State private var erasePreview: UIImage?`. A segmented `Picker` with "Crop" and "Erase" at the top of the `VStack`, above the image.
- [ ] **Step 2: Erase mode body.** In `.erase`, replace `QuadOverlay` with `EraseOverlay(image: erasePreview, rects: selection.rects, onAdd: { selection.add($0) })`. Build `erasePreview` with `pipeline.render(pageImage, quad:, quarterTurns:, eraseRects: [], filter:)` when entering Erase mode and when `filter` changes while in Erase mode (not per frame). Hide `rotationControls` in Erase mode (rotation clears boxes; keeping it out of reach avoids accidental loss). Keep `filterControls`. Below the image: an **Undo** button (`arrow.uturn.backward`, disabled when `selection.isEmpty`) and the count label `"\(selection.count) areas"` (plural string, Task 5).
- [ ] **Step 3: Clear rules.** `.onChange(of: quad)` and `.onChange(of: rotationQuarterTurns)` → `selection.clear()`. In Crop mode, when `!selection.isEmpty`, show the footnote "Changing the crop clears the erased areas." under the image.
- [ ] **Step 4: Apply.** `processAndReplaceCurrentPage` passes `selection.rects`. `applyToAll` needs no change: it already calls `processAndReplaceCurrentPage` for the current page and the filter-only path for the rest. The existing markup warning still fires.
- [ ] **Step 5: Accessibility.** Picker label "Edit mode"; Undo has label "Undo"; post `AccessibilityNotification.Announcement` with the count label after add/undo.
- [ ] **Step 6: Run `./scripts/test.sh`.** Expected: all pass, Failed 0. Then `xcodebuild build` for the app scheme on the simulator succeeds with no new warnings in the touched files.
- [ ] **Step 7: Commit** `feat(editor): Erase mode with boxes, Undo and clear-on-crop`.

---

### Task 5: Localization

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Localizable.xcstrings`
- Create: `docs/superpowers/qa/<YYYY-MM-DD>-page-eraser-back-translation.md`

New keys (add a `comment` to each): "Crop", "Erase", "Undo", "Edit mode", "%lld areas" (plural variations: one "%lld area", other "%lld areas"; zh-Hans "other" only), "Changing the crop clears the erased areas."

- [ ] **Step 1:** Add es, fr, de, it, zh-Hans values. Use Apple's own terms where they exist (Photos' Crop: es "Recortar", fr "Recadrer", de "Beschneiden", it "Ritaglia", zh-Hans "裁剪"; Undo: "Deshacer", "Annuler", "Widerrufen", "Annulla", "撤销"). German uses the du-form as elsewhere in the app; Italian drops the article on buttons.
- [ ] **Step 2: Run `python3 scripts/verify-localization.py`.** Expected: exits 0 with no missing languages.
- [ ] **Step 3:** Write the QA file in the format of `docs/superpowers/qa/2026-11-01-card-scan-prompts-back-translation.md`: one table row per key with de/it/zh-Hans and a literal back-translation, then Findings. Fix anything the back-translation shows is wrong.
- [ ] **Step 4: Run `./scripts/test.sh`.** Expected: all pass.
- [ ] **Step 5: Commit** `i18n: page eraser strings in five languages, with de/it/zh-Hans QA`. Tell Peter the FR/ES values are ready for his review.

---

### Task 6: Device check and TODO

**Files:**
- Modify: `TODO.md`

- [ ] **Step 1: Hand Peter these checks** for **Pocket Scanner Dev** on his iPhone (⌘R builds Dev; this does not touch his real library). No system prompts are expected. Never tell him to delete anything without naming the exact document; never the app.
  - **E1** Open a scanned page with staple holes ▸ page menu ▸ Edit. Tap **Erase**. The page shows cropped and straightened; the crop corners are gone. Drag a box over the holes. Expected: a red box; the count says "1 area".
  - **E2** Draw a second box over a margin note, tap **Undo**, draw it again. Expected: count 1 → 2 → 1 → 2.
  - **E3** Tap **Apply**. Expected: holes and note gone, no bright patch on the Color filter, page the same size in the viewer.
  - **E4** Search for a word from the erased note. Expected: no match on that page.
  - **E5** Edit again, draw a box, switch to **Crop**. Expected: the "Changing the crop clears…" note. Move a corner, switch back to Erase. Expected: no boxes.
  - **E6** Rotate a page in Crop, switch to Erase, box something near a corner, Apply. Expected: erased exactly where drawn.
  - **E7** On a multi-page document, draw a box, choose Greyscale ▸ "Apply Greyscale to all pages". Expected: only this page erased; all pages grey.
- [ ] **Step 2:** Fix any failure Peter reports with a failing test first where the cause is in Tasks 1–3.
- [ ] **Step 3:** Add to `TODO.md` under Next: "Bump to 4.1 (41) in the app and Controls targets" and "v4.1 What's New in all 8 store locales (page eraser)". Commit `docs(todo): 4.1 release steps for the page eraser` when Peter says to.
