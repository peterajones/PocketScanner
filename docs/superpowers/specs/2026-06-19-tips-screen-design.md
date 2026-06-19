# Spec: Tips screen

**Date:** 2026-06-19
**Status:** Approved (design) — ready for implementation plan
**Roadmap origin:** `docs/FutureEnhancements.md` → *Editing → "Highlighter thickness / bleed"*
(decided 2026-06-18: *clarify, don't fix the geometry* — add a short in-app note). This spec is
the chosen vehicle: a small, growable **Tips** screen whose first entries include that note.
**Target release:** next release after v1.10.

## Goal

Give Pocket Scanner a findable **Tips** screen reachable from Settings — a home for short,
honest guidance and lightweight feature discovery. It launches with six tips: five everyday
tricks plus the decided **highlights/handwriting** expectation-setter. Built so adding a tip
later is appending one value to an array.

## Scope decisions (from brainstorming)

- **Placement:** a **"Tips"** row (lightbulb icon) in Settings' existing **About** section
  (alongside Version / Send Feedback). Tapping pushes `TipsView` onto the navigation stack
  Settings already lives in.
- **Structure:** `TipsView` is a `List` of tips; each tip renders as a `Section` (title as the
  section header, body as the section content). Content is static data (`Tip` value + a
  `Tip.all` array), so the view is dumb and the content is testable.
- **Content (6 tips, in this order):** actionable tricks first, the highlights caveat last.
- **No** per-tip seen/dismiss state, in-context popovers, search, or onboarding changes.
  Just a findable screen with honest copy, designed to grow.

## Architecture / components

### `Tip` (model)
A small value type:
```
struct Tip: Identifiable {
    let id: String      // stable key, e.g. "search"
    let title: String
    let body: String
}
```
plus a static `static let all: [Tip]` holding the six tips below, in order. Pure data — no UI,
no dependencies — so it can be unit-tested.

### `TipsView`
A `List` over `Tip.all`; one `Section` per tip:
- header: `tip.title`
- content: `Text(tip.body)` (footnote/secondary styling, matching Settings' explanatory copy).
- `.navigationTitle("Tips")`.

### `SettingsView`
Add a `NavigationLink` row to the **About** section:
- label: `Label("Tips", systemImage: "lightbulb")`
- destination: `TipsView()`.
No other Settings changes.

## Content (final copy)

1. **Search inside your scans** — "Search reads the text inside every scan, even ones filed in
   folders. Tap a result to jump straight to the highlighted match."
2. **Swipe to delete** — "Swipe left on any document or folder to remove it."
3. **See your scans as thumbnails** — "Tap the layout button in the toolbar to switch between a
   list and a thumbnail grid of your library."
4. **Split out pages** — "In a document's edit mode, select pages and tap Save as New to pull
   them into their own scan."
5. **One big list** — "Prefer everything in one place? Turn off Show Folders in Settings and
   every scan lives in a single list."
6. **Highlights & handwriting** — "Highlights snap to the text Pocket Scanner detects in your
   scan. On printed pages that's precise; on handwriting or rough scans, text detection is
   looser — so a highlight may sit a bit tall or not line up exactly. Your scan itself is never
   altered."

## Data flow

```
Settings ▸ About ▸ "Tips" (NavigationLink) → TipsView
TipsView reads Tip.all → renders one Section per tip (header = title, body = text)
```
Static content; no state, no persistence, no store interaction.

## Error handling

None applicable — static content, no I/O, no user input, no failure modes.

## Testing

- **Unit (pure data):** assert `Tip.all` is non-empty, ids are unique, and every tip has a
  non-empty title and body; assert the highlights tip (`id == "highlights"`) is present (it's
  the roadmap-driven reason this screen exists).
- The screen itself is SwiftUI wiring — verified by build + on-device (open Settings ▸ Tips,
  confirm the six tips read correctly and the row sits in About). Matches how the app's other
  UI features ship.

## Deliverables

- New `DocumentScanner/DocumentScanner/Settings/TipsView.swift` — `Tip` model, `Tip.all`, `TipsView`.
- `DocumentScanner/DocumentScanner/Settings/SettingsView.swift` — the About-section "Tips" row.
- New `DocumentScanner/DocumentScannerTests/TipTests.swift` — the pure-data assertions.
- Spec + plan under `docs/superpowers/`. On merge, mark the FutureEnhancements highlighter item's
  "in-app note" as delivered (the fix-vs-clarify decision's clarify half is now shipped).

## Non-goals

- Re-engineering highlight geometry (explicitly rejected 2026-06-18).
- Per-tip dismissal / "new" badges / onboarding integration.
- Localizing the copy (the whole app is English today; localization is its own roadmap item).
- A search field or categorization within Tips (six static entries don't need it).
