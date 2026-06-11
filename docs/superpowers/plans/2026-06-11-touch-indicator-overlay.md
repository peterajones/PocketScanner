# Debug Touch-Indicator Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A DEBUG-only, app-wide overlay that draws a fading circle at every touch,
toggled from a persisted Settings switch, for recording App Preview / demo videos.

**Architecture:** A passive `UIGestureRecognizer` on the key window observes touches
without consuming them and forwards them to a passthrough overlay `UIWindow` that draws
animated circle layers. Installed in SwiftUI via a zero-size `UIViewRepresentable`
driven by an `@AppStorage` flag. The whole feature is wrapped in `#if DEBUG`.

**Tech Stack:** Swift, SwiftUI, UIKit (UIWindow, UIGestureRecognizer, CALayer/CAAnimation),
XCTest.

**Spec:** `docs/superpowers/specs/2026-06-11-touch-indicator-overlay-design.md`

---

## File Structure

- Create: `DocumentScanner/DocumentScanner/Debug/TouchIndicatorOverlay.swift` — the whole
  feature: settings constants, overlay window, observing recognizer, installer, modifier.
- Create: `DocumentScanner/DocumentScannerTests/TouchIndicatorSettingsTests.swift` — the
  default-off persistence test.
- Modify: `DocumentScanner/DocumentScanner/Settings/SettingsView.swift` — DEBUG "Developer"
  section with the toggle.
- Modify: `DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift` — apply
  `.touchIndicators()` at the root.

Tasks are ordered bottom-up so the new file compiles after every commit.

> **Xcode target membership:** if the project does NOT use file-system-synchronized
> groups, newly created files must be added to the right target in Xcode
> (`TouchIndicatorOverlay.swift` → **DocumentScanner**; the test → **DocumentScannerTests**),
> or the build won't see them. If it does use synchronized folders, they're picked up
> automatically. Verify with the build step in each task.

Build/test commands used throughout:
```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17'
cd DocumentScanner && xcodebuild test \
  -scheme DocumentScanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DocumentScannerTests
```

---

## Task 1: Settings constants + default-off test (TDD)

**Files:**
- Create: `DocumentScanner/DocumentScanner/Debug/TouchIndicatorOverlay.swift`
- Test: `DocumentScanner/DocumentScannerTests/TouchIndicatorSettingsTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DocumentScannerTests/TouchIndicatorSettingsTests.swift`:

```swift
import XCTest
@testable import DocumentScanner

final class TouchIndicatorSettingsTests: XCTestCase {
    func test_defaultsToDisabled() {
        XCTAssertFalse(TouchIndicatorSettings.defaultEnabled)
    }

    func test_usesStableStorageKey() {
        XCTAssertEqual(TouchIndicatorSettings.key, "touchIndicatorsEnabled")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the test command above.
Expected: FAILS to compile — `cannot find 'TouchIndicatorSettings' in scope`.

- [ ] **Step 3: Create the file with the settings constants**

Create `DocumentScanner/Debug/TouchIndicatorOverlay.swift`:

```swift
#if DEBUG
import Foundation

/// Storage key + default for the DEBUG-only touch-indicator overlay used when
/// recording App Preview / demo videos. Default is OFF so it never shows unless
/// explicitly enabled in Settings.
enum TouchIndicatorSettings {
    static let key = "touchIndicatorsEnabled"
    static let defaultEnabled = false
}
#endif
```

- [ ] **Step 4: Run the test to verify it passes**

Run the test command above (add the new file to the DocumentScanner target first if the
project doesn't use synchronized folders).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Debug/TouchIndicatorOverlay.swift \
        DocumentScanner/DocumentScannerTests/TouchIndicatorSettingsTests.swift
git commit -m "feat(debug): touch-indicator settings key (default off) + test"
```

---

## Task 2: Overlay window that draws the circles

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Debug/TouchIndicatorOverlay.swift`

(No unit test — this is UIKit window/CALayer drawing, verified on device in Task 6.)

- [ ] **Step 1: Add the overlay class**

Append inside the `#if DEBUG` block (before the closing `#endif`):

