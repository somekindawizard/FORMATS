import CloudKit
import Foundation

/// A note in the shared "Austin & me" notebook, backed by a CloudKit record in
/// a shared zone (separate from the SwiftData store). Kept text-only for v1.
struct SharedNote: Identifiable, Equatable {
    let id: CKRecord.ID
    var title: String
    var body: String
    var author: String
    var modified: Date
    /// The CloudKit record (carries system fields for safe saves/merges).
    var record: CKRecord

    static let recordType = "SharedNote"

    static func == (lhs: SharedNote, rhs: SharedNote) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.body == rhs.body && lhs.modified == rhs.modified
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }
        self.id = record.recordID
        self.title = record["title"] as? String ?? ""
        self.body = record["body"] as? String ?? ""
        self.author = record["author"] as? String ?? ""
        self.modified = record["modified"] as? Date ?? record.modificationDate ?? .now
        self.record = record
    }

    /// A blank note to be created in the given zone.
    static func makeRecord(in zoneID: CKRecordZone.ID, parent: CKRecord, author: String) -> CKRecord {
        let record = CKRecord(recordType: recordType,
                              recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
        record["title"] = "" as CKRecordValue
        record["body"] = "" as CKRecordValue
        record["author"] = author as CKRecordValue
        record["modified"] = Date.now as CKRecordValue
        // Parent reference so notes are included in the notebook's share.
        record.parent = CKRecord.Reference(record: parent, action: .none)
        record.setValue(CKRecord.Reference(record: parent, action: .deleteSelf), forKey: "notebook")
        return record
    }

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = body.split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return firstLine.map { String($0).trimmingCharacters(in: .whitespaces) } ?? "Untitled"
    }
}
