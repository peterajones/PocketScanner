import Vision
import UIKit

enum OCREngineError: Error {
    case invalidImage
}

struct OCREngine {

    /// Recognize text in the supplied image. Returns one string per
    /// `VNRecognizedTextObservation`'s top candidate, in Vision's natural reading order.
    func recognizeText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw OCREngineError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let strings = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: strings)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
