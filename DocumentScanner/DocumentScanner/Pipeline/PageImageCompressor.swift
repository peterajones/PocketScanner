import UIKit

/// Downsamples a scanned page image and JPEG-encodes it, so `PDFAssembler` can
/// embed a compact page instead of the full-resolution lossless capture (~24×
/// smaller in practice). Pure + SwiftUI-free so the size logic is unit-tested.
enum PageImageCompressor {

    /// The size to render at: scaled so the longest edge is at most `maxLongEdge`
    /// points. Never upsamples (returns the source size when already within cap).
    static func downsampledSize(for size: CGSize, maxLongEdge: CGFloat) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxLongEdge, size.width > 0, size.height > 0 else { return size }
        let scale = maxLongEdge / longest
        return CGSize(width: (size.width * scale).rounded(),
                      height: (size.height * scale).rounded())
    }

    /// Bakes in orientation, downsamples to `maxLongEdge`, and JPEG-encodes at
    /// `quality`. Returns nil if encoding fails. `scale = 1` so the produced JPEG's
    /// pixel dimensions equal the point dimensions (matching how `PDFAssembler`
    /// derives the page mediaBox from pixel size).
    static func compressedJPEGData(from image: UIImage,
                                   maxLongEdge: CGFloat,
                                   quality: CGFloat) -> Data? {
        let target = downsampledSize(for: image.size, maxLongEdge: maxLongEdge)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
