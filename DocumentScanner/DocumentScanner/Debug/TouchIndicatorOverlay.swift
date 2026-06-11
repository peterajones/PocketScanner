import SwiftUI
import UIKit

#if DEBUG

/// Storage key + default for the DEBUG-only touch-indicator overlay used when
/// recording App Preview / demo videos. Default is OFF so it never shows unless
/// explicitly enabled in Settings.
enum TouchIndicatorSettings {
    static let key = "touchIndicatorsEnabled"
    static let defaultEnabled = false
}

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
