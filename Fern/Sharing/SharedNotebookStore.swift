import CloudKit
import Observation
import Foundation

/// Manages the shared "Austin & me" notebook via CloudKit sharing — kept
/// entirely separate from the SwiftData store. The owner creates a custom zone
/// with a root record + `CKShare`; participants accept the share and the zone
/// appears in their shared database. Notes are child records of the root, so
/// they ride along with the share.
@MainActor
@Observable
final class SharedNotebookStore {
    static let shared = SharedNotebookStore()

    private let container = CKContainer(identifier: "iCloud.garden.fern.Fern")
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    private let zoneName = "SharedNotebook"
    private var ownedZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }
    private var ownedRootID: CKRecord.ID {
        CKRecord.ID(recordName: "root", zoneID: ownedZoneID)
    }

    private var myName: String {
        let n = UserDefaults.standard.string(forKey: "fern.userName") ?? ""
        return n.isEmpty ? "Me" : n
    }

    var notes: [SharedNote] = []
    var hasNotebook = false
    var isBusy = false

    // MARK: owner — create + invite

    /// Ensure the shared notebook exists (zone + root + share) and return the
    /// share to invite people with.
    func ensureShare() async throws -> CKShare {
        isBusy = true; defer { isBusy = false }
        _ = try? await privateDB.modifyRecordZones(saving: [CKRecordZone(zoneID: ownedZoneID)], deleting: [])

        let root: CKRecord
        if let existing = try? await privateDB.record(for: ownedRootID) {
            root = existing
        } else {
            root = CKRecord(recordType: "Notebook", recordID: ownedRootID)
            root["title"] = "Austin & me" as CKRecordValue
        }

        if let shareRef = root.share,
           let existing = try? await privateDB.record(for: shareRef.recordID) as? CKShare {
            return existing
        }

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "Fern — Austin & me" as CKRecordValue
        share.publicPermission = .none
        let result = try await privateDB.modifyRecords(saving: [root, share], deleting: [])
        if case .success(let saved) = result.saveResults[share.recordID], let s = saved as? CKShare {
            hasNotebook = true
            return s
        }
        return share
    }

    var containerForSharing: CKContainer { container }

    // MARK: accept (participant)

    func accept(_ metadata: CKShare.Metadata) async {
        _ = try? await container.accept(metadata)
        await refresh()
    }

    // MARK: notes

    /// The notebook root + the database it lives in (private if we own it,
    /// shared if we accepted an invite).
    private func rootAndDatabase() async -> (CKDatabase, CKRecord)? {
        if let root = try? await privateDB.record(for: ownedRootID) { return (privateDB, root) }
        if let zones = try? await sharedDB.allRecordZones() {
            for zone in zones {
                let rid = CKRecord.ID(recordName: "root", zoneID: zone.zoneID)
                if let root = try? await sharedDB.record(for: rid) { return (sharedDB, root) }
            }
        }
        return nil
    }

    @discardableResult
    func addNote() async -> SharedNote? {
        guard let (db, root) = await rootAndDatabase() else { return nil }
        let record = SharedNote.makeRecord(in: root.recordID.zoneID, parent: root, author: myName)
        guard let result = try? await db.modifyRecords(saving: [record], deleting: []),
              case .success(let saved)? = result.saveResults[record.recordID],
              let note = SharedNote(record: saved) else { return nil }
        notes.insert(note, at: 0)
        return note
    }

    func save(_ note: SharedNote, title: String, body: String) async {
        note.record["title"] = title as CKRecordValue
        note.record["body"] = body as CKRecordValue
        note.record["modified"] = Date.now as CKRecordValue
        note.record["author"] = myName as CKRecordValue
        let db = database(for: note.id.zoneID)
        _ = try? await db.modifyRecords(saving: [note.record], deleting: [])
    }

    func delete(_ note: SharedNote) async {
        let db = database(for: note.id.zoneID)
        _ = try? await db.modifyRecords(saving: [], deleting: [note.id])
        notes.removeAll { $0.id == note.id }
    }

    private func database(for zoneID: CKRecordZone.ID) -> CKDatabase {
        zoneID.ownerName == CKCurrentUserDefaultName ? privateDB : sharedDB
    }

    // MARK: refresh

    func refresh() async {
        var collected: [SharedNote] = []
        collected += await fetchNotes(privateDB, zone: ownedZoneID)
        if let zones = try? await sharedDB.allRecordZones() {
            for zone in zones { collected += await fetchNotes(sharedDB, zone: zone.zoneID) }
        }
        var seen = Set<CKRecord.ID>()
        notes = collected.filter { seen.insert($0.id).inserted }.sorted { $0.modified > $1.modified }
        hasNotebook = await rootAndDatabase() != nil
    }

    private func fetchNotes(_ db: CKDatabase, zone: CKRecordZone.ID) async -> [SharedNote] {
        await withCheckedContinuation { continuation in
            var notes: [SharedNote] = []
            let op = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zone],
                configurationsByRecordZoneID: [zone: .init()])
            op.recordWasChangedBlock = { _, result in
                if case .success(let record) = result, let note = SharedNote(record: record) {
                    notes.append(note)
                }
            }
            op.fetchRecordZoneChangesResultBlock = { _ in continuation.resume(returning: notes) }
            db.add(op)
        }
    }
}
