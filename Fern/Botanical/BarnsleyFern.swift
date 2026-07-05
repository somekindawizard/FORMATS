import CoreGraphics
import Foundation

/// One affine map of the fern's iterated function system.
struct FernTransform {
    var a, b, c, d, e, f: Double
    func apply(_ x: Double, _ y: Double) -> (Double, Double) {
        (a * x + b * y + e, c * x + d * y + f)
    }
}

/// The four maps + their probabilities that define a fern's *shape*. Perturbing
/// the coefficients (not just the RNG seed) is what makes a genuinely different
/// fern — the classic Barnsley set is an attractor, so reseeding alone barely
/// changes the silhouette.
struct FernVariant {
    var stem, leaflet, left, right: FernTransform
    var pStem, pLeaflet, pLeft: Double     // right takes the remainder

    static let classic = FernVariant(
        stem:    FernTransform(a: 0,     b: 0,     c: 0,     d: 0.16, e: 0, f: 0),
        leaflet: FernTransform(a: 0.85,  b: 0.04,  c: -0.04, d: 0.85, e: 0, f: 1.6),
        left:    FernTransform(a: 0.20,  b: -0.26, c: 0.23,  d: 0.22, e: 0, f: 1.6),
        right:   FernTransform(a: -0.15, b: 0.28,  c: 0.26,  d: 0.24, e: 0, f: 0.44),
        pStem: 0.01, pLeaflet: 0.85, pLeft: 0.07)

    /// A gently varied fern. `intensity` scales the jitter; kept modest so the
    /// result still reads as a fern (the leaflet map stays near-contractive).
    func perturbed(using rng: inout SplitMix64, intensity: Double = 1) -> FernVariant {
        func unit() -> Double { Double(rng.next()) / Double(UInt64.max) * 2 - 1 }   // −1…1
        func j(_ v: Double, _ range: Double) -> Double { v + unit() * range * intensity }
        var out = self
        out.stem    = FernTransform(a: 0, b: 0, c: 0, d: j(stem.d, 0.03), e: 0, f: 0)
        out.leaflet = FernTransform(a: j(leaflet.a, 0.028), b: j(leaflet.b, 0.03),
                                    c: j(leaflet.c, 0.03),  d: j(leaflet.d, 0.022),
                                    e: 0, f: j(leaflet.f, 0.12))
        out.left    = FernTransform(a: j(left.a, 0.05), b: j(left.b, 0.06),
                                    c: j(left.c, 0.05), d: j(left.d, 0.05),
                                    e: 0, f: j(left.f, 0.18))
        out.right   = FernTransform(a: j(right.a, 0.05), b: j(right.b, 0.06),
                                    c: j(right.c, 0.05), d: j(right.d, 0.05),
                                    e: 0, f: j(right.f, 0.18))
        return out
    }
}

/// Deterministic Barnsley fern — a rendered IFS for the app's signature mark.
/// Same seed + count + variant → byte-identical output.
struct BarnsleyFern {
    let points: [CGPoint]
    let minX: Double
    let maxX: Double
    let maxY: Double

    init(seed: UInt64, count: Int, variant: FernVariant = .classic) {
        var rng = SplitMix64(seed: seed)
        var pts = [CGPoint](); pts.reserveCapacity(max(0, count))
        var x: Double = 0, y: Double = 0
        var mnx: Double =  .infinity
        var mxx: Double = -.infinity
        var mxy: Double = -.infinity

        let tStem = variant.pStem
        let tLeaflet = tStem + variant.pLeaflet
        let tLeft = tLeaflet + variant.pLeft

        for _ in 0..<count {
            let r = Double(rng.next()) / Double(UInt64.max)
            let (nx, ny): (Double, Double)
            switch r {
            case ..<tStem:    (nx, ny) = variant.stem.apply(x, y)
            case ..<tLeaflet: (nx, ny) = variant.leaflet.apply(x, y)
            case ..<tLeft:    (nx, ny) = variant.left.apply(x, y)
            default:          (nx, ny) = variant.right.apply(x, y)
            }
            x = nx; y = ny
            pts.append(CGPoint(x: x, y: y))
            if x < mnx { mnx = x }
            if x > mxx { mxx = x }
            if y > mxy { mxy = y }
        }

        self.points = pts
        self.minX = pts.isEmpty ? 0 : mnx
        self.maxX = pts.isEmpty ? 0 : mxx
        self.maxY = pts.isEmpty ? 0 : mxy
    }
}

extension BarnsleyFern {
    /// A fresh, lightly-varied fern each call (system randomness).
    static func random(count: Int, intensity: Double = 1) -> BarnsleyFern {
        var sys = SystemRandomNumberGenerator()
        return varied(seed: sys.next(), count: count, intensity: intensity)
    }

    /// A fern that's unique to an id but stable — the same entry always grows
    /// the same fern (its fingerprint).
    static func forID(_ id: UUID, count: Int, intensity: Double = 1) -> BarnsleyFern {
        varied(seed: seed(from: id), count: count, intensity: intensity)
    }

    private static func varied(seed: UInt64, count: Int, intensity: Double) -> BarnsleyFern {
        var vrng = SplitMix64(seed: seed)
        let variant = FernVariant.classic.perturbed(using: &vrng, intensity: intensity)
        return BarnsleyFern(seed: seed, count: count, variant: variant)
    }

    /// Fold a UUID's 16 bytes into a 64-bit seed.
    static func seed(from id: UUID) -> UInt64 {
        withUnsafeBytes(of: id.uuid) { raw in
            var h: UInt64 = 0xcbf2_9ce4_8422_2325           // FNV-1a offset
            for byte in raw { h = (h ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
            return h
        }
    }
}

/// Splitmix64 — small, fast, deterministic. Same algorithm as the paper-grain
/// generator in Theme/PaperBackground.swift.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
