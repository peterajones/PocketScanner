import UIKit

/// Image builders and a pixel reader shared by the unit tests.
extension UIImage {
    static func fromColor(_ color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    static func renderingText(_ text: String, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 96),
            .foregroundColor: UIColor.black
        ]
        (text as NSString).draw(at: CGPoint(x: 20, y: 40), withAttributes: attrs)
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    /// One line of 64pt system text per entry, top to bottom.
    static func renderingLines(_ lines: [String], size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 64),
            .foregroundColor: UIColor.black
        ]
        for (i, line) in lines.enumerated() {
            (line as NSString).draw(at: CGPoint(x: 20, y: 30 + CGFloat(i) * 120), withAttributes: attrs)
        }
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    /// The RGB value of one pixel, 0–255, read by drawing the image into a 1×1 RGBA8
    /// context offset so that pixel lands at the origin. y is top-down, like UIKit.
    func rgb(atX x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
        guard let cg = cgImage else { return (-1, -1, -1) }
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // CG's origin is bottom-left: shift so pixel (x, y) from the top lands at (0, 0).
        ctx.draw(cg, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))
        return (Int(px[0]), Int(px[1]), Int(px[2]))
    }
}
