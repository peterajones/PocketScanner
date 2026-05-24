import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Visual filter applied to a page image in the editor. Preset-style;
/// no continuous sliders.
enum ImageFilter: String, CaseIterable, Identifiable {
    case none, greyscale, blackAndWhite, photo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Color"
        case .greyscale: return "Greyscale"
        case .blackAndWhite: return "B&W"
        case .photo: return "Photo"
        }
    }
}

struct ImageFilterEngine {

    private let context = CIContext()

    /// Apply `filter` to `source`. Returns the filtered UIImage or nil if
    /// the source has no cgImage.
    func apply(_ filter: ImageFilter, to source: UIImage) -> UIImage? {
        guard filter != .none else { return source }
        guard let cgImage = source.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        guard let output = filteredImage(filter, input: ciImage),
              let outCG = context.createCGImage(output, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: outCG, scale: source.scale, orientation: source.imageOrientation)
    }

    private func filteredImage(_ filter: ImageFilter, input: CIImage) -> CIImage? {
        switch filter {
        case .none:
            return input
        case .greyscale:
            let f = CIFilter.colorControls()
            f.inputImage = input
            f.saturation = 0
            return f.outputImage
        case .blackAndWhite:
            // CIPhotoEffectNoir is Apple's high-contrast B&W preset —
            // cleaner than rolling our own monochrome + contrast bump.
            let f = CIFilter.photoEffectNoir()
            f.inputImage = input
            return f.outputImage
        case .photo:
            // Punch up contrast + saturation for photos / glossy pages.
            let f = CIFilter.colorControls()
            f.inputImage = input
            f.saturation = 1.2
            f.contrast = 1.15
            return f.outputImage
        }
    }
}
