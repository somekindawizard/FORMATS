import SwiftData
import Foundation

/// Permanent deletion of a Redwood document reclaims everything it owns — the
/// SwiftData row, its version-history snapshots, its Apple Pencil drawing, its
/// per-note ink prefs, and any photos embedded in its body. The delete paths
/// used to drop only the drawing, leaking snapshots, ink prefs, and photo files
/// forever.
enum RWCleanup {

    /// Photo filenames referenced in a body as `fern://<name>` tokens.
    private static func photoNames(in body: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "fern://([^)\\s\"']+)") else { return [] }
        let ns = body as NSString
        return regex.matches(in: body, range: NSRange(location: 0, length: ns.length)).compactMap {
            $0.numberOfRanges > 1 ? ns.substring(with: $0.range(at: 1)) : nil
        }
    }

    /// Purge one document's off-model assets (files + prefs) — NOT the row.
    static func purgeAssets(_ doc: RWDocument) {
        DrawingStore.delete(doc.id)
        InkPrefsStore.remove(doc.id)
        for name in photoNames(in: doc.body) { PhotoStore.delete(name) }
    }

    /// Delete a document's snapshot rows.
    static func deleteSnapshots(_ context: ModelContext, documentID: UUID) {
        if let snaps = try? context.fetch(FetchDescriptor<RWSnapshot>(
            predicate: #Predicate<RWSnapshot> { $0.documentID == documentID })) {
            for s in snaps { context.delete(s) }
        }
    }

    /// Permanently delete a single node: assets, snapshots, then the row.
    /// Caller handles recursion into children and the final `save()`.
    static func purge(_ context: ModelContext, _ doc: RWDocument) {
        purgeAssets(doc)
        deleteSnapshots(context, documentID: doc.id)
        context.delete(doc)
    }
}
