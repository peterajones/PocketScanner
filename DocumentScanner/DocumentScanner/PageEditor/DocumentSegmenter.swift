@preconcurrency import Vision
import UIKit
import CoreGraphics

enum DocumentSegmenterError: Error {
    case invalidImage
}

struct DocumentSegmenter {

    /// Detect document edges in `image`. Returns the corner quad in image-pixel
    /// coordinates (top-left origin), or `nil` if no document is found.
    ///
    /// Uses VNDetectDocumentSegmentationRequest which is the same underlying
    /// detection VisionKit's scanner uses, but exposed so we can re-run it on
    /// an already-captured image.
    func detect(in image: UIImage) async throws -> Quad? {
        guard let cgImage = image.cgImage else { throw DocumentSegmenterError.invalidImage }
        let size = CGSize(width: cgImage.width, height: cgImage.height)

        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false
            func tryResume(_ result: Result<Quad?, Error>) {
                lock.lock(); defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(with: result)
            }

            let request = VNDetectDocumentSegmentationRequest { request, error in
                if let error = error { tryResume(.failure(error)); return }
                guard let observations = request.results as? [VNRectangleObservation],
                      let observation = observations.first else {
                    tryResume(.success(nil))
                    return
                }
                // Vision's document segmenter returns something for nearly any
                // input; require a meaningful confidence to count as a detection.
                guard observation.confidence >= 0.5 else {
                    tryResume(.success(nil))
                    return
                }
                tryResume(.success(Self.quad(from: observation, in: size)))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { tryResume(.failure(error)) }
            }
        }
    }

    /// Convert a VNRectangleObservation (normalized 0–1 with origin bottom-left)
    /// into our image-pixel Quad (origin top-left).
    private static func quad(from observation: VNRectangleObservation, in size: CGSize) -> Quad {
        func denormalize(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
        }
        return Quad(
            topLeft: denormalize(observation.topLeft),
            topRight: denormalize(observation.topRight),
            bottomRight: denormalize(observation.bottomRight),
            bottomLeft: denormalize(observation.bottomLeft)
        )
    }
}
