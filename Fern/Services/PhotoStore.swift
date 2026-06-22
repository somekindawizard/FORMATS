import UIKit

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
    }
}
