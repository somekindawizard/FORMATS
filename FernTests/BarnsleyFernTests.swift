import XCTest
@testable import Fern

final class BarnsleyFernTests: XCTestCase {

    func test_isDeterministic_forSameSeed() {
        let a = BarnsleyFern(seed: 4_211, count: 5_000)
        let b = BarnsleyFern(seed: 4_211, count: 5_000)
        XCTAssertEqual(a.points.count, b.points.count)
        XCTAssertEqual(a.points.first?.x, b.points.first?.x)
        XCTAssertEqual(a.points.last?.x,  b.points.last?.x)
    }

    func test_pointsCoverFernExtent() {
        let f = BarnsleyFern(seed: 9_173, count: 20_000)
        // Canonical Barnsley extent: x ~ [-2.18, 2.66], y ~ [0, 9.99]
        XCTAssertGreaterThan(f.maxY, 7)
        XCTAssertLessThan(f.minX, -1.5)
        XCTAssertGreaterThan(f.maxX,  1.5)
    }

    func test_emptyCountReturnsEmpty() {
        XCTAssertTrue(BarnsleyFern(seed: 1, count: 0).points.isEmpty)
    }
}
