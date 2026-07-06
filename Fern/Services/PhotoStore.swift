import UIKit
import ImageIO

/// Stores entry photos as files in Documents/Photos and returns their
/// filenames (which live on `Entry.photoFileNames`). Keeping large image
/// blobs out of the SwiftData store keeps the database small and the schema
/// simple — and the files show up in the Files app (see Info.plist keys).
enum PhotoStore {

    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Save image data; returns the stored filename (or nil on failure).
    @discardableResult
    static func save(_ data: Data) -> String? {
        let name = UUID().uuidString + ".jpg"
        let url = directory.appendingPathComponent(name)
        do { try data.write(to: url); return name } catch { return nil }
    }

    static func load(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        thumbs.removeObject(forKey: name as NSString)
    }

    // MARK: thumbnails

    private static let thumbs = NSCache<NSString, UIImage>()

    /// A small, cached rendition for list rows. Decoding the full multi-MB
    /// photo for every visible 60pt row made library scrolling stutter;
    /// ImageIO decodes straight to thumbnail size without inflating the
    /// original.
    static func thumbnail(_ name: String, side: CGFloat = 60) -> UIImage? {
        guard !name.isEmpty else { return nil }
        if let hit = thumbs.object(forKey: name as NSString) { return hit }
        let url = directory.appendingPathComponent(name)
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: side * 3,   // 3x screens
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        else { return nil }
        let image = UIImage(cgImage: cg)
        thumbs.setObject(image, forKey: name as NSString)
        return image
    }
}
