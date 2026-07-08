# Signature iCloud Sync — Design (v2.7 / 26)

**Status:** Approved 2026-07-08. Feature "A" of the post-v2.4 roadmap (C → B → A).

## Problem

Signatures are stored **local-only** in `Application Support/Signature/` (`<uuid>.png` files + a `names.json` sidecar). They are per-install: deleting and reinstalling the app, or setting up a new phone, **wipes them** — the reported "my signatures were gone" bug. Scanned documents already sync via iCloud; signatures do not.

## Goal & scope

Persist signatures to iCloud so they **survive reinstall / new-phone setup** and are available on another device signed into the same iCloud account.

**Primary scenario (a):** reinstall / device-migration survival. Signatures persist to the cloud and reappear after a fresh install.

**Secondary (sequential, not concurrent):** a scanning/signing session started on iPhone in the morning is finished on iPad (same iCloud account) that afternoon. The documents already sync; the signature just needs to be present when the iPad opens hours later.

**Explicitly out of scope:** concurrent multi-device editing / real-time propagation while both devices are live. This does not happen for this app (iPhone-only; sequential handoff at most), so no live `NSMetadataQuery` observation is built.

## Non-goals

- No new signature UI, no typed/drawn signatures, no per-signature settings.
- No change to `SignatureStore`'s public API or its callers.
- No `NSMetadataQuery` / live observers.
- No CloudKit.

## Chosen approach

**A single archive file in the hidden sibling of the iCloud document scope.**

The app's ubiquity container (`iCloud.ca.peter-jones.DocumentScanner`) has a root above `/Documents`. iCloud Drive syncs the whole container, but Files.app (and the app's own scan library, which enumerates `/Documents`) only surfaces `/Documents`. Placing signatures at `<container root>/Signatures/` — a **sibling of `/Documents`, not inside it** — keeps them synced but **hidden from Files and from the scan library**, and not user-deletable.

```
<ubiquity container root>/
├── Documents/          ← Files shows this = scan library (PDFs + folders)
└── Signatures/         ← synced by iCloud, hidden from Files  ← signatures live here
    └── signatures.dat
```

On-disk (macOS): `~/Library/Mobile Documents/iCloud~ca~peter-jones~DocumentScanner/Signatures/signatures.dat`.

### Why a single file (not the current directory of PNGs)

One file makes sync trivial: a fresh device downloads/materializes it with **one coordinated read** — no folder-enumeration or per-file placeholder guesswork (the class of bug that makes signatures "look missing"). Trade-off accepted: last-writer-wins instead of union merge, which only matters under concurrent offline edits on two devices — out of scope.

### Alternatives considered

- **iCloud key-value store (KVS):** simplest sync, inherently hidden, but a hard 1 MB total ceiling and it is off-label for image blobs. Rejected in favor of real iCloud Drive with no ceiling.
- **Many PNG files + live `NSMetadataQuery`** (literal reuse of the documents path): truest union merge, no ceiling, but drags in placeholder-download + live-query machinery; the folder-enumeration edge cases are exactly where "signatures look missing" bugs breed. Overkill for scenario (a).
- **CloudKit private DB:** overkill for a handful of KB-scale images.

## Architecture

The change is localized to `SignatureStore`. **Its public API is unchanged** — `all()`, `add()`, `remove(id:)`, `rename(id:to:)`, `signature(withID:)` — so callers (`SettingsView`, `DocumentViewerView`, `SignaturePicker`) are untouched.

### Storage shape

`signatures.dat` is a binary property list of a `Codable` archive:

```
SignatureArchive { entries: [Entry] }
Entry { id: String, pngData: Data, name: String?, createdAt: Date }
```

Binary plist is compact for raw PNG bytes (no base64 bloat) and preserves newest-first order (sort by `createdAt` descending on read).

### Location resolution & convergence

The store resolves its target via the existing `ICloudContainer` pattern (injectable for tests): an **iCloud archive URL** (`<container root>/Signatures/signatures.dat`, when iCloud is available) and a **local archive URL** (`Application Support/Signature/signatures.dat`).

**One lazy "converge toward iCloud" path** on load handles migration, offline-first-launch promotion, and steady state:

