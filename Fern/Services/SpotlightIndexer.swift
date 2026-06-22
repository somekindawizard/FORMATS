import CoreSpotlight
import UniformTypeIdentifiers
import Foundation

/// Indexes entries in CoreSpotlight so they're findable from system search.
/// Opening a result hands the app an NSUserActivity carrying the entry's id.
enum SpotlightIndexer {
    static let domain = "garden.fern.entry"

    private static func attributeSet(for entry: Entry) -> CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = entry.displayTitle
        attrs.contentDescription = String(entry.body.prefix(300))
        attrs.keywords = entry.tagNames
        return attrs
    }

    private static func item(for entry: Entry) -> CSSearchableItem {
        CSSearchableItem(uniqueIdentifier: entry.id.uuidString,
                         domainIdentifier: domain,
                         attributeSet: attributeSet(for: entry))
    }

    static func index(_ entry: Entry) {
        CSSearchableIndex.default().indexSearchableItems([item(for: entry)])
    }

    static func deindex(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString])
    }

    /// Rebuild the whole index (call on launch). Reads models — main actor.
    static func reindexAll(_ entries: [Entry]) {
        CSSearchableIndex.default().indexSearchableItems(entries.map(item(for:)))
    }
}
