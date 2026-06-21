import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The known universe of output formats, plus runtime resolution of which
/// ones this device can actually encode.
///
/// Design note (2026): Apple's ImageIO natively *encodes* JPEG, PNG, TIFF,
/// GIF, BMP, HEIC/HEIF and AVIF, and natively *decodes* those plus WebP,
/// JPEG XL and most camera RAW. WebP/JPEG-XL *encoding* is not guaranteed,
/// so rather than hard-code assumptions we ask the system what it can write
/// via `CGImageDestinationCopyTypeIdentifiers()` and surface exactly that.
/// PDF is always offered because it is produced through PDFKit, not ImageIO.
enum FormatCatalog {

    /// Editorial metadata for every format we know how to describe, keyed by UTI.
    static let known: [ImageFormat] = [
        ImageFormat(
            uti: "public.heic", name: "HEIC", ext: "heic",
            blurb: "Apple's modern default. HEVC-compressed stills, roughly half the size of JPEG at the same quality.",
            useCase: "Everyday photos kept on-device",
            family: .raster, lossy: true, supportsAlpha: true, supportsHDR: true,
            supportsAnimation: false, supportsWideGamut: true),

        ImageFormat(
            uti: "public.avif", name: "AVIF", ext: "avif",
            blurb: "AV1-based and royalty-free. The best general-purpose compression in 2026 — smaller than HEIC with HDR and wide gamut.",
            useCase: "Smallest files for sharing & web",
            family: .raster, lossy: true, supportsAlpha: true, supportsHDR: true,
            supportsAnimation: true, supportsWideGamut: true),

        ImageFormat(
            uti: "public.jpeg", name: "JPEG", ext: "jpg",
            blurb: "The universal standard. Opens absolutely everywhere; no transparency.",
            useCase: "Maximum compatibility",
            family: .raster, lossy: true, supportsAlpha: false, supportsHDR: true,
            supportsAnimation: false, supportsWideGamut: true),

        ImageFormat(
            uti: "public.png", name: "PNG", ext: "png",
            blurb: "Lossless and lossless-transparent. The safe choice for graphics, screenshots and cut-outs.",
            useCase: "Crisp graphics with transparency",
            family: .raster, lossy: false, supportsAlpha: true, supportsHDR: false,
            supportsAnimation: false, supportsWideGamut: true),

        ImageFormat(
            uti: "org.webmproject.webp", name: "WebP", ext: "webp",
            blurb: "Google's web format. Smaller than PNG/JPEG with transparency and animation.",
            useCase: "Web delivery with broad support",
            family: .raster, lossy: true, supportsAlpha: true, supportsHDR: false,
            supportsAnimation: true, supportsWideGamut: false),

        ImageFormat(
            uti: "public.jpeg-xl", name: "JPEG XL", ext: "jxl",
            blurb: "The format built for stills. Best-in-class quality, preserves grain and texture, with a lossless path from legacy JPEG.",
            useCase: "Archival & professional photography",
            family: .raster, lossy: true, supportsAlpha: true, supportsHDR: true,
            supportsAnimation: false, supportsWideGamut: true),

        ImageFormat(
            uti: "public.tiff", name: "TIFF", ext: "tiff",
            blurb: "Lossless, high bit-depth. The print and editing interchange standard.",
            useCase: "Editing & print interchange",
            family: .raster, lossy: false, supportsAlpha: true, supportsHDR: false,
            supportsAnimation: false, supportsWideGamut: true),

        ImageFormat(
            uti: "com.compuserve.gif", name: "GIF", ext: "gif",
            blurb: "256 colours and simple animation. Charming, ancient, occasionally indispensable.",
            useCase: "Simple animations & memes",
            family: .raster, lossy: false, supportsAlpha: true, supportsHDR: false,
            supportsAnimation: true, supportsWideGamut: false),

        ImageFormat(
            uti: "com.microsoft.bmp", name: "BMP", ext: "bmp",
            blurb: "Uncompressed bitmap. Large but utterly literal.",
            useCase: "Legacy & raw bitmap needs",
            family: .raster, lossy: false, supportsAlpha: false, supportsHDR: false,
            supportsAnimation: false, supportsWideGamut: false),

        ImageFormat(
            uti: "public.heif", name: "HEIF", ext: "heif",
            blurb: "The container behind HEIC, here with broad codec support.",
            useCase: "Efficient stills, HEIC's sibling",
            family: .raster, lossy: true, supportsAlpha: true, supportsHDR: true,
            supportsAnimation: false, supportsWideGamut: true),

        ImageFormat(
            uti: "com.adobe.pdf", name: "PDF", ext: "pdf",
            blurb: "A document wrapper for one or many images — ideal for sending a set as a single file.",
            useCase: "Bundle images into one document",
            family: .document, lossy: false, supportsAlpha: false, supportsHDR: false,
            supportsAnimation: false, supportsWideGamut: true),
    ]

    /// UTIs the running OS reports it can encode via ImageIO.
    static let systemEncodableUTIs: Set<String> = {
        let ids = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return Set(ids.map { $0.lowercased() })
    }()

    /// Returns true if this device can produce the given format.
    static func canEncode(_ format: ImageFormat) -> Bool {
        if format.family == .document { return true }            // PDF via PDFKit
        return systemEncodableUTIs.contains(format.uti.lowercased())
    }

    /// The formats offered for output on this device, in editorial order.
    static var available: [ImageFormat] {
        known.filter { canEncode($0) }
    }

    /// Look up editorial metadata for an arbitrary UTI (used to label inputs).
    static func describe(uti: String) -> ImageFormat? {
        known.first { $0.uti.caseInsensitiveCompare(uti) == .orderedSame }
    }
}