- **iCloud available, archive present** → coordinated-read it (source of truth).
- **iCloud available, no archive yet** → seed it and promote up:
  - a **local `signatures.dat`** exists → copy up to iCloud, read it; else
  - **old-format `<uuid>.png` + `names.json`** exist → build the archive from them, write to iCloud, read it; else
  - empty (no signatures yet).
- **iCloud unavailable** → same seeding against the **local** location; promoted to iCloud on a later load once iCloud is back.

Writes (`add` / `remove` / `rename`) serialize the full set and do a coordinated write to the resolved location (iCloud if available, else local).

### Migration (one-time)

The "build archive from old PNGs + `names.json`" branch is the v2.7 migration. It fires the first time only (skipped once `signatures.dat` exists), is idempotent, and **never deletes the old PNGs** — they remain as a local backup (tiny, local-only). The existing legacy single-`signature.png` fold-in is preserved.

### Fresh device (new phone / reinstall)

The archive arrives as a non-materialized iCloud placeholder. Before reading, the store calls `startDownloadingUbiquitousItem` and does a coordinated read, which **waits for the tiny file to materialize** — so `all()` returns real signatures, never nil/empty due to a not-yet-downloaded file.

### "Load latest on open" (no live query)

`all()` re-reads the archive on every call, and callers already invoke it on view appearance (Settings list, "Choose a Signature" sheet). View appearance *is* the refresh: the coordinated read pulls whatever iCloud has synced by then, which for an hours-later handoff is the up-to-date file.

## Error handling

Fail safe — never destructive:

- **Corrupt/undecodable archive** → `all()` returns `[]` **and does not overwrite or delete the file.** A bad read must never trigger a save that clobbers real data; the file is left for the next sync/launch, and old local PNGs remain as backup. (Most important guard — degrade to "temporarily empty," never "permanently wiped.")
- **iCloud read/download fails or times out** → return what's locally available (possibly empty), no crash; next view-appearance re-read retries.
- **Write failures** surface via the existing `add() throws` path (Settings handles a save error); reads stay non-throwing, returning `[]` as today.
- **No half-written file** — `NSFileCoordinator` + atomic write (same as `DocumentStorage`).
- **Conflicts = last-writer-wins** — if iCloud keeps conflict versions, take `currentVersion` and mark the rest resolved so a freak conflict can't wedge the file. (Irrelevant to sequential use.)

## Testing

Location resolution is injectable, so the convergence logic is unit-testable with plain temp directories — **no real iCloud account required.** "iCloud available" = iCloud temp dir provided; "unavailable" = nil provider → local temp dir.

1. **Round-trip** — add → `all()` returns it; rename sets/clears name; remove drops it.
2. **Migration** — seed old `<uuid>.png` + `names.json` → load → archive built, signatures + names present, **PNGs still on disk**, second load doesn't rebuild/duplicate (idempotent).
3. **Legacy `signature.png`** still folds in.
4. **Promotion** — local archive present, iCloud dir empty → load copies it up (file now exists in iCloud dir) and returns signatures.
5. **Corrupt archive** — `all()` returns `[]` **and the file is left intact** (not deleted/rewritten).
6. **Fallback** — nil iCloud provider → local location works end-to-end.
7. **Order** — newest-first survives the round-trip.

**On-device (Release build) smoke — can't be unit-tested (needs real iCloud):**
- Fresh install / reinstall pulls signatures back.
- Morning-iPhone → afternoon-iPad handoff (same iCloud account): a signature added on one device is available on the other.
- Verify `Signatures/` does **not** appear in Files.app or in the app's scan library.

## Files (anticipated)

- **Modify:** `Signature/SignatureStore.swift` — new single-file archive backing, injectable location resolution, convergence/migration, coordinated reads/writes, download materialization.
- **Possibly add:** a small `SignatureArchive` Codable type (may live in `SignatureStore.swift` or its own file).
- **Add:** `DocumentScannerTests/SignatureStoreICloudTests.swift` (or extend existing signature-store tests) covering the cases above.
- **No changes** to `SettingsView`, `DocumentViewerView`, `SignaturePicker` (public API unchanged).
- Update `docs/FutureEnhancements.md` (mark A built) in the same session as the code.
