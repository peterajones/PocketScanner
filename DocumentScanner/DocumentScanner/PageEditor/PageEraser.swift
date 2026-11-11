import UIKit

/// Paints rectangles out of a page image in the paper's own colour.
///
/// Erasing is permanent: the pixels are replaced in the image, so once the page is
/// re-assembled and OCR'd the erased content is gone from the PDF and from search.
/// Rects are in the image's coordinate space (1 pt = 1 px, origin top-left).
enum PageEraser {

    /// Width of the strip just outside a rect that the paper colour is sampled from.
    static let bandWidth: CGFloat = 6

    /// The paper colour around `rect`: the per-channel median of the pixels in a band
    /// `bandWidth` wide outside it, clipped to the image. The median ignores print or
    /// handwriting that crosses part of the band. With no band pixels at all (the rect
    /// covers the image), white.
    static func paperColor(around rect: CGRect, in image: UIImage) -> UIColor {
        guard let pixels = Pixels(image) else { return .white }
        return pixels.median(around: rect)
    }

    /// `image` with each rect filled in the paper colour sampled around it. Each sample
    /// comes from the ORIGINAL image, so one fill never colours the next. Rects are
    /// clipped to the image; with nothing to erase, `image` itself is returned.
    static func erase(_ rects: [CGRect], in image: UIImage) -> UIImage {
        let bounds = CGRect(origin: .zero, size: image.size)
        let clipped = rects.map { $0.standardized.intersection(bounds) }.filter { !$0.isEmpty }
        guard !clipped.isEmpty, let pixels = Pixels(image) else { return image }

        // Fill whole pixels: a box edge on a fractional pixel would blend, leaving a
        // faint line of whatever it cut through.
        let all = rects.map { $0.standardized.integral }.filter { !$0.intersection(bounds).isEmpty }
        // A box wholly inside another adds nothing and has no band of its own to sample.
        let boxes = all.enumerated().filter { i, box in
            !all.enumerated().contains { j, other in
                j != i && other.contains(box) && (other != box || j < i)
            }
        }.map(\.element)
        // Sample each box's band, skipping pixels under the OTHER boxes: that ink is
        // being erased too, so it must not colour this fill.
        let fills = boxes.indices.map { i in
            (rect: boxes[i].intersection(bounds),
             colour: pixels.median(around: boxes[i],
                                   excluding: boxes.indices.filter { $0 != i }.map { boxes[$0] }))
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { ctx in
            image.draw(in: bounds)
            for fill in fills {
                fill.colour.setFill()
                ctx.fill(fill.rect)
            }
        }
    }
}

/// A scale-1 RGBA8 copy of an image, read once per erase.
private struct Pixels {
    let width: Int
    let height: Int
    let data: [UInt8]

    init?(_ image: UIImage) {
        let width = Int(image.size.width.rounded())
        let height = Int(image.size.height.rounded())
        guard width > 0, height > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                return false
            }
            // Flip to UIKit's top-left origin so row 0 of the buffer is the top of the image.
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: 1, y: -1)
            UIGraphicsPushContext(ctx)
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            UIGraphicsPopContext()
            return true
        }
        guard drawn else { return nil }
        self.width = width
        self.height = height
        data = buffer
    }

    func median(around rect: CGRect, excluding others: [CGRect] = []) -> UIColor {
        let r = rect.standardized
        let outer = r.insetBy(dx: -PageEraser.bandWidth, dy: -PageEraser.bandWidth)
        let x0 = max(0, Int(outer.minX.rounded(.down))), x1 = min(width, Int(outer.maxX.rounded(.up)))
        let y0 = max(0, Int(outer.minY.rounded(.down))), y1 = min(height, Int(outer.maxY.rounded(.up)))
        guard x0 < x1, y0 < y1 else { return .white }

        var reds: [UInt8] = [], greens: [UInt8] = [], blues: [UInt8] = []
        for y in y0..<y1 {
            for x in x0..<x1 {
                // Skip pixels inside the rect: only the band around it counts.
                if CGFloat(x) + 0.5 > r.minX, CGFloat(x) + 0.5 < r.maxX,
                   CGFloat(y) + 0.5 > r.minY, CGFloat(y) + 0.5 < r.maxY { continue }
                let centre = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                if others.contains(where: { $0.contains(centre) }) { continue }
                let i = (y * width + x) * 4
                reds.append(data[i]); greens.append(data[i + 1]); blues.append(data[i + 2])
            }
        }
        guard !reds.isEmpty else { return .white }
        func median(_ values: [UInt8]) -> CGFloat { CGFloat(values.sorted()[values.count / 2]) / 255 }
        return UIColor(red: median(reds), green: median(greens), blue: median(blues), alpha: 1)
    }
}