```swift
import UIKit

/// A passthrough overlay window that renders a fading circle per active touch.
/// `isUserInteractionEnabled == false` so it never intercepts touches; the app's
/// own window stays key (we set `isHidden = false`, never `makeKeyAndVisible`).
final class TouchIndicatorOverlay {
    private var window: UIWindow?
    private var layers: [ObjectIdentifier: CALayer] = [:]
    private let diameter: CGFloat = 50
    private let color = UIColor(red: 123/255, green: 18/255, blue: 161/255, alpha: 1) // #7B12A1

    func attach(to scene: UIWindowScene) {
        guard window == nil else { return }
        let w = UIWindow(windowScene: scene)
        w.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.statusBar.rawValue + 100)
        w.isUserInteractionEnabled = false
        w.backgroundColor = .clear
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        w.rootViewController = vc
        w.isHidden = false
        window = w
    }

    func detach() {
        layers.values.forEach { $0.removeFromSuperlayer() }
        layers.removeAll()
        window?.isHidden = true
        window = nil
    }

    func handle(touches: Set<UITouch>) {
        guard let host = window?.rootViewController?.view else { return }
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: host)
            switch touch.phase {
            case .began:
                let layer = makeCircle()
                layer.position = point
                host.layer.addSublayer(layer)
                layers[id] = layer
            case .moved, .stationary:
                CATransaction.begin()
                CATransaction.setDisableActions(true) // follow the finger, no implicit anim
                layers[id]?.position = point
                CATransaction.commit()
            case .ended, .cancelled:
                if let layer = layers.removeValue(forKey: id) { animateOut(layer) }
            @unknown default:
                break
            }
        }
    }

    private func makeCircle() -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        layer.cornerRadius = diameter / 2
        layer.backgroundColor = color.withAlphaComponent(0.35).cgColor
        layer.borderColor = color.cgColor
        layer.borderWidth = 1.5
        return layer
    }

    private func animateOut(_ layer: CALayer) {
        CATransaction.begin()
        CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.toValue = 1.1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.5
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        layer.add(group, forKey: "out")
        CATransaction.commit()
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Debug/TouchIndicatorOverlay.swift
git commit -m "feat(debug): passthrough overlay window that draws touch circles"
```

---

## Task 3: Passive touch-observing gesture recognizer

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Debug/TouchIndicatorOverlay.swift`

(No unit test — gesture/touch behavior is verified on device in Task 6.)

- [ ] **Step 1: Add the recognizer**

Append inside the `#if DEBUG` block:

```swift
/// Observes every touch in the window it's attached to and forwards them, without
/// ever consuming, delaying, or cancelling them. It never transitions out of
/// `.possible`, so it cannot interfere with the app's own taps/gestures.
final class TouchObservingGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onTouches: ((Set<UITouch>) -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { onTouches?(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { onTouches?(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { onTouches?(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { onTouches?(touches) }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add DocumentScanner/DocumentScanner/Debug/TouchIndicatorOverlay.swift
git commit -m "feat(debug): passive touch-observing gesture recognizer"
```

---

## Task 4: SwiftUI installer + `.touchIndicators()` modifier

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Debug/TouchIndicatorOverlay.swift`

(No unit test — install/teardown is verified on device in Task 6.)

- [ ] **Step 1: Add the installer and coordinator**

Append inside the `#if DEBUG` block:

```swift
import SwiftUI

/// Zero-size representable that wires the overlay + recognizer onto the active
/// window scene when `enabled` is true, and tears them down when false. Idempotent.
struct TouchIndicatorInstaller: UIViewRepresentable {
    var enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.setEnabled(enabled, from: uiView)
    }

    final class Coordinator {
        private let overlay = TouchIndicatorOverlay()
        private var recognizer: TouchObservingGestureRecognizer?
        private var installed = false

        func setEnabled(_ enabled: Bool, from view: UIView) {
            enabled ? install(from: view) : uninstall()
        }

        private func install(from view: UIView) {
            guard !installed else { return }
            guard let scene = view.window?.windowScene
                ?? UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first,
                  let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? view.window
            else { return } // window not ready yet; SwiftUI calls updateUIView again later

            overlay.attach(to: scene)
            let r = TouchObservingGestureRecognizer(target: nil, action: nil)
            r.onTouches = { [weak self] touches in self?.overlay.handle(touches: touches) }
            keyWindow.addGestureRecognizer(r)
            recognizer = r
            installed = true
        }

        private func uninstall() {
            guard installed else { return }
            if let r = recognizer { r.view?.removeGestureRecognizer(r) }
            recognizer = nil
            overlay.detach()
            installed = false
        }
    }
}

private struct TouchIndicatorModifier: ViewModifier {
    @AppStorage(TouchIndicatorSettings.key) private var enabled = TouchIndicatorSettings.defaultEnabled
    func body(content: Content) -> some View {
        content.overlay(
            TouchIndicatorInstaller(enabled: enabled)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
    }
}
#endif
```

- [ ] **Step 2: Add the always-compiled modifier entry point**

