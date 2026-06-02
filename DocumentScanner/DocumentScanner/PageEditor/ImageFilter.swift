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

    /// Color-controls parameters (saturation, contrast, brightness)
    /// or nil for the identity / pass-through case.
    var colorControls: (saturation: Float, contrast: Float, brightness: Float)? {
        switch self {
        case .none:          return nil
        case .greyscale:     return (saturation: 0,   contrast: 1.3, brightness: 0)
        case .blackAndWhite: return (saturation: 0,   contrast: 1.8, brightness: 0.15)
        case .photo:         return (saturation: 1.5, contrast: 1.3, brightness: 0)
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
        guard let params = filter.colorControls else { return input }
        let f = CIFilter.colorControls()
        f.inputImage = input
        f.saturation = params.saturation
        f.contrast = params.contrast
        f.brightness = params.brightness
        return f.outputImage
    }
}
