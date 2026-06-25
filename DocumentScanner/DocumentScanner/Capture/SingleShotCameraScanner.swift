import UIKit

/// Single-photo capture for signatures: wraps `UIImagePickerController(.camera)`
/// so "Add Signature" takes ONE photo (shutter → Use Photo) rather than the
/// multi-page document scanner's batch (which keeps auto-capturing until you tap
/// Done). Conforms to `DocumentScannerPresenting` so `SignatureCaptureView` uses
/// it unchanged — it just returns the one photo as `[image]`.
struct SingleShotCameraScanner: DocumentScannerPresenting {
    func makeViewController(
        onFinish: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void
    ) -> UIViewController {
        // No camera (e.g. simulator) — nothing to present; treat as a cancel.
        // Signature capture is device-only.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            DispatchQueue.main.async { onCancel() }
            return UIViewController()
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        // Restores a crop: after the shutter, the native Move & Scale screen lets
        // you zoom/position onto the signature before Use Photo (returns
        // `.editedImage`). The band-crop in SignatureProcessor tightens further.
        picker.allowsEditing = true
        let coordinator = Coordinator(onFinish: onFinish, onCancel: onCancel)
        picker.delegate = coordinator
        // Keep the coordinator alive for the controller's lifetime (same pattern
        // as SystemDocumentScanner).
        objc_setAssociatedObject(picker, &Coordinator.key, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return picker
    }

    private final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        static var key: UInt8 = 0
        let onFinish: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onFinish: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Prefer the cropped result from Move & Scale; fall back to the full
            // photo if editing produced nothing.
            if let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) {
                onFinish([image])
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
