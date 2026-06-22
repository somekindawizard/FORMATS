import XCTest
import SwiftData
@testable import Fern

@MainActor
final class ModelTests: XCTestCase {

    /// SwiftData's `isStoredInMemoryOnly: true` config has had stability
    /// issues that trap on first insert. Use a unique on-disk store per test
    /// instead — same isolation guarantee, no flakiness.
    func makeContext() throws -> ModelContext {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fern-test-\(UUID().uuidString).store")
        let container = try ModelContainer(
            for: Entry.self, Tag.self, Attachment.self,
            configurations: ModelConfiguration(url: url)
        )
        return container.mainContext
    }

    func test_entry_roundTrips() throws {
        let ctx = try makeContext()
        let entry = Entry(title: "Lady Bird",
                          body: "Still water this morning.",
                          collection: .journal)
        ctx.insert(entry)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Entry>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Lady Bird")
        XCTAssertEqual(fetched.first?.collection, .journal)
    }

    func test_wordCount_countsWhitespaceSeparatedTokens() {
        let entry = Entry(title: "x",
                          body: "  one two   three\nfour ",
                          collection: .piece)
        XCTAssertEqual(entry.wordCount, 4)
    }

    func test_wordCount_emptyBodyIsZero() {
        let entry = Entry(title: "x",
                          body: "   \n ",
                          collection: .piece)
        XCTAssertEqual(entry.wordCount, 0)
    }
}
