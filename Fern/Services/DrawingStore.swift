import PencilKit

/// Persists a note's Apple Pencil ink as a `PKDrawing` file in Documents/Drawings,
/// keyed by the entry id — same file-backed reasoning as photos (keeps the
/// SwiftData store small and the schema simple).
enum DrawingStore {
    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Drawings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func url(_ id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).drawing")
    }

    static func load(_ id: UUID) -> PKDrawing? {
        guard let data = try? Data(contentsOf: url(id)) else { return nil }
        return try? PKDrawing(data: data)
    }

    static func save(_ id: UUID, _ drawing: PKDrawing) {
        if drawing.strokes.isEmpty { delete(id); return }
        try? drawing.dataRepresentation().write(to: url(id))
    }

    static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(id))
    }

    static func exists(_ id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: url(id).path)
    }

    /// A render of the drawing sized for OCR — capped to ~3 megapixels. The
    /// old fixed 2x render of the full bounds could transiently allocate
    /// hundreds of MB on a long handwritten note (jetsam risk).
    static func ocrImage(_ drawing: PKDrawing) -> UIImage {
        let b = drawing.bounds
        let area = max(1, b.width * b.height)
        let scale = min(2, sqrt(3_000_000 / area))
        return drawing.image(from: b, scale: max(0.5, scale))
    }
}
