import UIKit
import CoreImage

struct PerspectiveCorrector {

    /// Apply a perspective-correction transform to `source` using `quad`'s
    /// 4 corners as the new image rectangle. Returns nil if the transform
    /// cannot be applied (e.g., source has no cgImage).
    ///
    /// `quad` is in image pixel coordinates with origin top-left (y-down).
    /// Core Image uses origin bottom-left (y-up), so y values are flipped.
    func correct(_ source: UIImage, quad: Quad) -> UIImage? {
        guard let cgImage = source.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let h = ciImage.extent.height

        func flipped(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: h - p.y) }

        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: flipped(quad.topLeft)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: flipped(quad.topRight)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: flipped(quad.bottomRight)), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: flipped(quad.bottomLeft)), forKey: "inputBottomLeft")

        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let outCG = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: outCG, scale: 1, orientation: .up)
    }
}
