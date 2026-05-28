# Dev Build Setup

The Xcode project produces two parallel apps that can coexist on the
same iPhone:

| | Bundle ID | Display name | Entitlements | iCloud |
|---|---|---|---|---|
| **Release** | `ca.peter-jones.DocumentScanner` | Pocket Scanner | `DocumentScanner.entitlements` | yes |
| **Debug** | `ca.peter-jones.DocumentScanner.dev` | Pocket Scanner Dev | `DocumentScanner-Dev.entitlements` (empty) | no |

The two installations are completely separate apps to iOS — different
home-screen icons, different sandbox containers, different App Store
identities. Installing one does not affect the other.

## How to build each

Both configurations build from the same source, just with different
build settings:

- **Dev** (default for `⌘R`): produces `Pocket Scanner Dev` and
  installs it via Xcode → your iPhone (or simulator).
- **Release**: only used during `Product → Archive`. The archived
  binary uploads to App Store Connect as the user-facing `Pocket Scanner`.

### Running Release locally (rare — read the warning first)

> **Warning: running Release locally replaces the App Store install.**
> Release uses the production bundle ID (`ca.peter-jones.DocumentScanner`),
> which iOS treats as the same app as the one on the App Store. Building
> from Xcode overwrites the App Store binary with your locally-signed copy.
>
> What's lost: the "App Store install" status — the listing shows "Get"
> instead of "Open" until you reinstall.
>
> What's preserved: all your data. The iCloud container is keyed by
> bundle ID, not signing identity, so scans/settings survive.
>
> Recovery: delete the app from your phone (long-press → Remove App),
> then re-install from the App Store. Two minutes, no data loss.
>
> **In almost all cases the Dev build covers what you need.** Only
> flip to Release locally if you specifically must verify the
> production-signed binary on a real device.

If you've read the above and still need to:

1. **Product → Scheme → Edit Scheme…** (⌘<)
2. Select **Run** in the left sidebar
3. In the right panel, **Info** tab (default) → first row is **Build
   Configuration** — switch from `Debug` to `Release`
4. ⌘R

Switch back to Debug as soon as you're done, or the next `⌘R` will
silently replace your App Store install again.

## Limitations of the dev build

**No iCloud sync.** The dev entitlements file is empty, so iCloud
Drive isn't requested. Two consequences:

1. **Saves go to local Documents.** `ICloudContainer.resolveDocumentsURL()`
   falls back to the app's local Documents directory when iCloud isn't
   available, so scans don't disappear — they just live locally only.

2. **Library list appears empty.** `MetadataQueryLibraryStore` only queries
   `NSMetadataQueryUbiquitousDocumentsScope` (iCloud Drive), so it can't
   see the local scans. They're saved, but orphaned from the UI.
   *This is a pre-existing app bug for any user without iCloud — not
   specific to the dev configuration.* Worth fixing eventually.

**Practical impact**: in the dev build you can fully test features
that don't depend on the library list:

- ✅ Launch screen
- ✅ Settings (App Lock, About, Send Feedback)
- ✅ Camera capture
- ✅ Scan pipeline (OCR, PDF assembly)
- ✅ Smart scan-name suggestions in the Name & Save sheet
- ✅ Per-page editing UI (if you navigate to it before saving)
- ❌ Library list / browsing
- ❌ Search (depends on library)
- ❌ Folders (depends on library)
- ❌ iCloud sync / conflict resolution

For features in the bottom group, build Release temporarily, accept
that the App Store Pocket Scanner gets replaced for the test session,
then re-install from the App Store when done.

## How it's wired

- `DocumentScanner-Dev.entitlements` — empty plist, no iCloud claims
- `project.pbxproj` Debug build settings override three keys:
  - `CODE_SIGN_ENTITLEMENTS` → the empty Dev entitlements file
  - `INFOPLIST_KEY_CFBundleDisplayName` → "Pocket Scanner Dev"
  - `PRODUCT_BUNDLE_IDENTIFIER` → `ca.peter-jones.DocumentScanner.dev`
- Release config keeps the original values

## Promoting dev to iCloud-enabled later

If you ever want the dev build to also sync to iCloud (e.g., to test
folders or sync features without trashing your prod library):

1. Apple Developer Portal → Identifiers → register a new iCloud
   container, e.g. `iCloud.ca.peter-jones.DocumentScanner.dev`
2. Update `DocumentScanner-Dev.entitlements` to include
   `com.apple.developer.icloud-container-identifiers`,
   `com.apple.developer.icloud-services`, and
   `com.apple.developer.ubiquity-container-identifiers` — all pointing
   at the new container ID
3. Optionally update `Info.plist` `NSUbiquitousContainers` to add
   the new container with display name "Pocket Scanner Dev"

This costs about 15 minutes one-time, but means iCloud-using features
become fully testable in dev without touching the production library.
