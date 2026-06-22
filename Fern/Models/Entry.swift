import SwiftData
import Foundation

/// One piece of writing — a dated journal entry or a longer creative piece.
///
/// The foundation `Entry` is **scalar-only**. Stored relationships (`tags`,
/// `attachments`) arrive where they're first used and tested:
/// - `tags` in Plan 3 (with a proper inverse on `Tag`)
/// - `attachments` in Plan 4 (photos)
///
/// Enums are stored as raw strings (`collectionRaw`, `moodRaw`) and surfaced
/// as typed properties via an **extension** below. Keeping the typed
/// accessors out of the `@Model` class avoids any chance of the macro
/// treating them as persistent (which can crash `insert` at runtime).
@Model
final class Entry {
    var id: UUID
    var title: String
    var body: String                 // Markdown
    var collectionRaw: String
    var createdAt: Date
    var updatedAt: Date
    var moodRaw: String?
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        collection: Collection,
        createdAt: Date = .now,
        mood: Mood? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.collectionRaw = collection.rawValue
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.moodRaw = mood?.rawValue
        self.isPinned = isPinned
    }
}

// MARK: – Typed enum accessors (kept out of the @Model body)

extension Entry {
    var collection: Collection {
        get { Collection(rawValue: collectionRaw) ?? .journal }
        set { collectionRaw = newValue.rawValue }
    }

    var mood: Mood? {
        get { moodRaw.flatMap(Mood.init(rawValue:)) }
        set { moodRaw = newValue?.rawValue }
    }

    /// Whitespace-separated token count of the body.
    var wordCount: Int {
        body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
