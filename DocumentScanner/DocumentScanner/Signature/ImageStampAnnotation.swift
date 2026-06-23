import PDFKit
import UIKit

/// A stamp annotation that draws a (signature) image. The image is drawn in the
/// override and PDFKit bakes the result into the saved PDF's appearance stream,
/// so it persists and renders across a save→reload (verified by
/// `SignatureAnnotationPersistenceTests`). Tagged so the viewer's tap handler
/// recognizes it for move/remove.
final class ImageStampAnnotation: PDFAnnotation {
    private let image: UIImage

    init(image: UIImage, bounds: CGRect, userName: String) {
        self.image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
        self.userName = userName
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        // NOTE: do NOT call super.draw() — for a `.stamp` with no appearance
        // stream PDFKit paints a default placeholder (a bordered box with an X
        // through it). We draw only our own image.
        guard let cg = image.cgImage else { return }
        context.saveGState()
        context.draw(cg, in: bounds)
        context.restoreGState()
    }
}
