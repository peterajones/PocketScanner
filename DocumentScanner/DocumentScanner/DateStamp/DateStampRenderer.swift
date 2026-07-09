import UIKit

/// Renders a short string (a formatted date) to a transparent, black-text image.
/// Rendered at a large point size so the placed stamp stays crisp when the user
/// pinch-resizes it up (unlike a scanned signature, text degrades if rendered
/// small then scaled). The image is then placed exactly like a signature.
enum DateStampRenderer {
    private static let fontSize: CGFloat = 96
    private static let padding: CGFloat = 12

    static func image(for text: String) -> UIImage {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let str = text as NSString
        let textSize = str.size(withAttributes: attrs)
        let size = CGSize(width: ceil(textSize.width) + padding * 2,
                          height: ceil(textSize.height) + padding * 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false   // transparent background
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            str.draw(at: CGPoint(x: padding, y: padding), withAttributes: attrs)
        }
    }
}
