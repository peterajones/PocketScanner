# How Pocket Scanner stores data in iCloud

A practical map of *where* the app's files actually live, how that relates to
the iCloud Drive you see in Finder / the Files app, and how the "it just syncs"
magic actually works. Written for someone comfortable with web dev but new to
Apple's iCloud container model.

## The container

Every iCloud-enabled app gets a **ubiquity container** — a private folder that
iCloud keeps in sync across the user's devices. Ours is identified by
`iCloud.ca.peter-jones.DocumentScanner` (set in the app's entitlements).

The app asks the system for it at runtime with
`FileManager.url(forUbiquityContainerIdentifier:)`. That returns `nil` when the
user is signed out of iCloud (or has it disabled for the app) — which is the
signal the app uses to fall back to local-only storage.

## Where it lives on the Mac

On a Mac signed into the same iCloud account, the container lives on disk at:

```
~/Library/Mobile Documents/iCloud~ca~peter-jones~DocumentScanner/
├── Documents/      ← the user-visible "scan library"
│   ├── T3-slip.pdf
│   └── Receipts/   ← scan folders
└── Signatures/     ← app-private; synced but hidden from the user
    └── signatures.dat
```

Two things trip people up:

- **The dots become tildes.** The container id `iCloud.ca.peter-jones.DocumentScanner`
  maps to the on-disk folder name `iCloud~ca~peter-jones~DocumentScanner`. That's
  just Apple's naming convention.
- **`~/Library` is hidden, and `Mobile Documents` is TCC-protected.** Finder hides
  `~/Library` by default (get there via **Go → Go to Folder…**). And even in
  Terminal, listing *inside* `Mobile Documents` gives `Operation not permitted`
  until you grant Terminal **Full Disk Access** (System Settings → Privacy &
  Security). That's a macOS privacy protection, not a bug.

## The relationship to "iCloud Drive" in Finder / Files

`~/Library/Mobile Documents/` **is** the real on-disk home of iCloud Drive. The
"iCloud Drive" item you see in Finder's sidebar (or the Files app on iPhone) is
not a separate copy or an alias — it's a **view onto that same location**.

But that view is deliberately narrow: for a third-party app, iCloud only surfaces
the container's **`Documents/`** subfolder (because our Info.plist sets
`NSUbiquitousContainerIsDocumentScopePublic = true`). Anything in the container
*outside* `Documents/` is still synced by iCloud but **never shown** in Finder or
the Files app.

That's the whole trick behind where signatures live:

- **`Documents/`** = the scan library. Shown in Files as "Pocket Scanner"; the
  app's `MetadataQueryLibraryStore` enumerates it for the document/folder list.
- **`Signatures/`** = a **sibling** of `Documents/`, one level up — *not inside* it.
  So iCloud syncs `signatures.dat` across devices, but it never appears in Files
  or in the app's own scan library, and the user can't accidentally
  delete/rename it. (This is the v2.7 "signature iCloud sync" design.)

> Cosmetic aside: the Files folder may still read **"Document Scanner"** (the old
> app name) even though the Info.plist now says "Pocket Scanner". iCloud caches
> the container's display name from when it was first created and won't re-read
> it. Pre-existing and harmless.

## How the syncing actually works (materialization)

The files in `Mobile Documents` are **real files, not symlinks** — but each one
can be in one of two states:

- **Materialized** — the actual bytes are on local disk.
- **Dataless (evicted)** — only a lightweight **placeholder** is on disk (you
  still see the filename and size), with the real bytes up in iCloud. Finder
  shows these with a small ☁️ download icon. When anything *reads* the file,
  macOS transparently downloads ("faults in") the bytes on demand.

A dataless placeholder is an **APFS feature managed by the File Provider daemon**
(`bird`), not a symlink or a redirect. The path always resolves; the *content* is
lazy.

**Web analogue:** think of a CDN-backed asset. The URL (path) always works, but
the first request can be a cache miss that fetches from origin (materialize),
while later requests are cache hits (already local). It's fetch-on-read.

### Why the app has to care

On a **fresh device** (new phone, or a reinstall), the synced file first arrives
as a *dataless placeholder*. If the app naively read it, it could get an empty
stub and conclude "no data." So both storage layers coordinate the download:

- **Documents** use `MetadataQueryLibraryStore` (an `NSMetadataQuery`) to observe
  ubiquitous items and drive downloads — the heavyweight, live-updating path.
- **Signatures** (`SignatureStore`) take the lighter path that suits a single
  small file: before reading `signatures.dat`, call
  `startDownloadingUbiquitousItem` and do a coordinated read, which waits for the
  tiny file to materialize. So a fresh device pulls the real signatures instead of
  reading an empty placeholder — the exact failure the iCloud-sync feature was
  built to prevent.

All writes/reads go through an `NSFileCoordinator` so a half-synced file is never
read mid-write.

## Local fallback (signed out of iCloud)

When `FileManager.url(forUbiquityContainerIdentifier:)` returns `nil` (signed out
of iCloud), the app writes locally instead:

- **Documents** → the app's local `Documents/` directory.
- **Signatures** → `Application Support/Signature/signatures.dat`.

When iCloud later becomes available, the next load lazily **promotes** the local
data up into the container, so nothing is stranded. (`SignatureStore` also
one-time-migrates the pre-v2.7 `<uuid>.png` + `names.json` files into the single
`signatures.dat` archive, leaving the old PNGs in place as a backup.)

## Quick reference

| Thing | Location | Visible to user? | Synced? |
|---|---|---|---|
| Scanned documents | `<container>/Documents/` | Yes (Files → Pocket Scanner) | Yes |
| Signatures | `<container>/Signatures/signatures.dat` | No (hidden sibling) | Yes |
| Local fallback (signed out) | app's `Documents/` + `Application Support/Signature/` | Docs: app only | No (until iCloud returns) |

See also: `docs/superpowers/specs/2026-07-08-signature-icloud-sync-design.md` for
the signature-sync design rationale.
