import UIKit
import Vision
import CoreImage

enum CutoutError: LocalizedError {
    case noSubject
    case renderFailed
    var errorDescription: String? {
        switch self {
        case .noSubject:    return "No clear subject was found to lift from the background."
        case .renderFailed: return "The cut-out couldn't be rendered."
        }
    }
}

/// Lifts the foreground subject from an image entirely on-device using Vision's
/// foreground instance mask, returning an RGBA image with a transparent ground.
enum BackgroundRemover {

    private static let ciContext = CIContext()

    static func cutout(_ cg: CGImage) throws -> CGImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else { throw CutoutError.noSubject }

        let masked = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true)

        let ciImage = CIImage(cvPixelBuffer: masked)
        guard let out = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw CutoutError.renderFailed
        }
        return out
    }

    /// Convenience: cut out and write a transparent PNG, returning a result.
    static func cutoutToPNG(_ source: SourceImage) throws -> ConversionResult {
        guard let imgSource = CGImageSourceCreateWithURL(source.url as CFURL, nil),
              let full = Thumbnailer.orientedImage(
                from: imgSource,
                maxPixel: max(source.pixelSize.width, source.pixelSize.height)) else {
            throw ConversionError.decodeFailed
        }
        let cut = try cutout(full)

        let png = FormatCatalog.describe(uti: "public.png")!
        let outURL = TempFiles.outputURL(baseName: source.displayName + "-cutout", ext: png.ext)
        try ConversionEngine.writePNG(cut, to: outURL)

        let thumb = Thumbnailer.thumbnail(for: outURL, maxPixel: 600) ?? UIImage(cgImage: cut)
        return ConversionResult(url: outURL, format: png,
                                originalBytes: source.byteSize,
                                outputBytes: TempFiles.byteSize(of: outURL),
                                thumbnail: thumb, sourceName: source.displayName)
    }
}
