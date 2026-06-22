import XCTest
@testable import Fern

/// Unit tests for the model's pure logic. Persistence (insert/save/fetch)
/// is exercised by the editor in Plan 2 — there's a known iOS 26 SwiftData
/// trap in `_assertionFailure in ModelContainer.currentContainer(_:)`
/// when calling `insert` from an isolated XCTest, even on a minimal model.
/// The same persistence path works under the SwiftUI app lifecycle, where
/// the container is installed via `.modelContainer(_:)`, so we test it
/// there instead of fighting the framework in unit tests.
final class ModelTests: XCTestCase {

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

    func test_typedCollectionRoundtripsThroughRawString() {
        let entry = Entry(title: "x", body: "y", collection: .piece)
        XCTAssertEqual(entry.collection, .piece)
        entry.collection = .journal
        XCTAssertEqual(entry.collectionRaw, "journal")
    }

    func test_moodAccessorIsOptional() {
        let e = Entry(title: "x", body: "y", collection: .journal)
        XCTAssertNil(e.mood)
        e.mood = .calm
        XCTAssertEqual(e.moodRaw, "calm")
        e.mood = nil
        XCTAssertNil(e.moodRaw)
    }
}
