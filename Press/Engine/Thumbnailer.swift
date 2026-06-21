import UIKit
import ImageIO

/// Decoding helpers that always apply orientation, so downstream pixels are
/// upright and we can safely normalise metadata.
enum Thumbnailer {

    /// A full- or reduced-resolution CGImage with EXIF orientation baked in.
    static func orientedImage(from imgSource: CGImageSource, maxPixel: CGFloat) -> CGImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(max(1, maxPixel.rounded())),
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(imgSource, 0, opts as CFDictionary)
    }

    /// A UIImage preview for a file on disk.
    static func thumbnail(for url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = orientedImage(from: src, maxPixel: maxPixel) else { return nil }
        return UIImage(cgImage: cg)
    }
}
