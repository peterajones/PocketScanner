# Spec: Debug touch-indicator overlay

**Date:** 2026-06-11
**Status:** Approved (design) — ready for implementation plan
**Related:** supports the App Preview video effort
(`docs/superpowers/specs/2026-06-10-app-preview-design.md`)

## Goal

A DEBUG-only, app-wide overlay that draws a fading circle at each touch point, so taps
and drags are visible when recording App Preview / demo videos. Toggled from the
Settings screen and persisted, so it can be reused for every future preview re-shoot.

## Scope decisions (from brainstorming)

- **DEBUG-only.** The entire feature is wrapped in `#if DEBUG`; it compiles to nothing
  in Release and cannot exist in the App Store build.
- **Passive observation.** The overlay must never consume, cancel, or delay touches —
  the app stays fully usable while recording.
- **Toggle: a persisted Settings switch.** A DEBUG-only "Developer" section in
  `SettingsView` with a `Toggle` backed by `@AppStorage("touchIndicatorsEnabled")`,
  default **off**. Matches the existing `showFolders` toggle pattern.
- **SwiftUI install.** The app is pure SwiftUI (no AppDelegate/SceneDelegate); the
  overlay installs via a small `UIViewRepresentable`, not a window-class swap.

## Non-goals

- Shake-to-toggle or any non-Settings control (considered, dropped — YAGNI).
- Availability in Release / TestFlight / App Store builds.
- A third-party dependency (TouchVisualizer, COSTouchVisualizer, Fingertips) — those
  are UIKit window-swizzle based and don't fit a SwiftUI app cleanly.
- Recording or screenshotting the touches into a file — that's the camera/QuickTime's job.

## Architecture

All types live in one cohesive DEBUG file: `DocumentScanner/Debug/TouchIndicatorOverlay.swift`.

### Components

1. **`TouchObservingGestureRecognizer: UIGestureRecognizer`**
   - Attached to the foreground scene's key window.
   - Overrides `touchesBegan/Moved/Ended/Cancelled` to report each `UITouch` (identity +
     location in window coordinates) to a callback.
   - `cancelsTouchesInView = false`; `delaysTouchesBegan/Ended = false`; a delegate
     returns `true` from `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)`.
   - Never transitions to `.recognized` (stays passive) so it cannot intercept or cancel
     the app's own gestures/taps.

2. **`TouchIndicatorOverlay`**
   - A passthrough `UIWindow` at a high `windowLevel` (above the app's normal window),
     `isUserInteractionEnabled = false`, clear background.
   - Maintains a map of `UITouch` → indicator layer. Adds a circle on touch-begin,
     repositions it on move, animates it out on end/cancel.

3. **`TouchIndicatorInstaller: UIViewRepresentable`**
   - On `makeUIView`/`updateUIView`, finds its `window` and the active `UIWindowScene`,
     creates the overlay window, and attaches the recognizer to the key window.
   - Reads the `touchIndicatorsEnabled` flag: when on, install/show; when off, remove the
     recognizer and hide the overlay. Idempotent.

4. **`.touchIndicators()` View modifier**
   - A `ViewModifier` that overlays the (zero-size, invisible) `TouchIndicatorInstaller`.
   - In Release builds it is a no-op (the modifier body is `#if DEBUG`).

### Wiring

- `SettingsView` gains a `#if DEBUG` "Developer" section:
  `Toggle("Touch Indicators", isOn: $touchIndicatorsEnabled)` where
  `@AppStorage("touchIndicatorsEnabled") private var touchIndicatorsEnabled = false`.
- `DocumentScannerApp` applies `.touchIndicators()` once at the root of the
  `WindowGroup` content so the installer is always present (it self-gates on the flag).

## Visual behavior

- Circle ~50 pt diameter, fill brand purple `#7B12A1` at ~0.35 alpha, ~1.5 pt solid
  stroke of the same colour at full alpha.
- Touch-down: appears at full opacity at the touch point.
- Move: the circle follows the finger (drags/swipes are visible).
- Touch-up / cancel: scale to ~1.1× and fade opacity to 0 over ~0.5 s, then remove.
- Multitouch: one indicator per `UITouch`, tracked by touch identity.

## Testing

This is UIKit window/touch/animation code and is not meaningfully unit-testable. Plan:

- **One unit test** for persistence: `@AppStorage("touchIndicatorsEnabled")` (or a thin
  wrapper reading `UserDefaults`) defaults to **false** when unset. This guards against
  the overlay ever being on by default.
- **Functional check:** the on-device QuickTime recording itself — toggle on, confirm
  circles appear at taps and the app remains fully responsive.
- Honest call-out: no TDD for the visual/recognizer layer; it is verified by eye on device.

## Deliverables

- `DocumentScanner/Debug/TouchIndicatorOverlay.swift` (new, all `#if DEBUG`).
- `Settings/SettingsView.swift` — DEBUG-only Developer section with the toggle.
- `App/DocumentScannerApp.swift` — `.touchIndicators()` at the root.
- One unit test for the default-off persistence.

## Known constraints / accepted trade-offs

- DEBUG-only by design; not available to testers via TestFlight (acceptable — it is a
  recording aid, not a user feature).
- The passive recognizer observes touches that begin within the key window; system UI
  presented in separate windows (e.g. the share sheet, Face ID) won't show indicators.
  Acceptable — the storyboard beats happen in the app's own window.
