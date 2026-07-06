import XCTest
import simd
@testable import Fern

final class FernPhysicsTests: XCTestCase {
    private let p = FernPhysicsParams.defaults

    // A displaced point, untouched, moves back toward home.
    func testReturnsTowardHome() {
        let home = SIMD2<Float>(0, 0)
        var pos = SIMD2<Float>(50, 0)
        var vel = SIMD2<Float>(0, 0)
        for _ in 0..<20 {
            (pos, vel) = FernPhysicsStep.step(pos: pos, vel: vel, home: home,
                finger: .zero, touching: false, params: p, dt: 1.0 / 120)
        }
        XCTAssertLessThan(abs(pos.x), 50, "should have moved back toward home")
    }

    // Energy decays: after long settling, it's essentially at rest at home.
    func testSettlesAtHome() {
        let home = SIMD2<Float>(10, -5)
        var pos = SIMD2<Float>(120, 90)
        var vel = SIMD2<Float>(0, 0)
        for _ in 0..<2000 {
            (pos, vel) = FernPhysicsStep.step(pos: pos, vel: vel, home: home,
                finger: .zero, touching: false, params: p, dt: 1.0 / 120)
        }
        XCTAssertLessThan(distance(pos, home), 0.5)
        XCTAssertLessThan(length(vel), 0.5)
    }

    // Underdamped: it overshoots home at least once (crosses to the far side).
    func testUnderdampedOvershoots() {
        var soft = FernPhysicsParams.defaults
        soft.springK = 220; soft.damping = 1.2   // lively, low damping
        soft.globalDamp = 1.0
        let home = SIMD2<Float>(0, 0)
        var pos = SIMD2<Float>(40, 0)
        var vel = SIMD2<Float>(0, 0)
        var overshot = false
        for _ in 0..<400 {
            (pos, vel) = FernPhysicsStep.step(pos: pos, vel: vel, home: home,
                finger: .zero, touching: false, params: soft, dt: 1.0 / 120)
            if pos.x < -0.5 { overshot = true; break }
        }
        XCTAssertTrue(overshot, "an underdamped spring should overshoot home")
    }

    // A touching finger pushes a nearby point away from the finger.
    func testFingerPushesAway() {
        let params = FernPhysicsParams.defaults
        let home = SIMD2<Float>(0, 0)
        var pos = SIMD2<Float>(0, 0)         // sitting at home, finger just left of it
        var vel = SIMD2<Float>(0, 0)
        let finger = SIMD2<Float>(-8, 0)     // within radius
        (pos, vel) = FernPhysicsStep.step(pos: pos, vel: vel, home: home,
            finger: finger, touching: true, params: params, dt: 1.0 / 120)
        XCTAssertGreaterThan(vel.x, 0, "point should be shoved to the right, away from finger")
    }
}
