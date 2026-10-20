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
    let alertCenter: AlertCenter

    /// Follows `presentedViewController` to the end of the chain.
    static func topMost(from root: UIViewController) -> UIViewController {
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    func start(from root: UIViewController) async {
        guard coordinator.beginCapture() else { return }

        if await CameraPermission.request() == .denied {
            presentCameraDenied(from: root)
            return
        }

        let camera = scanner.makeViewController(
            onFinish: { images in
                Task { @MainActor in
                    self.finishCapture(images: images, root: root)
                }
            },
            onCancel: {
                Task { @MainActor in
                    Self.topMost(from: root).dismiss(animated: true)
                    self.coordinator.cancel()
                }
            }
        )
        camera.modalPresentationStyle = .fullScreen
        Self.topMost(from: root).present(camera, animated: true)
    }

    // MARK: - Private

    private func presentCameraDenied(from root: UIViewController) {
        let box = WeakBox()
        let denied = UIHostingController(rootView: CameraDeniedView(onDismiss: {
            box.controller?.dismiss(animated: true)
            coordinator.cancel()
        }))
        box.controller = denied
        denied.modalPresentationStyle = .fullScreen
        Self.topMost(from: root).present(denied, animated: true)
    }

    /// Swaps the camera for the Saving screen in one turn so the screen behind never
    /// shows through, then saves.
    private func finishCapture(images: [UIImage], root: UIViewController) {
        coordinator.beginSaving(images: images)
        let top = Self.topMost(from: root)
        let host = top.presentingViewController ?? root
        top.dismiss(animated: false) {
            self.runSave(images: images, root: host)
        }
    }

    private func runSave(images: [UIImage], root: UIViewController) {
        let saving = UIHostingController(rootView: SavingView())
        saving.modalPresentationStyle = .fullScreen
        Self.topMost(from: root).present(saving, animated: false)

        let defaults = UserDefaults.standard
        let filter = ImageFilter(rawValue: defaults.string(forKey: "defaultScanFilter") ?? "") ?? .none
        let paperSize = PaperSize(rawValue: defaults.string(forKey: "scanPaperSize") ?? "") ?? .auto

        Task { @MainActor in
            do {
                let url = try await saver.save(images: images, filter: filter, paperSize: paperSize)
                coordinator.saveSucceeded(url: url)
                saving.dismiss(animated: false)
            } catch {
                coordinator.saveFailed()
                saving.dismiss(animated: false) {
                    self.presentFailure(error, root: root)
                }
            }
        }
    }

    private func presentFailure(_ error: Error, root: UIViewController) {
        alertCenter.present(AppAlert(
            title: String(localized: "Couldn't save"),
            message: error.localizedDescription,
            primary: AppAlert.Action(title: String(localized: "Retry"), role: .default, handler: {
                let images = coordinator.capturedImages
                coordinator.beginSaving(images: images)
                runSave(images: images, root: root)
            }),
            secondary: AppAlert.Action(title: String(localized: "Cancel"), role: .cancel, handler: {
                coordinator.cancel()
            })
        ))
    }

    private final class WeakBox {
        weak var controller: UIViewController?
    }
}
