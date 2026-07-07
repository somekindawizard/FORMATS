import SwiftData
import Foundation

/// A Redwood **project** — one long work (a novel, an essay collection, a
/// thesis). It owns a tree of documents and folders (the binder).
///
/// Like Fern's models, every stored property has a default and there are no
/// stored relationships or `.unique` constraints — the scalar-only shape that
/// keeps SwiftData's `insert` safe on iOS 26 and mirrors cleanly to CloudKit
/// if/when sync is turned on.
@Model
final class RWProject {
    var id: UUID = UUID()
    var title: String = ""
    var subtitle: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var order: Int = 0
    /// Optional target word count for the whole manuscript (0 = none).
    var wordTarget: Int = 0

    init(title: String, order: Int = 0) {
        self.title = title
        self.order = order
    }
}

/// A node in a project's binder: either a **folder** (groups children) or a
/// **document** (a writable section — scene, chapter, note). Nesting is by
/// `parentID` (nil = top level of the project); sibling order by `order`.
@Model
final class RWDocument {
    var id: UUID = UUID()
    var projectID: UUID = UUID()
    var parentID: UUID?              // nil = top level
    var title: String = ""
    /// The index-card synopsis shown on the corkboard / binder row.
    var synopsis: String = ""
    var body: String = ""           // Markdown
    var isFolder: Bool = false
    var order: Int = 0
    /// A workflow label — "", "todo", "draft", "revised", "final".
    var statusRaw: String = ""
    /// Optional per-document word goal ("this scene ≈ 2000 words"); 0 = none.
    var wordTarget: Int = 0
    /// Soft delete — non-nil means the node (and its subtree) is in the Trash,
    /// hidden from the binder but restorable. Inline default so existing stores
    /// migrate cleanly.
    var deletedAt: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(projectID: UUID, title: String = "", isFolder: Bool = false,
         order: Int = 0, parentID: UUID? = nil) {
        self.projectID = projectID
        self.title = title
        self.isFolder = isFolder
        self.order = order
        self.parentID = parentID
    }
}

extension RWDocument {
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = MarkdownRender.plainText(body)
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let firstLine { return String(firstLine).trimmingCharacters(in: .whitespaces) }
        return isFolder ? "Untitled folder" : "Untitled"
    }

    /// Word count over the *rendered* text, so Markdown syntax (`#`, `**`,
    /// list markers, template scaffolding) isn't counted as words — matching
    /// how `displayTitle` reads the body.
    var wordCount: Int {
        MarkdownRender.plainText(body)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// ≈ reading time in minutes (≥1), at ~220 wpm.
    var readMinutes: Int { max(1, Int((Double(wordCount) / 220).rounded(.up))) }

    var status: RWStatus {
        get { RWStatus(rawValue: statusRaw) ?? .none }
        set { statusRaw = newValue.rawValue }
    }
}

/// A frozen copy of a document at a moment in time — Redwood's version
/// history. Take one before a heavy revision; restore or read it later.
@Model
final class RWSnapshot {
    var id: UUID = UUID()
    var documentID: UUID = UUID()
    var title: String = ""
    var synopsis: String = ""
    var body: String = ""
    var label: String = ""          // e.g. "before revise", or blank
    var createdAt: Date = Date.now
    var wordCount: Int = 0

    init(documentID: UUID, title: String, synopsis: String, body: String,
         label: String = "", wordCount: Int = 0) {
        self.documentID = documentID
        self.title = title
        self.synopsis = synopsis
        self.body = body
        self.label = label
        self.wordCount = wordCount
    }
}

enum RWStatus: String, CaseIterable, Identifiable {
    // `none` stores as "" so the empty default and an explicit "no status" are
    // the same on-disk encoding (they previously diverged: "" vs "none").
    case none = "", todo, draft, revised, final
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none:    return "No status"
        case .todo:    return "To do"
        case .draft:   return "Draft"
        case .revised: return "Revised"
        case .final:   return "Final"
        }
    }
}
