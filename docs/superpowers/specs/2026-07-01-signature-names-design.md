# Signature names — design (v2.3 / build 21)

## Summary

Let the user give each saved signature an optional **name**, so multiple
signatures can be told apart — primarily in the "Choose a Signature" picker
shown when signing a document. Names are edited in Settings by tapping a
signature row. This is a deliberately small, focused release.

**Explicitly out of scope:** reordering signatures (considered and dropped —
with the 2–3 signatures a real user has, a custom order is marginal; order stays
creation-date, newest first). Also out: iCloud sync, typed/drawn signatures.

## Motivation

Saved signatures currently render as **thumbnails only** in two places — the
Settings list and the `SignaturePicker` sheet. Two similar-looking scrawls are
indistinguishable at signing time. A short human-readable label fixes exactly
that moment.

## Current state (what we build on)

- `Signature` is `{ id: String, image: UIImage }`; `id` is the on-disk filename
  stem (a UUID).
- `SignatureStore` persists one `<uuid>.png` per signature in Application
  Support (`Signature/`). `all()` returns them sorted by file **creation date,
  newest first**. There is no stored name and no stored order. The directory is
  injectable for testability and a future iCloud move.
- UI touch points: `SettingsView` signature `Section` (full-width thumbnail rows
  with swipe-to-delete, plus an "Add Signature" button); `SignaturePicker`
  ("Choose a Signature", used when signing with 2+ signatures and as the Move
  fallback).
- Established rename idiom in the app: `LibraryView` "Rename Folder" —
  `.alert(...)` with a prefilled `TextField` + Rename / Cancel, driven by an
  optional-state binding. Signature rename mirrors this.

## Design

### 1. Storage — a names sidecar (PNGs untouched)

- Add `name: String?` to `Signature`.
- Persist names in a **single JSON sidecar** `names.json` in the Signature
  directory: a `[id: name]` dictionary. The `<uuid>.png` files and their
  creation-date ordering are unchanged.
- `SignatureStore.all()` loads the sidecar and attaches `name` to each
  `Signature` (nil when the id is absent). Order is unchanged (creation date,
  newest first).
- New `SignatureStore.rename(id:to:)`:
  - Trims the new name.
  - Non-empty → sets `names[id] = trimmed` and writes the sidecar atomically.
  - Empty/whitespace-only → **removes** `names[id]` (reverts to unnamed) and
    writes.
- `remove(id:)` also prunes `names[id]` from the sidecar so deleted signatures
  leave no stale label.
- Sidecar read is defensive: absent or unreadable file → treat all as unnamed;
  ids present in the sidecar but with no matching PNG are ignored.
- **No migration:** absence of a name = unnamed. Existing installs keep working;
  signatures appear unnamed until named.

### 2. Settings — tap a row to rename

- The signature row changes from a full-width thumbnail to a **compact row**:
  a small leading thumbnail, then the name — or a muted **"Add a name"**
  placeholder when unnamed — and a trailing chevron to signal it is tappable.
- Tapping the row opens `.alert("Rename Signature")` with a `TextField`
  prefilled with the current name (empty when unnamed), `.autocorrectionDisabled()`,
  and **Rename / Cancel** buttons — mirroring "Rename Folder".
- Rename calls `signatureStore.rename(id:to:)` then reloads
  `signatures = signatureStore.all()`.
- Existing **swipe-to-delete** is retained unchanged.

### 3. The payoff — names in the picker

- `SignaturePicker` shows each signature's name beneath its thumbnail. Unnamed
  entries remain thumbnail-only (current behavior). No layout change beyond an
  optional caption label.

### 4. Details / decisions

- Names are **optional**, trimmed, **not** forced unique (two "Work" signatures
  are allowed — the user's problem, not ours to police).
- Length: input is capped at **40 characters** (truncate-on-entry, no error
  shown); display is single-line with tail truncation everywhere, so any name
  stays visually bounded regardless.
- **No auto-numbering.** Unnamed reads "Add a name" in Settings and shows nothing
  in the picker — avoids positional numbers that would look wrong without a
  stable custom order.

## Components

- `Signature` — add `name: String?`.
- `SignatureStore` — sidecar load/save helpers; `rename(id:to:)`; prune on
  `remove`; attach names in `all()` and `signature(withID:)`.
- `SettingsView` — compact row layout, rename alert + state, wiring.
- `SignaturePicker` — name caption under each thumbnail.

## Testing

Pure `SignatureStore` tests over an injected temp directory (matching the
existing suite):

- name set by `rename` round-trips through `all()`.
- `rename` to a new value overwrites the previous name.
- `rename` to blank/whitespace clears the name (id absent from sidecar).
- `remove(id:)` prunes the sidecar entry (name does not resurrect on re-add of a
  new id).
- absent/unreadable sidecar → every `Signature.name` is nil.
- sidecar containing an id with no PNG → ignored, no crash.
- name is trimmed on save.

UI wiring (Settings alert, picker caption) is verified by the on-device smoke
test at implementation time.

## Rollout

- Version bump to **2.3 (21)** at archive (main currently reads 2.2 / 20).
- Ships after v2.2 (20) Merge is live.
- Update `FutureEnhancements.md`: mark "Signature names/labels + reordering
  (v2.3)" as shipped-names / reordering-dropped.
