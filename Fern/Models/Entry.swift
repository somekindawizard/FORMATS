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
    // NOTE: every stored property has a default value (and no `.unique`
    // constraints, no stored relationships) so SwiftData can mirror the schema
    // to CloudKit. `init` still sets real values; the defaults just satisfy the
    // CloudKit requirement.
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""            // Markdown
    var collectionRaw: String = Collection.journal.rawValue
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var moodRaw: String?
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    /// Optional weather captured alongside place (SF Symbol name + °C).
    var weatherSymbol: String?
    var weatherTempC: Double?
    /// The prompt this entry was started from, if any — shown as a quiet
    /// reminder in the editor.
    var prompt: String?
    var isPinned: Bool = false
    /// When true, the entry's contents are hidden until Face ID unlocks them.
    var isLocked: Bool = false
    /// Optional named notebook (a custom collection) this entry belongs to.
    var notebook: String?
    /// For creative pieces: draft (false) vs finished (true).
    var isFinished: Bool = false
    /// Tags as a value array (not a relationship) — robust on iOS 26 SwiftData.
    /// Inline default so existing stores migrate cleanly when this is added.
    var tagNames: [String] = []
    /// Filenames of attached photos, stored in Documents/Photos (see PhotoStore).
    /// A value array, not a relationship — same robustness reasoning as tags.
    /// Photos may also be embedded inline in `body` as `![](fern://<name>)`.
    var photoFileNames: [String] = []
    /// When true, inline photos render in a theme-toned black-and-white wash.
    var photoWash: Bool = false
    /// Optional cover photo filename (in Documents/Photos) — shown as a hero
    /// image atop the note in reading mode and as a thumbnail in the library.
    var coverPhotoName: String = ""
    /// Text recognized from the note's Apple Pencil ink (Vision OCR), so
    /// handwriting is searchable. Empty when there's no ink.
    var inkText: String = ""

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        collection: Collection,
        createdAt: Date = .now,
        mood: Mood? = nil,
        isPinned: Bool = false,
        tagNames: [String] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.collectionRaw = collection.rawValue
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.moodRaw = mood?.rawValue
        self.isPinned = isPinned
        self.tagNames = tagNames
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

    /// True when the entry has no meaningful content — used to discard a
    /// note that was started ("Begin writing") but never written in.
    var isBlank: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && photoFileNames.isEmpty
            && tagNames.isEmpty
            && !DrawingStore.exists(id)
    }

    /// What to show in lists: the title, else the first non-empty line of the
    /// body, else a quiet placeholder.
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = MarkdownRender.plainText(body)
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let firstLine { return String(firstLine).trimmingCharacters(in: .whitespaces) }
        return "Untitled"
    }
}
