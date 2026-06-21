import UIKit
import ImageIO
import PDFKit
import UniformTypeIdentifiers

enum ConversionError: LocalizedError {
    case cannotRead
    case unsupportedTarget(String)
    case cannotCreateDestination
    case decodeFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .cannotRead:               return "This image couldn't be read."
        case .unsupportedTarget(let n): return "\(n) can't be written on this device."
        case .cannotCreateDestination:  return "Couldn't prepare the output file."
        case .decodeFailed:             return "The image couldn't be decoded."
        case .writeFailed:              return "Writing the converted file failed."
        }
    }
}

/// Pure, synchronous conversion built on ImageIO (raster) and PDFKit (documents).
/// Run it off the main thread; `AppModel` wraps it in a task.
enum ConversionEngine {

    // Some newer ImageIO destination keys are referenced as string literals so
    // the project compiles cleanly across SDKs (their backing CFString values
    // equal the constant names on Apple platforms).
    private static let kPreserveGainMap = "kCGImageDestinationPreserveGainMap" as CFString

    static func convert(_ source: SourceImage,
                        to format: ImageFormat,
                        settings: ConversionSettings) throws -> ConversionResult {
        guard let imgSource = CGImageSourceCreateWithURL(source.url as CFURL, nil) else {
            throw ConversionError.cannotRead
        }
        let outURL = TempFiles.outputURL(baseName: source.displayName, ext: format.ext)

        if format.family == .document {
            try writePDF(from: imgSource, source: source, settings: settings, to: outURL)
        } else {
            try writeRaster(from: imgSource, source: source, format: format,
                            settings: settings, to: outURL)
        }

        let outBytes = TempFiles.byteSize(of: outURL)
        let thumb = Thumbnailer.thumbnail(for: outURL, maxPixel: 600) ?? source.thumbnail
        return ConversionResult(url: outURL, format: format,
                                originalBytes: source.byteSize, outputBytes: outBytes,
                                thumbnail: thumb, sourceName: source.displayName)
    }

    // MARK: - Raster

    private static func writeRaster(from imgSource: CGImageSource,
                                    source: SourceImage,
                                    format: ImageFormat,
                                    settings: ConversionSettings,
                                    to outURL: URL) throws {
        guard let type = format.type else { throw ConversionError.unsupportedTarget(format.name) }
        guard let dest = CGImageDestinationCreateWithURL(
            outURL as CFURL, type.identifier as CFString, 1, nil) else {
            throw ConversionError.cannotCreateDestination
        }

        let longest = max(source.pixelSize.width, source.pixelSize.height)
        let maxPixel = settings.resize.maxPixelSize(forLongest: longest)
        let needsRedraw = (maxPixel != nil) || !settings.preserveMetadata

        if needsRedraw {
            // Resizing or stripping: bake pixels (orientation applied) and
            // attach a properties dictionary we fully control.
            let target = maxPixel ?? longest
            guard let cg = Thumbnailer.orientedImage(from: imgSource, maxPixel: target) else {
                throw ConversionError.decodeFailed
            }
            var props = properties(from: imgSource, settings: settings, pixelsBaked: true)
            if format.lossy {
                props[kCGImageDestinationLossyCompressionQuality] = settings.quality
            }
            CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        } else {
            // Full-fidelity pass-through: keep metadata, colour and — where
            // supported — the HDR gain map (ISO 21496-1).
            var opts: [CFString: Any] = [:]
            if format.lossy {
                opts[kCGImageDestinationLossyCompressionQuality] = settings.quality
            }
            if settings.preserveHDR, format.supportsHDR, source.hasGainMap {
                opts[kPreserveGainMap] = true
            }
            CGImageDestinationAddImageFromSource(dest, imgSource, 0, opts as CFDictionary)
        }

        guard CGImageDestinationFinalize(dest) else { throw ConversionError.writeFailed }
    }

    /// Builds the destination properties, honouring the metadata setting and
    /// normalising orientation when the pixels have already been transformed.
    private static func properties(from imgSource: CGImageSource,
                                   settings: ConversionSettings,
                                   pixelsBaked: Bool) -> [CFString: Any] {
        let src = CGImageSourceCopyPropertiesAtIndex(imgSource, 0, nil) as? [CFString: Any] ?? [:]
        var out: [CFString: Any] = [:]

        if settings.preserveMetadata {
            out = src
        } else {
            // Privacy mode: drop EXIF / GPS / IPTC / TIFF maker notes, keep only
            // what's needed to render colour faithfully.
            for key in [kCGImagePropertyProfileName,
                        kCGImagePropertyDPIWidth,
                        kCGImagePropertyDPIHeight,
                        kCGImagePropertyDepth,
                        kCGImagePropertyColorModel] {
                if let v = src[key] { out[key] = v }
            }
        }

        if pixelsBaked {
            out[kCGImagePropertyOrientation] = 1
            if var tiff = out[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                tiff[kCGImagePropertyTIFFOrientation] = 1
                out[kCGImagePropertyTIFFDictionary] = tiff
            }
        }
        return out
    }

    // MARK: - PDF

    private static func writePDF(from imgSource: CGImageSource,
                                 source: SourceImage,
                                 settings: ConversionSettings,
                                 to outURL: URL) throws {
        let longest = max(source.pixelSize.width, source.pixelSize.height)
        let maxPixel = settings.resize.maxPixelSize(forLongest: longest) ?? longest
        guard let cg = Thumbnailer.orientedImage(from: imgSource, maxPixel: maxPixel) else {
            throw ConversionError.decodeFailed
        }
        try writePDF(images: [cg], to: outURL)
    }

    /// Writes a single CGImage as a lossless PNG (used by the cut-out tool).
    static func writePNG(_ image: CGImage, to outURL: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(
            outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ConversionError.cannotCreateDestination
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ConversionError.writeFailed }
    }

    /// Renders one image per page at its native pixel size (72 dpi page units).
    static func writePDF(images: [CGImage], to outURL: URL) throws {
        guard let first = images.first else { throw ConversionError.decodeFailed }
        var mediaBox = CGRect(x: 0, y: 0, width: first.width, height: first.height)
        guard let ctx = CGContext(outURL as CFURL, mediaBox: &mediaBox, nil) else {
            throw ConversionError.cannotCreateDestination
        }
        for image in images {
            var box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            let page = [kCGPDFContextMediaBox as String: NSData(
                bytes: &box, length: MemoryLayout<CGRect>.size)] as CFDictionary
            ctx.beginPDFPage(page)
            ctx.draw(image, in: box)
            ctx.endPDFPage()
        }
        ctx.closePDF()
    }
}
