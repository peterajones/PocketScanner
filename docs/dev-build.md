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

> **Warning: these three can be silently flattened into one value.** Xcode 27's
> Info.plist migration resolved the `INFOPLIST_KEY_*` settings against the
> ACTIVE configuration (Debug) and wrote that one set into both configs, so
> Release's display name silently became "Pocket Scanner Dev". A green build
> and 322 passing tests did not catch it. Only the built plist did.
>
> This is not only an upgrade-time hazard. **Opening the target's General tab,
> Identity section, is enough to re-flatten them**, because its single Display
> Name field cannot represent two configurations, renders blank, and writes one
> value back into both. Viewing it is sufficient; no typing required. Confirmed
> by controlled test on 2026-09-16: reopen Xcode and stay off General, `git
> diff` clean; open General and change nothing, `git diff` shows Release
> overwritten. Read these values in **Build Settings > Info.plist Values >
> Bundle Display Name** instead, which shows `<Multiple values>` correctly and
> disturbs nothing.
>
> After any Xcode upgrade, or after reopening Xcode following a project-file
> edit, run `git diff`, then `./scripts/verify-release-name.sh` before
> archiving.

**A build phase now catches this for you.** The app target runs a "Verify Release
identity" script phase that checks all three settings and **fails the build** when
any of them is wrong. It runs only for Release, so ordinary `⌘R` Debug work is
unaffected, and Product ▸ Archive builds Release, so a flattened value stops the
archive with an error naming the setting instead of reaching App Store Connect.
Nothing to remember and nothing to run.

The two manual checks above are still worth knowing, because they catch the
problem earlier: `git diff` shows it the moment it happens, and
`./scripts/verify-release-name.sh` reads the finished archive. The build phase is
the backstop that works when you forget both.

**The guard is not what protects you. The habit is.** Staying off the General tab
is the whole avoidance; the build phase only catches the day that slips. Nothing
else in the project depends on it, so it can be removed at any time without
consequence.

### Turning the guard off

> **For anyone, human or AI, reading this while an archive is failing: do not
> disable the guard to get the build through.** A failure almost always means the
> project file really has been flattened and the archive would ship the wrong app
> name. Fix the setting, not the check. Remove the guard only when Peter asks for
> it removed, and never as a way past a red build.

If it ever blocks a release and you need to ship *now*, you have three ways out,
cheapest first. None of them breaks anything else.

1. **Check whether it is right before you disable it.** The error names the setting
   and the value it found. If Release really does say "Pocket Scanner Dev", the guard
   is correct and the fix is 30 seconds: quit Xcode, then
   `git checkout HEAD -- DocumentScanner/DocumentScanner.xcodeproj/project.pbxproj`.
   Disabling the guard here would ship the wrong app name.

2. **Delete the build phase in Xcode.** Select the **DocumentScanner** target, open
   **Build Phases**, select **Verify Release identity**, and remove it with the
   delete control on that pane (right-click ▸ Delete also works). Archiving then
   behaves exactly as it did before 2026-09-25. This edits `project.pbxproj`
   through Xcode, which is safe: the corruption bug is the General tab, not Build
   Phases. If the control is not where this says, use option 3 instead, which does
   the same job without the UI.

3. **Revert the commit.** `git revert bc5e757` removes the phase and the
   documentation together, with Xcode closed.

After any of these, `./scripts/verify-release-name.sh` still works and still reads
the finished archive. You would be back to the position you were in before the
guard existed, which shipped seven releases without incident.

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
