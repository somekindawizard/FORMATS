import XCTest
@testable import Fern

final class DateGroupingTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func test_groupsByDay_sortedNewestFirst() {
        let a = Entry(title: "a", body: "x", collection: .journal, createdAt: date(2026, 6, 21, 7))
        let b = Entry(title: "b", body: "x", collection: .journal, createdAt: date(2026, 6, 21, 19))
        let c = Entry(title: "c", body: "x", collection: .piece,   createdAt: date(2026, 6, 18))

        let sections = DayGrouping.sections(from: [a, b, c])

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].entries.count, 2)
        XCTAssertEqual(sections[0].entries.first?.title, "b")  // newest within day first
        XCTAssertEqual(sections[1].entries.first?.title, "c")
    }
}
