import SwiftUI
import UIKit

struct CaptureSheet: UIViewControllerRepresentable {
    let presenter: DocumentScannerPresenting
    let onFinish: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        presenter.makeViewController(onFinish: onFinish, onCancel: onCancel)
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}
