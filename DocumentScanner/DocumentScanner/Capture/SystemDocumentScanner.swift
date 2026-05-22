import UIKit
import VisionKit

struct SystemDocumentScanner: DocumentScannerPresenting {
    func makeViewController(
        onFinish: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void
    ) -> UIViewController {
        let vc = VNDocumentCameraViewController()
        let coordinator = Coordinator(onFinish: onFinish, onCancel: onCancel)
        vc.delegate = coordinator
        // Keep coordinator alive for the lifetime of the controller.
        objc_setAssociatedObject(vc, &Coordinator.key, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return vc
    }

    private final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        static var key: UInt8 = 0
        let onFinish: ([UIImage]) -> Void
        let onCancel: () -> Void
        init(onFinish: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }
        func documentCameraViewController(_ vc: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
            onFinish(images)
        }
        func documentCameraViewControllerDidCancel(_ vc: VNDocumentCameraViewController) {
            onCancel()
        }
        func documentCameraViewController(_ vc: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancel() // Treat error as cancellation for Plan 1; a later plan can surface it.
        }
    }
}
