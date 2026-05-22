import UIKit

/// Abstraction over VisionKit's document scanner so future UI tests can inject
/// fixture pages without opening the real camera. Only the system implementation
/// exists in Plan 1; a stub lands in Plan 5 (UI tests).
protocol DocumentScannerPresenting {
    func makeViewController(
        onFinish: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void
    ) -> UIViewController
}
