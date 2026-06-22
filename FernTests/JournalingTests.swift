import XCTest
@testable import Fern

final class JournalingTests: XCTestCase {

    private let cal = Calendar.current
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: displayTitle

    func test_displayTitle_usesTitleWhenPresent() {
        let e = Entry(title: "  Lady Bird ", body: "x", collection: .journal)
        XCTAssertEqual(e.displayTitle, "Lady Bird")
    }

    func test_displayTitle_fallsBackToFirstBodyLine() {
        let e = Entry(title: "  ", body: "\n  first real line\nsecond", collection: .journal)
        XCTAssertEqual(e.displayTitle, "first real line")
    }

    func test_displayTitle_placeholderWhenEmpty() {
        let e = Entry(title: "", body: "   \n  ", collection: .journal)
        XCTAssertEqual(e.displayTitle, "Untitled")
    }

    // MARK: stats

    func test_wordsThisWeek_sumsOnlyThisWeek() {
        let now = date(2026, 6, 17) // a Wednesday
        let thisWeek = Entry(title: "a", body: "one two three", collection: .journal, createdAt: now)
        let lastMonth = Entry(title: "b", body: "lots of words here now", collection: .journal,
                              createdAt: date(2026, 5, 1))
        let words = WritingStats.wordsThisWeek([thisWeek, lastMonth], asOf: now)
        XCTAssertEqual(words, 3)
    }

    func test_currentStreak_countsConsecutiveDaysEndingToday() {
        let now = date(2026, 6, 17, 20)
        let entries = [
            Entry(title: "", body: "x", collection: .journal, createdAt: date(2026, 6, 17, 8)),
            Entry(title: "", body: "x", collection: .journal, createdAt: date(2026, 6, 16, 8)),
            Entry(title: "", body: "x", collection: .journal, createdAt: date(2026, 6, 15, 8)),
            // gap on the 14th
            Entry(title: "", body: "x", collection: .journal, createdAt: date(2026, 6, 13, 8))
        ]
        XCTAssertEqual(WritingStats.currentStreak(entries, asOf: now), 3)
    }

    func test_currentStreak_zeroWhenNothingToday() {
        let now = date(2026, 6, 17)
        let entries = [Entry(title: "", body: "x", collection: .journal, createdAt: date(2026, 6, 16))]
        XCTAssertEqual(WritingStats.currentStreak(entries, asOf: now), 0)
    }

    // MARK: prompts

    func test_dailyPrompt_isStableForSameDay() {
        let morning = date(2026, 6, 17, 7)
        let evening = date(2026, 6, 17, 22)
        XCTAssertEqual(PromptLibrary.daily(kind: .journal, theme: nil, on: morning)?.text,
                       PromptLibrary.daily(kind: .journal, theme: nil, on: evening)?.text)
    }

    func test_promptLibrary_isLarge() {
        XCTAssertGreaterThan(PromptLibrary.all.count, 700)
    }

    func test_dailyPrompt_matchesKindAndTheme() {
        let p = PromptLibrary.daily(kind: .creative, theme: .nature, on: date(2026, 6, 17))
        XCTAssertEqual(p?.kind, .creative)
        XCTAssertEqual(p?.theme, .nature)
    }

    // MARK: on this day

    func test_onThisDay_findsPastYearsSameDay() {
        let now = date(2026, 6, 17)
        let lastYear = Entry(title: "then", body: "x", collection: .journal, createdAt: date(2025, 6, 17, 8))
        let twoYears = Entry(title: "older", body: "x", collection: .journal, createdAt: date(2024, 6, 17, 8))
        let otherDay = Entry(title: "no", body: "x", collection: .journal, createdAt: date(2025, 6, 18, 8))
        let today    = Entry(title: "today", body: "x", collection: .journal, createdAt: now)

        let found = OnThisDay.entries(from: [lastYear, twoYears, otherDay, today], asOf: now)
        XCTAssertEqual(found.map(\.title), ["then", "older"])
    }
}
