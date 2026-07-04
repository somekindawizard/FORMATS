import SwiftData
import Foundation

/// The binary bytes behind a note's photos and ink, stored **in** the SwiftData
/// store so CloudKit syncs them across devices (the on-disk files in
/// Documents/Photos and Documents/Drawings don't sync on their own).
///
/// Scalar-only with defaults and no relationships — same shape that's safe to
/// insert on iOS 26 and to mirror to CloudKit. `.externalStorage` keeps the big
/// blob out of the row (CloudKit sends it as an asset).
@Model
final class Asset {
    var id: UUID = UUID()
    /// The exact filename the file-backed stores use, e.g. "<uuid>.jpg" or
    /// "<entryID>.drawing".
    var name: String = ""
    /// "photo" or "drawing" — selects which directory it materializes into.
    var kind: String = "photo"
    @Attribute(.externalStorage) var data: Data = Data()

    init(id: UUID = UUID(), name: String, kind: String, data: Data) {
        self.id = id
        self.name = name
        self.kind = kind
        self.data = data
    }
}
