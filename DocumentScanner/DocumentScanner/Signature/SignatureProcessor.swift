import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Turns a scanned signature (dark ink on light paper) into a tight transparent
/// cut-out: Black & White → key the paper to alpha → crop to the ink bounds.
/// Pure: same input → same output; no I/O. Returns nil when there's no ink.
struct SignatureProcessor {
    private let context = CIContext()
    private let filterEngine = ImageFilterEngine()

    func process(_ scanned: UIImage) -> UIImage? {
        let bw = filterEngine.apply(.blackAndWhite, to: scanned) ?? scanned
        guard let cg = bw.cgImage else { return nil }
        let input = CIImage(cgImage: cg)

        let inverted = input.applyingFilter("CIColorInvert")
        let masked = inverted.applyingFilter("CIMaskToAlpha")
        let blackInk = masked.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        ])

        guard let crop = inkBounds(of: blackInk), !crop.isEmpty else { return nil }
        guard let outCG = context.createCGImage(blackInk, from: crop) else { return nil }
        return UIImage(cgImage: outCG, scale: scanned.scale, orientation: .up)
    }

    private func inkBounds(of image: CIImage) -> CGRect? {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        let w = Int(extent.width), h = Int(extent.height)
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = context.createCGImage(image, from: extent) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                if px[(y * w + x) * 4 + 3] > 40 {
                    if x < minX { minX = x }; if x > maxX { maxX = x }
                    if y < minY { minY = y }; if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let pad = 4
        let rx = max(0, minX - pad)
        let ry = max(0, (h - 1 - maxY) - pad)
        let rw = min(w - rx, (maxX - minX) + 1 + pad * 2)
        let rh = min(h - ry, (maxY - minY) + 1 + pad * 2)
        return CGRect(x: rx, y: ry, width: rw, height: rh)
    }
}
