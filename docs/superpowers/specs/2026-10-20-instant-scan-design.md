# Instant Scan — Design

**Status:** Approved 2026-10-20. **Built, device-verified and merged to main 2026-10-20; ships in
v4.0 (39).** See "As built" at the end for where the build departed from this design.

## Why

Pocket Scanner's best moments are fast ones. Peter's example: an optometrist left a
prescription on the table without handing it over; he scanned it and left. Today that
takes unlock → find the app → wait for the library → `＋` → Scan Document. The goal is
**one press to a live camera**.

Two secondary reasons, both from the 2026-10-20 strategy session:

- **Apple is pushing App Intents.** WWDC 2026 coverage (third-party, not yet checked
  against Apple's own session pages) says App Intents replaces SiriKit as the only way
  Siri reaches third-party apps in iOS 27. Adopting it is a plausible hook for an App
  Store **Featuring Nomination**, the only route to new users that doesn't depend on
  search.
- **No evidence it affects App Store search ranking.** This feature is for owners of the
  app and for the nomination story. It does not fix discoverability on its own; the
  listing rework (a separate project) does that.

This is the first of three projects agreed that day: (1) instant scan, (2) Siri/Spotlight
*finding* documents ("show my lab results"), (3) listing rework around real use cases.

## What it does

### Entry points

All of these run **one App Intent** ("Scan Document"), so they behave identically:

| Entry point | Availability |
|---|---|
| Action button | iOS 17.6+ (assign via Shortcuts on 17; directly as a Control on 18+) |
| Siri / Spotlight phrase, e.g. "Scan with Pocket Scanner" (an App Shortcut) | iOS 17.6+ |
| Control Center button | iOS 18+ |
| Lock-screen button | iOS 18+ |

The deployment target stays **iOS 17.6**. On iOS 17 there are no Controls; nothing else
changes for anyone who never uses the feature.

### The flow

1. The intent opens Pocket Scanner straight into the **existing scanner camera**
   (`scannerPresenter` / `CaptureSheet`, the same capture the `＋` ▸ Scan Document path
   uses).
2. After the user captures and taps Save in the camera, the scan is saved to
   **Main Library** (the storage root).
3. Pocket Scanner then shows **that document open in the viewer**, pushed onto the
   library's `NavigationStack` (`DocumentRoute`), so Back lands on the library.

**Cancel:** dismissing the camera without saving creates nothing; the app shows
wherever it would normally show (the lock screen, if the lock is on).

### With the Face ID lock on (decided by Peter)

**Camera first; Face ID before anything is shown.**

- The camera is presented **above** the `LockGate` lock screen, and nothing from the
  library is visible at any point before Face ID succeeds.
- `LockGate`'s automatic Face ID prompt (its `.task(id: isLocked)`) must **not** fire
  while an instant-scan capture is in progress. Today it fires on cold launch and on
  relock, which would put a Face ID sheet over the camera.
- **The scan is saved before Face ID** *(Claude's call, explained to Peter)*. If Face ID
  fails or is cancelled, the scan is already in Main Library, behind the lock, and is
  not lost. The app stays locked, and the new document opens after the next successful
  unlock, or not at all *(builder's choice)*.
- Accepted consequence: someone holding the unlocked phone can *add* a scan without Face
  ID. They cannot *see* anything.
- Coming from the lock screen, iOS requires the **phone** itself to be unlocked before
  any app opens. That is iOS behaviour, not something this feature controls. Verify it
  on a device.

### Defaults *(Claude's calls)*

- **Filter and page size:** the user's existing settings (`defaultScanFilter`,
  `scanPaperSize`).
- **Name:** the existing auto-namer (`DefaultDocumentName` plus OCR), exactly as a
  normal scan.
- **OCR:** runs as it does today, so the document is searchable.
- **Review prompt:** an instant scan counts as a successful scan for
  `ReviewPromptTracker`, but the prompt must never appear over the camera or the Face ID
  prompt. Fire it, if at all, once the document is showing.

- **Telling owners it exists:** add **one new tip** to the existing Tips screen
  (`Settings/Tip.swift`) explaining how to put Scan Document on the Action button, in
  Control Center or on the lock screen. It is localized like every other tip and gets
  the de/it/zh-Hans back-translation pass.
- **Release work is out of this plan:** the version bump, release notes, screenshots and
  the Featuring Nomination follow the usual release process, not this build plan.

### No naming sheet: silent save (decided by Peter)

An instant scan **skips `NameDocumentSheet`**. After the camera's Save, the document is
saved with the defaults above and opened in the viewer. "It can be renamed later," using
the existing Rename.

What this means for the build:

- **A new save path outside the sheet.** Today `NameDocumentSheet.save()` waits for the
  OCR task, and the auto-namer needs its result. The silent path has to do the same:
  wait for OCR, name the document, apply the default filter, write the file.
- **Something on screen while OCR runs.** Show a short "Saving…" state, not a blank
  pause. With the lock on, it sits **above the opaque lock screen** and shows no page
  content.
- **Order with the lock on:** camera → Saving… → saved → Face ID → document opens.
  Without the lock: camera → Saving… → document opens.
- The filter and name can be changed afterwards, as for any document.

## Constraints

- **Privacy promise:** nothing leaves the device. App Intents and Controls are local; no
  new network access.
- **Localization:** the App Shortcut phrase(s), the Control's title and any new UI
  strings ship in **en, es, fr, de, it, zh-Hans**. de/it/zh-Hans copy needs the
  standing back-translation QA pass (`docs/superpowers/qa/`). Apple requires App
  Shortcut phrases to include the app name.
- **Do not open the target's General tab** (`docs/dev-build.md`, FB24809836). Adding a
  widget-extension target for the Controls means editing build settings; do it in Build
  Settings, and the "Verify Release identity" build phase must still pass.
- **Both storage modes:** the iCloud store (`MetadataQueryLibraryStore`) and the
  local-only store (`InMemoryLibraryStore`) must show the new document.
- **UI-test mode** (`-UITestMode`, `StubDocumentScanner`) must stay hermetic.

## Non-goals

- Choosing a destination folder from the intent (always Main Library).
- Siri/Spotlight *finding* or opening existing documents: project 2.
- Scanning from the lock screen without unlocking the phone (would need Apple's
  locked-camera capture extension, which can't host the system document camera).
- Any change to the existing `＋` ▸ Scan Document flow.
- Widgets other than the Control.

## Apple documentation check (2026-10-20)

Read from developer.apple.com's documentation JSON, not from third-party coverage:

- **`openAppWhenRun` is deprecated as of iOS 26** ("Please provide 'supportedModes'
  instead"), and `supportedModes` / `IntentModes` exist only on **iOS 26+**. With a 17.6
  deployment target, **conform the intent to `OpenIntent` (iOS 16+)** instead: "The
  system automatically brings your app to the foreground to run this app intent." That
  avoids both the deprecated property and the iOS 26-only one. `OpenIntent` needs a
  `target` parameter. A one-case `AppEnum` (the scanner screen) is the pattern in
  Apple's own Controls example. Also: setting `openAppWhenRun` to `true` "generates an
  error if the app intent runs in an app extension".
- **Controls:** `ControlWidget` and `ControlWidgetButton` are **iOS 18+**, live in a
  **Widget Extension** target (File ▸ New ▸ Target ▸ Widget Extension, "Include
  Control"), and are exposed through a `WidgetBundle`. To open the app from a control,
  use an `OpenIntent`, and "the system requires the Target Membership of the app intent
  to be set to both the app and the widget extension". Buttons are stateless, "for
  fire-and-forget actions such as … launching an app". The same control serves Control
  Center, the Lock Screen and the Action button.
- **`authenticationPolicy`** defaults to `.alwaysAllowed`, which "allows the intent to
  run without authentication, including when the device is locked". Opening the app
  still goes through iOS's own unlock; verify the lock-screen path on a device.
- **SiriKit's overview page** now says it provides "legacy support" and, "to implement
  modern support … and integrate your app with Apple Intelligence and Siri AI, use the
  App Intents framework". That supports the direction. The page doesn't state a formal
  deprecation date, and the WWDC 2026 session claims remain unchecked.
- **`AppShortcutsProvider`** is iOS 16+. The page notes Apple may use anonymized App
  Shortcut phrases and titles to train its models, which has no bearing on user data or
  the privacy promise.

## Left to the builder

- How the intent hands off to the running UI (e.g. an observable pending-action flag
  that `LibraryView` reacts to), and how it behaves on cold launch vs. warm.
- What happens if the intent fires while the user is mid-task in a modal (signature
  placement, naming sheet, an alert). Hard rule: **never discard unsaved user work.**
  Waiting, or ignoring the request, are both acceptable.
- What happens if the intent fires while the iCloud onboarding screen is showing:
  onboarding wins, and the scan request may be dropped.
- Camera permission denied: reuse `CameraDeniedView`.
- Navigation when the user was deep in a folder or viewer: resetting to
  `[DocumentRoute(new doc)]` on the library stack is fine.
- Whether the intent code lives in a shared framework or is compiled into both the app
  and the widget-extension target.
- Test strategy: the pure parts (pending-action state, lock sequencing) unit-tested; a
  device check for the Action button, Control Center, the lock screen and Face ID.

## As built (2026-10-20)

Built through the plan with per-task reviews, a whole-branch review and device checks D1–D8, all
passing on Peter's iPhone. 342 unit tests and 3 UI tests pass. Where the build departed from this design,
and why:

- **Failure alert:** "Couldn't save" with Retry is a native `UIAlertController` presented over the
  Saving screen, not the app's SwiftUI `AlertCenter`. The root `.alert` can't appear over an open
  sheet, which would have left the scan stuck with Face ID never prompting.
- **Opening the document:** it is pushed onto the library stack only when no modal is open, checked
  as `topMost(from: root) === root` because the instant-scan screens are still dismissing when the save
  lands. With a sheet open, the scan is saved and not opened.
- **A second scan while locked** replaces the first scan's "open after unlock". The first is still in
  Main Library. Without this, a locked app silently ignored every later instant scan.
- **The Face ID auto-prompt is withdrawn on cancel** (`withTaskCancellationHandler` →
  `LAContext.invalidate()`), so it can't sit over the camera on a cold launch. D2 confirmed: camera
  first, exactly one Face ID prompt after the save.
- **Controls extension:** target `PocketScannerControlsExtension`; bundle IDs
  `ca.peter-jones.DocumentScanner.Controls` / `.dev.Controls`; iOS 18.0; display name "Pocket Scanner" /
  "Pocket Scanner Dev"; version and build hand-synced with the app; `CONTROLS_EXTENSION` compiles out
  the app-only call in the shared intent file. Creating the target in Xcode did not open the General tab
  this time, and the app's settings were verified unchanged.
- **App Shortcut phrases:** `AppShortcuts.xcstrings` stores both phrases as **one string set under the
  first phrase**, which is how Xcode keys them. Separate keys made the second phrase "stale" and
  produced build warnings. The short title is translated in `Localizable.xcstrings`.

**What D1–D8 taught that users will meet:**

- The Action button must be set to the **Scan Document control** (or a Shortcut running it). "Open
  Pocket Scanner" just opens the app.
- A lock-screen slot only accepts the control after one of the two existing buttons is removed.
- Siri asks once to "turn on" the app's shortcuts before "Scan with Pocket Scanner" works.
- The first instant scan asks for camera permission, as any first scan does.
- From a locked phone, iOS asks for Face ID or the passcode before the app opens. That is iOS
  behaviour, and the reason this feature is "camera first after unlock", not "camera from the lock
  screen".