The `extension View` must exist in Release too (as a no-op), so add it **outside** the
`#if DEBUG` block, at the very bottom of the file (after the `#endif`):

```swift
import SwiftUI

extension View {
    /// Installs the DEBUG touch-indicator overlay (driven by the Settings toggle).
    /// A no-op in Release builds.
    func touchIndicators() -> some View {
        #if DEBUG
        return modifier(TouchIndicatorModifier())
        #else
        return self
        #endif
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add DocumentScanner/DocumentScanner/Debug/TouchIndicatorOverlay.swift
git commit -m "feat(debug): SwiftUI installer + touchIndicators() modifier (Release no-op)"
```

---

## Task 5: Wire the toggle into Settings and the app root

**Files:**
- Modify: `DocumentScanner/DocumentScanner/Settings/SettingsView.swift`
- Modify: `DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift`

- [ ] **Step 1: Add the DEBUG toggle to SettingsView**

In `SettingsView.swift`, add the persisted property near the other `@AppStorage`
declarations (after `@AppStorage("showFolders") private var showFolders = true`):

```swift
    #if DEBUG
    @AppStorage(TouchIndicatorSettings.key) private var touchIndicatorsEnabled = TouchIndicatorSettings.defaultEnabled
    #endif
```

Then add a Developer section to the `Form`, immediately before `Section("About") {`:

```swift
            #if DEBUG
            Section {
                Toggle("Touch Indicators", isOn: $touchIndicatorsEnabled)
            } header: {
                Text("Developer")
            } footer: {
                Text("Shows a circle at each touch — for recording App Preview videos. Debug builds only.")
            }
            #endif
```

- [ ] **Step 2: Apply `.touchIndicators()` at the app root**

In `DocumentScannerApp.swift`, wrap the existing `WindowGroup` content in a `Group` and
apply the modifier, so the installer is always present (it self-gates on the flag).
The body currently looks like:

```swift
    var body: some Scene {
        WindowGroup {
            if Self.isUITesting {
                // …branches…
            } else {
                // …branches…
            }
        }
    }
```

Make exactly two edits, leaving every branch body unchanged:

1. Change the opening `WindowGroup {` line to:

```swift
        WindowGroup {
            Group {
```

2. Change the line that closes the `if/else` chain — the lone `}` directly inside
   `WindowGroup` (the one just before the `}` that closes `WindowGroup`) to:

```swift
            }
            .touchIndicators()
```

Result:

```swift
    var body: some Scene {
        WindowGroup {
            Group {
                if Self.isUITesting {
                    // …branches (unchanged)…
                } else {
                    // …branches (unchanged)…
                }
            }
            .touchIndicators()
        }
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the full unit suite (no regressions)**

Run the test command. Expected: PASS, including `TouchIndicatorSettingsTests`.

- [ ] **Step 5: Commit**

```bash
git add DocumentScanner/DocumentScanner/Settings/SettingsView.swift \
        DocumentScanner/DocumentScanner/App/DocumentScannerApp.swift
git commit -m "feat(debug): Settings toggle + wire touch overlay at app root"
```

---

## Task 6: On-device verification

**Files:** none (manual verification)

- [ ] **Step 1: Run on a device or simulator**

Launch the app (DEBUG build). Open **Settings** → confirm a **Developer** section with a
**Touch Indicators** toggle (default **off**).

- [ ] **Step 2: Toggle on and verify behavior**

Turn **Touch Indicators** on. Across the app confirm:
  - A ~50pt purple circle appears at each tap and **follows drags/swipes**.
  - Multiple fingers each show their own circle.
  - The circle **scales up and fades** on lift.
  - The app remains **fully responsive** — taps, scrolls, and gestures all still work
    (the overlay never blocks input).

- [ ] **Step 3: Toggle off and verify teardown**

Turn the toggle **off** → indicators stop appearing immediately; app still responsive.

- [ ] **Step 4: (Optional) Confirm Release exclusion**

```bash
cd DocumentScanner && xcodebuild build \
  -scheme DocumentScanner -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED with no Developer section / overlay compiled in (the feature
is `#if DEBUG`; `.touchIndicators()` is a no-op).

---

## Done

After Task 6: a DEBUG-only touch-indicator overlay, toggled from a persisted Settings
switch (default off), draws a fading circle at every touch app-wide without interfering
with input — ready to record the App Preview (and future re-shoots). The feature
compiles to nothing in Release. Next step outside this plan: use it while shooting the
App Preview per `docs/superpowers/plans/2026-06-10-app-preview.md`.
