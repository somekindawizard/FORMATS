import simd
import CoreGraphics

/// Tunable feel constants for the interactive fern. Shared by the CPU mirror
/// (tests) and the GPU (packed into `FernUniforms`).
struct FernPhysicsParams {
    var springK: Float        // pull back toward home
    var damping: Float        // velocity damping (per-force)
    var globalDamp: Float     // per-step velocity multiplier (stability)
    var fingerRadius: Float   // points; influence radius of the finger
    var pushStrength: Float   // radial shove away from finger
    var dragCoupling: Float   // how much the finger's motion sweeps points
    var pointSize: Float      // px splat diameter
    var toneGamma: Float      // matches FlameFern
    var toneFloor: Float      // matches FlameFern
    var densityDenom: Float   // log-density normalizer (tuned for the point count)

    static let defaults = FernPhysicsParams(
        springK: 120, damping: 6, globalDamp: 0.985,
        fingerRadius: 90, pushStrength: 26000, dragCoupling: 2.2,
        pointSize: 2.2, toneGamma: 2.3, toneFloor: 0.55, densityDenom: 5.2)
}

/// Pure integrator for one point, one step. The Metal `fern_physics` kernel is a
/// line-for-line port of this — keep them in sync.
enum FernPhysicsStep {
    static func step(pos: SIMD2<Float>, vel: SIMD2<Float>, home: SIMD2<Float>,
                     finger: SIMD2<Float>, touching: Bool,
                     params p: FernPhysicsParams, dt: Float)
    -> (SIMD2<Float>, SIMD2<Float>) {
        var v = vel
        var F = p.springK * (home - pos) - p.damping * v
        if touching {
            let d = pos - finger
            let r = simd_length(d)
            if r < p.fingerRadius && r > 1e-4 {
                var fall = 1 - r / p.fingerRadius
                fall = fall * fall * (3 - 2 * fall)     // smoothstep
                F += p.pushStrength * fall * (d / r)
                // fingerVel is folded in on the GPU side; the CPU mirror models
                // the radial shove only.
            }
        }
        v += F * dt
        v *= p.globalDamp
        let np = pos + v * dt
        return (np, v)
    }
}
