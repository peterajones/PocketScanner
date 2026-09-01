import CoreGraphics
import Foundation

/// The physical page size a scan is written to. Preset-style; no custom dimensions.
///
/// This exists because a camera cannot know how big the paper was. Before this type,
/// a page's MediaBox was the image's pixel dimensions treated as points — so a typical
/// scan produced a page around 29 × 39 INCHES rather than 8.5 × 11, and would not line
/// up beside a normal PDF.
///
/// Page size and image resolution are independent: the image is drawn onto the page at
/// whatever pixel dimensions it has, which simply determines the effective DPI. A
/// 2100px-wide image on an 8.5" page is a 247 DPI scan.
enum PaperSize: String, CaseIterable, Identifiable {

    /// Keep the proportions the scanner detected; only normalise the scale.
    case auto
    case usLetter
    case a4

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:      return String(localized: "Auto", comment: "Scan page size: keep the proportions the scanner detected")
        case .usLetter:  return String(localized: "US Letter", comment: "Scan page size")
        case .a4:        return String(localized: "A4", comment: "Scan page size")
        }
    }

    /// Long edge used by `.auto`, in points. 792pt = 11in, so a well-cropped
    /// Letter-shaped scan lands within a percent or two of a true Letter page.
    static let autoLongEdge: CGFloat = 792

    /// Portrait dimensions in points. 72pt = 1 inch.
    private var portraitSize: CGSize? {
        switch self {
        case .auto: return nil
        case .usLetter: return CGSize(width: 612, height: 792)   // 8.5 × 11 in
        case .a4:       return CGSize(width: 595, height: 842)   // 210 × 297 mm
        }
    }

    /// The page size in points for a scan whose image is `imageSize` pixels.
    ///
    /// For the fixed sizes the result is that paper's dimensions, oriented to match the
    /// scan — the image is fitted and centred within it at draw time, so a scan whose
    /// proportions differ gets margins rather than distortion.
    func pageSize(forImage imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return portraitSize ?? CGSize(width: Self.autoLongEdge, height: Self.autoLongEdge)
        }
        let isLandscape = imageSize.width > imageSize.height

        guard let portrait = portraitSize else {
            // .auto — preserve the aspect exactly, normalise the long edge.
            let scale = Self.autoLongEdge / max(imageSize.width, imageSize.height)
            return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        }
        return isLandscape ? CGSize(width: portrait.height, height: portrait.width) : portrait
    }

    /// A resolver suitable for `PDFAssembler.assemble(pages:createdAt:pageSize:)`.
    var resolver: (CGSize) -> CGSize {
        { self.pageSize(forImage: $0) }
    }
}
