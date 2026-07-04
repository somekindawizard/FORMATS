import UIKit
import Vision

/// Recognizes handwriting/printing in an image via Vision, so a note's Apple
/// Pencil ink becomes searchable text. Best effort — returns "" on failure.
enum HandwritingOCR {
    static func recognize(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do { try handler.perform([request]) }
            catch { continuation.resume(returning: "") }
        }
    }
}
