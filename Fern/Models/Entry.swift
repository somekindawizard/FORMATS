import SwiftData
import Foundation

/// One piece of writing — a dated journal entry or a longer creative piece.
///
/// The foundation Entry is **scalar-only**. Stored relationships (`tags`,
/// `attachments`) are introduced where they're first used and tested:
/// - `tags` in Plan 3 (with a proper inverse on Tag and predicate queries)
/// - `attachments` in Plan 4 (photos)
///
/// Enums (`Collection`, `Mood`) are stored as raw strings with typed
/// accessors. SwiftData on iOS 26 traps on insert when a stored property
/// is a custom `enum` — the raw-string indirection is the smallest fix
/// that keeps the public API (`entry.collection`, `entry.mood`) intact.
@Model
final class Entry {
    var id: UUID
    var title: String
    var body: String                  // Markdown
    var createdAt: Date
    var updatedAt: Date
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    var isPinned: Bool

    // MARK: – Enum storage (raw under the hood, typed in the API)

    private var collectionRaw: String
    var collection: Collection {
        get { Collection(rawValue: collectionRaw) ?? .journal }
        set { collectionRaw = newValue.rawValue }
    }

    private var moodRaw: String?
    var mood: Mood? {
        get { moodRaw.flatMap(Mood.init(rawValue:)) }
        set { moodRaw = newValue?.rawValue }
    }

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

    /// Whitespace-separated token count of the body.
    var wordCount: Int {
        body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
