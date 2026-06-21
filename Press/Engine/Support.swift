import Foundation
import UIKit

/// Byte / dimension formatting used throughout the UI.
enum Format {
    static func bytes(_ count: Int) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f.string(fromByteCount: Int64(count))
    }

    static func dimensions(_ size: CGSize) -> String {
        "\(Int(size.width.rounded())) × \(Int(size.height.rounded()))"
    }

    /// "62% smaller" / "18% larger" / "same size".
    static func delta(_ fraction: Double) -> String {
        let pct = Int((abs(fraction) * 100).rounded())
        if pct == 0 { return "same size" }
        return fraction < 0 ? "\(pct)% smaller" : "\(pct)% larger"
    }
}

/// Staging for picked inputs and produced outputs in the app's temp area.
enum TempFiles {
    static let root: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Press", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var inputs: URL { sub("Inputs") }
    static var outputs: URL { sub("Outputs") }

    private static func sub(_ name: String) -> URL {
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A unique, human-readable output URL: "Sunset.heic", "Sunset-1.heic"…
    static func outputURL(baseName: String, ext: String) -> URL {
        let base = baseName.isEmpty ? "Image" : baseName
        var candidate = outputs.appendingPathComponent("\(base).\(ext)")
        var n = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputs.appendingPathComponent("\(base)-\(n).\(ext)")
            n += 1
        }
        return candidate
    }

    static func byteSize(of url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    static func clearOutputs() {
        try? FileManager.default.removeItem(at: outputs)
    }
}
