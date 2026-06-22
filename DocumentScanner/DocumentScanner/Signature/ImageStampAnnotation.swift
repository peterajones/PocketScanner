import PDFKit
import UIKit

/// A stamp annotation that draws a (signature) image. Draws at runtime via the
/// override; to survive a save→reload round-trip it must also carry a PDF
/// appearance stream, which `draw(with:in:)` alone does not create — Task 1's
/// spike verifies whether PDFKit persists this. Tagged so the viewer's
/// tap-to-delete recognizes it.
final class ImageStampAnnotation: PDFAnnotation {
    private let image: UIImage

    init(image: UIImage, bounds: CGRect, userName: String) {
        self.image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
        self.userName = userName
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        super.draw(with: box, in: context)
        guard let cg = image.cgImage else { return }
        context.saveGState()
        context.draw(cg, in: bounds)
        context.restoreGState()
    }
}
