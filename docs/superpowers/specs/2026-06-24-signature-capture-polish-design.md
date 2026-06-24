# Spec: Signature capture polish (Rescan from preview + guidance hint)

**Date:** 2026-06-24
**Status:** Approved (design) — ready for implementation plan
**Roadmap origin:** Signature feature nice-to-haves (post v2.0 signing + multiple signatures).
**Target release:** v2.0 (current main).

## Goal

Two small UX wins on the signature **preview** screen in `SignatureCaptureView`:

1. **Rescan from the preview** — let the user retry a poor-but-successful cut-out in one tap,
   instead of having to Cancel and restart. (Rescan currently exists only on the *failure* screen.)
2. **In-capture guidance hint** — show a short "how to get a clean cut-out" tip on the preview,
   at the moment the user is deciding Save vs Rescan.

## Scope decisions (from brainstorming)

- Both tweaks live on the **preview** state of `SignatureCaptureView` (when `processed != nil`).
  **Save** stays in the toolbar (`confirmationAction`); **Cancel** stays in the toolbar
  (`cancellationAction`).
- **No pre-scan intro screen.** The view auto-launches Apple's scanner; an intro would add a tap
  to every capture. The tip on the preview (actionable via Rescan) delivers the guidance without
  friction.
- The **failure** screen already has its own guidance ("Try again on a plain, well-lit sheet with
  a dark pen") + a toolbar Rescan — left as-is.

## Changes (one file: `Signature/SignatureCaptureView.swift`)

Replace the preview `VStack`'s helper footnote and add a Rescan button. The preview content becomes:

- `Text("Your signature").font(.headline)` — unchanged.
- `CheckerboardPreview(...)` — unchanged.
- **Guidance hint** (replaces the current "Looks good? Save it to reuse on any document." line):
  `Text("Tip: a bold pen on a plain sheet gives the cleanest cut-out.").font(.footnote).foregroundStyle(.secondary)`
- **Rescan button** (new, secondary): `Button("Rescan") { showingScanner = true }` —
  re-opens the scanner. (`processingFailed` is already `false` in the preview state, so no reset
  needed; setting it false defensively is fine.)

No new types, no state changes, no signature/store changes.

## Data flow

```
preview (processed != nil):
  Save   (toolbar)  → store.add + onSaved        [unchanged]
  Cancel (toolbar)  → onCancel                    [unchanged]
  Rescan (content)  → showingScanner = true → CaptureSheet → handleScan(...) [re-process]
```

## Error handling

None new. Rescan reuses the existing `showingScanner` → `CaptureSheet` → `handleScan` path, which
already handles empty results (`processingFailed = true`) and processing failure.

## Testing

- No new unit tests — this is pure presentation; `SignatureProcessor`/`SignatureStore` are already
  tested. Verified by build + on-device (scan → preview shows the tip + a Rescan button; Rescan
  re-opens the scanner; Save/Cancel unchanged).

## Deliverables

- `Signature/SignatureCaptureView.swift`: tip footnote + Rescan button on the preview.
- Spec under `docs/superpowers/`. (Small enough that the roadmap needs no new entry; mention in the
  v2.0 What's New is optional.)

## Non-goals

- A pre-scan intro/guidance screen.
- Reworking the failure-state screen.
- Any change to placement, the picker, Move, or storage.
