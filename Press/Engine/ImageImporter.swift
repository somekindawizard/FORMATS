import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Turns picked files and photo-library data into staged `SourceImage`s.
enum ImageImporter {

    /// Import by copying a (possibly security-scoped) file URL into temp storage.
    static func makeSource(copying url: URL) -> SourceImage? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        return makeSource(data: data, suggestedName: name.isEmpty ? "Image" : name)
    }

    /// Import from raw image data (the Photos picker path).
    static func makeSource(data: Data, suggestedName: String) -> SourceImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let uti = (CGImageSourceGetType(src) as String?) ?? UTType.image.identifier
        let ext = UTType(uti)?.preferredFilenameExtension ?? "img"

        let url = uniqueInputURL(name: suggestedName, ext: ext)
        guard (try? data.write(to: url)) != nil else { return nil }
        return probe(url: url, uti: uti, name: suggestedName)
    }

    // MARK: - Probing

    private static func probe(url: URL, uti: String, name: String) -> SourceImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumb = Thumbnailer.thumbnail(for: url, maxPixel: 700) else { return nil }

        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
        let w = (props[kCGImagePropertyPixelWidth] as? CGFloat) ?? thumb.size.width
        let h = (props[kCGImagePropertyPixelHeight] as? CGFloat) ?? thumb.size.height
        let orientation = (props[kCGImagePropertyOrientation] as? Int) ?? 1
        // Orientations 5–8 swap width/height when displayed.
        let displaySize = orientation >= 5 ? CGSize(width: h, height: w)
                                           : CGSize(width: w, height: h)

        return SourceImage(
            url: url,
            uti: uti,
            pixelSize: displaySize,
            byteSize: TempFiles.byteSize(of: url),
            hasGainMap: detectGainMap(src),
            thumbnail: thumb,
            displayName: name
        )
    }

    private static func detectGainMap(_ src: CGImageSource) -> Bool {
        CGImageSourceCopyAuxiliaryDataInfoAtIndex(
            src, 0, kCGImageAuxiliaryDataTypeHDRGainMap) != nil
    }

    private static func uniqueInputURL(name: String, ext: String) -> URL {
        var candidate = TempFiles.inputs.appendingPathComponent("\(name).\(ext)")
        var n = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = TempFiles.inputs.appendingPathComponent("\(name)-\(n).\(ext)")
            n += 1
        }
        return candidate
    }
}
