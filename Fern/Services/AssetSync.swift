import SwiftData
import Foundation

/// Bridges the file-backed photo/drawing stores with the CloudKit-synced `Asset`
/// records, so binary content travels between devices:
/// - `record…` puts a file's bytes into the store (uploads via CloudKit).
/// - `materializeAll` writes any synced-in bytes back to local files.
/// - `backfill` seeds records for photos/drawings that existed before this.
enum AssetSync {

    // MARK: record (on the device that created the file)

    @MainActor
    static func recordPhoto(_ context: ModelContext, name: String, data: Data) {
        guard !exists(context, name: name) else { return }
        context.insert(Asset(name: name, kind: "photo", data: data))
        try? context.save()
    }

    @MainActor
    static func recordDrawing(_ context: ModelContext, entryID: UUID, data: Data) {
        let name = "\(entryID.uuidString).drawing"
        if let existing = fetch(context, name: name) {
            // Re-drawing after an erase resurrects a tombstoned record.
            let kindChanged = existing.kind != "drawing"
            if kindChanged { existing.kind = "drawing" }
            if existing.data != data { existing.data = data; try? context.save() }
            else if kindChanged { try? context.save() }
        } else {
            context.insert(Asset(name: name, kind: "drawing", data: data))
            try? context.save()
        }
    }

    // MARK: delete (tombstones)

    /// Deletion must propagate: rather than deleting the record (which other
    /// devices would just re-upload from their local file), we EMPTY its bytes
    /// and mark the `kind` with a ".deleted" suffix. The record syncs
    /// everywhere, and `materializeAll` removes the matching local file on
    /// each device. Without this, deleted photos and erased handwriting
    /// resurrected on every sync.
    ///
    /// The marker lives in `kind` (a tiny string) — NOT in the data — so that
    /// materializeAll can detect tombstones without touching `data`, which is
    /// `.externalStorage`: reading it faults the whole blob into memory
    /// (checking `data.isEmpty` per record loaded every photo in the library
    /// on every launch and jetsammed the app).
    @MainActor
    static func tombstone(_ context: ModelContext, name: String) {
        guard let existing = fetch(context, name: name),
              !existing.kind.hasSuffix(".deleted") else { return }
        existing.data = Data()
        existing.kind += ".deleted"
        try? context.save()
    }

    @MainActor
    static func tombstoneDrawing(_ context: ModelContext, entryID: UUID) {
        tombstone(context, name: "\(entryID.uuidString).drawing")
    }

    // MARK: background sync (never on the main thread — this ran at launch and
    // was hanging the main thread long enough to trip the watchdog)

    /// Run materialize + backfill on a detached background context, so the heavy
    /// asset fetch / file I/O never blocks launch or the UI.
    nonisolated static func sync(_ container: ModelContainer) {
        Task.detached(priority: .utility) {
            let context = ModelContext(container)
            materializeAll(context)
            backfill(context)
        }
    }

    // MARK: materialize (on the device that synced them in)

    /// Write any asset whose local file is missing; remove files whose asset
    /// was tombstoned on another device; collapse duplicate records (two
    /// devices backfilling the same name). Idempotent and cheap.
    ///
    /// CRITICAL: this must never read `asset.data` outside the rare
    /// missing-file branch. `data` is `.externalStorage`, so any access —
    /// even `.isEmpty` — faults the whole blob into memory; doing that per
    /// record loaded every photo in the library on every launch/foreground
    /// and jetsammed the app. Tombstones are detected from `kind` instead.
    static func materializeAll(_ context: ModelContext) {
        guard let assets = try? context.fetch(FetchDescriptor<Asset>()) else { return }
        // Dedup by name. A tombstone among duplicates means a deletion raced a
        // backfill — deletion wins. Otherwise duplicates carry identical bytes.
        var byName: [String: Asset] = [:]
        var removedDupes = false
        for asset in assets {
            if let kept = byName[asset.name] {
                let keptDead = kept.kind.hasSuffix(".deleted")
                let mineDead = asset.kind.hasSuffix(".deleted")
                if keptDead || mineDead {
                    let tomb = keptDead ? kept : asset
                    let other = keptDead ? asset : kept
                    context.delete(other)
                    byName[asset.name] = tomb
                } else {
                    context.delete(asset)
                }
                removedDupes = true
            } else {
                byName[asset.name] = asset
            }
        }
        if removedDupes { try? context.save() }

        for asset in byName.values {
            let dead = asset.kind.hasSuffix(".deleted")
            let baseKind = dead ? String(asset.kind.dropLast(".deleted".count)) : asset.kind
            let dir = baseKind == "drawing" ? DrawingStore.directory : PhotoStore.directory
            let url = dir.appendingPathComponent(asset.name)
            if dead {
                // Tombstone — a deletion propagating from another device.
                try? FileManager.default.removeItem(at: url)
            } else if !FileManager.default.fileExists(atPath: url.path) {
                // The only place the blob is faulted in — and only for files
                // that are genuinely missing locally. Pooled so consecutive
                // writes don't accumulate.
                autoreleasepool {
                    if !asset.data.isEmpty { try? asset.data.write(to: url) }
                }
            }
        }
    }

    // MARK: backfill (existing content from before assets synced)

    /// Create records for local photo/drawing files that don't have one yet, so
    /// pre-existing notes sync their images too.
    static func backfill(_ context: ModelContext) {
        guard let entries = try? context.fetch(FetchDescriptor<Entry>()) else { return }
        let known = Set((try? context.fetch(FetchDescriptor<Asset>()))?.map(\.name) ?? [])
        var inserted = false
        for entry in entries {
            for name in entry.photoFileNames where !known.contains(name) {
                let url = PhotoStore.directory.appendingPathComponent(name)
                if let data = try? Data(contentsOf: url) {
                    context.insert(Asset(name: name, kind: "photo", data: data))
                    inserted = true
                }
            }
            let dname = "\(entry.id.uuidString).drawing"
            if !known.contains(dname) {
                let durl = DrawingStore.directory.appendingPathComponent(dname)
                if FileManager.default.fileExists(atPath: durl.path),
                   let data = try? Data(contentsOf: durl) {
                    context.insert(Asset(name: dname, kind: "drawing", data: data))
                    inserted = true
                }
            }
        }
        if inserted { try? context.save() }
    }

    // MARK: helpers

    private static func fetch(_ context: ModelContext, name: String) -> Asset? {
        let descriptor = FetchDescriptor<Asset>(predicate: #Predicate { $0.name == name })
        return try? context.fetch(descriptor).first
    }

    private static func exists(_ context: ModelContext, name: String) -> Bool {
        fetch(context, name: name) != nil
    }
}
