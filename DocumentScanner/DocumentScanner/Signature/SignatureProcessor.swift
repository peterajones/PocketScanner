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
        // Normalize to `.up` first. `cgImage` below reads the raw pixel buffer and
        // drops `imageOrientation`; the document scanner always handed back upright
        // images, but UIImagePickerController tags a portrait capture `.right`, so
        // without this the ink would be processed sideways. Bake the rotation in.
        let upright = normalizedUp(scanned)
        let bw = filterEngine.apply(.blackAndWhite, to: upright) ?? upright
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
        return UIImage(cgImage: outCG, scale: upright.scale, orientation: .up)
    }

    /// Redraw `image` so its pixels are upright and `imageOrientation` is `.up`.
    /// `image.size` is already in display (oriented) coordinates and `draw(in:)`
    /// honors orientation, so the rendered result needs no metadata correction.
    private func normalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
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

        // Per-row ink counts.
        var rowInk = [Int](repeating: 0, count: h)
        for y in 0..<h {
            var c = 0
            for x in 0..<w where px[(y * w + x) * 4 + 3] > 40 { c += 1 }
            rowInk[y] = c
        }
        // Group inky rows into vertical bands, merging across small gaps (so a
        // signature's own internal whitespace doesn't split it), and keep the
        // band with the most ink. This drops a thin line separated from the
        // signature by a wide gap — e.g. a camera/refresh band artifact when
        // scanning a screen — without clipping the signature's own strokes.
        let maxGap = max(8, Int(Double(h) * 0.10))
        var bestStart = -1, bestEnd = -1, bestInk = -1
        var y = 0
        while y < h {
            guard rowInk[y] > 0 else { y += 1; continue }
            var end = y, gap = 0, total = 0, j = y
            while j < h {
                if rowInk[j] > 0 { end = j; total += rowInk[j]; gap = 0 }
                else { gap += 1; if gap > maxGap { break } }
                j += 1
            }
            if total > bestInk { bestInk = total; bestStart = y; bestEnd = end }
            y = j
        }
        guard bestStart >= 0 else { return nil }
        // Column extent within the chosen band.
        var minX = w, maxX = -1
        for yy in bestStart...bestEnd {
            for x in 0..<w where px[(yy * w + x) * 4 + 3] > 40 {
                if x < minX { minX = x }; if x > maxX { maxX = x }
            }
        }
        guard maxX >= minX else { return nil }
        let minY = bestStart, maxY = bestEnd
        // Pad evenly, then clamp the whole rect to the image extent in one step
        // (a per-edge min() clamp would silently halve the padding when ink sits
        // against an edge). CIImage origin is bottom-left, so flip the raster's
        // top-left y-range when forming the rect.
        let pad: CGFloat = 4
        let rect = CGRect(x: CGFloat(minX) - pad,
                          y: CGFloat(h - 1 - maxY) - pad,
                          width: CGFloat(maxX - minX) + 1 + pad * 2,
                          height: CGFloat(maxY - minY) + 1 + pad * 2)
        let clamped = rect.intersection(CGRect(x: 0, y: 0, width: w, height: h))
        return clamped.isEmpty ? nil : clamped
    }
}
