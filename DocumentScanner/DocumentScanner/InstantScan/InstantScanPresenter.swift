import SwiftUI
import UIKit

/// Runs an instant scan on top of whatever the app is showing (lock screen, an open
/// sheet): camera, then an opaque "Saving…" screen while `SilentScanSaver` works.
/// Everything is presented through UIKit so it sits above SwiftUI sheets without
/// touching the navigation path or dismissing the user's unsaved work.
@MainActor
struct InstantScanPresenter {
    let scanner: DocumentScannerPresenting
    let saver: SilentScanSaver
    let coordinator: InstantScanCoordinator

    /// The key window's root view controller, where instant scan presents from.
    static func keyWindowRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap(\.keyWindow)
            .first?.rootViewController
    }

    /// Follows `presentedViewController` to the end of the chain, stopping before any
    /// controller that is already being dismissed (it can't host a new presentation).
    static func topMost(from root: UIViewController) -> UIViewController {
        var top = root
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }

    func start(from root: UIViewController) async {
        guard coordinator.beginCapture() else { return }

        if await CameraPermission.request() == .denied {
            presentCameraDenied(from: root)
            return
        }

        let box = WeakBox()
        let camera = scanner.makeViewController(
            onFinish: { images in
                Task { @MainActor in
                    self.finishCapture(images: images, root: root)
                }
            },
            onCancel: {
                Task { @MainActor in
                    // Dismiss through the camera's own presenter, never whatever is on
                    // top now, so a user's sheet can't be dismissed by mistake.
                    box.controller?.presentingViewController?.dismiss(animated: true)
                    self.coordinator.cancel()
                }
            }
        )
        box.controller = camera
        camera.modalPresentationStyle = .fullScreen
        present(camera, from: root)
    }

    // MARK: - Private

    /// Presents on top of everything. UIKit silently refuses a presentation while
    /// another transition is in progress; if that happened, cancel the scan on the
    /// next main-actor turn rather than leave the coordinator capturing forever.
    private func present(_ controller: UIViewController, from root: UIViewController) {
        Self.topMost(from: root).present(controller, animated: true)
        Task { @MainActor in
            if controller.presentingViewController == nil {
                coordinator.cancel()
            }
        }
    }

    private func presentCameraDenied(from root: UIViewController) {
        let box = WeakBox()
        let denied = UIHostingController(rootView: CameraDeniedView(onDismiss: {
            box.controller?.dismiss(animated: true)
            coordinator.cancel()
        }))
        box.controller = denied
        denied.modalPresentationStyle = .fullScreen
        present(denied, from: root)
    }

    /// Presents Saving on top of the camera (no animation) so whatever is behind never
    /// shows through, then saves. The camera and Saving go away together afterwards.
    private func finishCapture(images: [UIImage], root: UIViewController) {
        coordinator.beginSaving(images: images)
        let camera = Self.topMost(from: root)
        let host = camera.presentingViewController ?? root
        let saving = UIHostingController(rootView: SavingView())
        saving.modalPresentationStyle = .fullScreen
        camera.present(saving, animated: false)
        runSave(images: images, host: host)
    }

    private func runSave(images: [UIImage], host: UIViewController) {
        let defaults = UserDefaults.standard
        let filter = ImageFilter(rawValue: defaults.string(forKey: "defaultScanFilter") ?? "") ?? .none
        let paperSize = PaperSize(rawValue: defaults.string(forKey: "scanPaperSize") ?? "") ?? .auto

        Task { @MainActor in
            do {
                let url = try await saver.save(images: images, filter: filter, paperSize: paperSize)
                coordinator.saveSucceeded(url: url)
                host.dismiss(animated: false)
            } catch {
                coordinator.saveFailed()
                presentFailure(error, host: host)
            }
        }
    }

    /// A UIKit alert over the Saving screen: the SwiftUI root alert can't appear while
    /// the user has a sheet open, and Saving stays up so nothing behind it is exposed.
    private func presentFailure(_ error: Error, host: UIViewController) {
        let alert = UIAlertController(
            title: String(localized: "Couldn't save"),
            message: error.localizedDescription,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Retry"), style: .default) { _ in
            let images = coordinator.capturedImages
            coordinator.beginSaving(images: images)
            runSave(images: images, host: host)
        })
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { _ in
            host.dismiss(animated: false)
            coordinator.cancel()
        })
        Self.topMost(from: host).present(alert, animated: true)
    }

    private final class WeakBox {
        weak var controller: UIViewController?
    }
}
