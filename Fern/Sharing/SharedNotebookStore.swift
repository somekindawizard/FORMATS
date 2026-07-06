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

    /// The collaborator's name, from this device's user name (Brandon ↔ Austin).
    /// Falls back to a name learned from the share's participants, then generic.
    nonisolated static var partnerName: String {
        let me = (UserDefaults.standard.string(forKey: "fern.userName") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch me.lowercased() {
        case "austin":  return "Brandon"
        case "brandon": return "Austin"
        default:
            if let learned = UserDefaults.standard.string(forKey: "fern.partnerName"),
               !learned.isEmpty { return learned }
            return "your collaborator"
        }
    }
    var partnerName: String { Self.partnerName }

    /// Remember the other participant's name from a live share, for the generic case.
    private func learnPartner(from share: CKShare) {
        let others = share.participants.filter { $0.userIdentity.userRecordID != share.currentUserParticipant?.userIdentity.userRecordID }
        if let name = others.compactMap({ $0.userIdentity.nameComponents })
            .map({ PersonNameComponentsFormatter().string(from: $0) })
            .first(where: { !$0.isEmpty }) {
            UserDefaults.standard.set(name, forKey: "fern.partnerName")
        }
    }

    var notes: [SharedNote] = []
    var hasNotebook = false
    var isBusy = false
    /// Set when a save could not be persisted even after conflict-merging —
    /// surfaced by the editor so edits never vanish silently.
    var lastSaveFailed = false

    /// The freshest CKRecord per note. CloudKit's change tags advance on every
    /// save, so re-saving a stale instance fails `.ifServerRecordUnchanged` —
    /// without this cache, every save after the first was silently dropped.
    private var liveRecords: [CKRecord.ID: CKRecord] = [:]

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
            root["title"] = "\(myName) & \(partnerName)" as CKRecordValue
        }

        if let shareRef = root.share,
           let existing = try? await privateDB.record(for: shareRef.recordID) as? CKShare {
            learnPartner(from: existing)
            return existing
        }

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "Fern — \(myName) & \(partnerName)" as CKRecordValue
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
        liveRecords[note.id] = saved
        notes.insert(note, at: 0)
        return note
    }

    func save(_ note: SharedNote, title: String, body: String) async {
        let db = database(for: note.id.zoneID)
        let record = liveRecords[note.id] ?? note.record
        apply(title: title, body: body, to: record)
        do {
            let result = try await db.modifyRecords(saving: [record], deleting: [])
            switch result.saveResults[note.id] {
            case .success(let saved):
                liveRecords[note.id] = saved
                lastSaveFailed = false
            case .failure(let error):
                await resolveConflict(error, noteID: note.id, title: title, body: body, db: db)
            case nil:
                lastSaveFailed = true
            }
        } catch {
            await resolveConflict(error, noteID: note.id, title: title, body: body, db: db)
        }
    }

    private func apply(title: String, body: String, to record: CKRecord) {
        record["title"] = title as CKRecordValue
        record["body"] = body as CKRecordValue
        record["modified"] = Date.now as CKRecordValue
        record["author"] = myName as CKRecordValue
    }

    /// The partner saved since we last fetched (`serverRecordChanged`) — the
    /// whole point of a shared notebook. Re-apply our text onto the *server's*
    /// record (fresh change tag) and retry, so the save lands instead of being
    /// silently discarded. Field-level: our title/body win for this save;
    /// nothing local is dropped.
    private func resolveConflict(_ error: Error, noteID: CKRecord.ID,
                                 title: String, body: String, db: CKDatabase) async {
        guard let ck = error as? CKError, ck.code == .serverRecordChanged,
              let server = ck.serverRecord else {
            lastSaveFailed = true
            return
        }
        apply(title: title, body: body, to: server)
        if let result = try? await db.modifyRecords(saving: [server], deleting: []),
           case .success(let saved)? = result.saveResults[noteID] {
            liveRecords[noteID] = saved
            lastSaveFailed = false
        } else {
            lastSaveFailed = true
        }
    }

    func delete(_ note: SharedNote) async {
        let db = database(for: note.id.zoneID)
        _ = try? await db.modifyRecords(saving: [], deleting: [note.id])
        liveRecords[note.id] = nil
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
        // Freshly fetched records carry current change tags — cache them so the
        // next save doesn't fail `.ifServerRecordUnchanged`.
        for note in notes { liveRecords[note.id] = note.record }
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
