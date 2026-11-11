import UIKit

/// The page editor's image steps in one place: perspective-correct → rotate → erase →
/// filter. The Erase-mode preview and Apply both use it, so what you draw boxes on is
/// exactly what gets erased and saved.
struct PageEditPipeline {
    var corrector = PerspectiveCorrector()
    var filterEngine = ImageFilterEngine()

    /// Corrected then rotated: the space erase rects live in.
    func straightened(_ pageImage: UIImage, quad: Quad, quarterTurns: Int) -> UIImage? {
        guard let corrected = corrector.correct(pageImage, quad: quad) else { return nil }
        return PageImageRenderer.rotated(corrected, quarterTurns: quarterTurns)
    }

    /// The finished page image. Erasing comes before the filter, so the fill is sampled
    /// from unfiltered paper and then filtered along with it. A filter failure falls
    /// back to the unfiltered image, as the editor always has.
    func render(_ pageImage: UIImage, quad: Quad, quarterTurns: Int,
                eraseRects: [CGRect], filter: ImageFilter) -> UIImage? {
        guard let straight = straightened(pageImage, quad: quad, quarterTurns: quarterTurns) else {
            return nil
        }
        let erased = PageEraser.erase(eraseRects, in: straight)
        return filterEngine.apply(filter, to: erased) ?? erased
    }
}
