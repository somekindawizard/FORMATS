import CoreGraphics

/// Deterministic Barnsley fern — a single rendered IFS for the app's
/// signature mark. Same seed + count → byte-identical output.
struct BarnsleyFern {
    let points: [CGPoint]
    let minX: Double
    let maxX: Double
    let maxY: Double

    init(seed: UInt64, count: Int) {
        var rng = SplitMix64(seed: seed)
        var pts = [CGPoint](); pts.reserveCapacity(max(0, count))
        var x: Double = 0, y: Double = 0
        var mnx: Double =  .infinity
        var mxx: Double = -.infinity
        var mxy: Double = -.infinity

        for _ in 0..<count {
            let r = Double(rng.next()) / Double(UInt64.max)
            let (nx, ny): (Double, Double)
            switch r {
            case ..<0.01:
                nx = 0;                     ny = 0.16 * y
            case ..<0.86:
                nx = 0.85 * x + 0.04 * y;   ny = -0.04 * x + 0.85 * y + 1.6
            case ..<0.93:
                nx = 0.20 * x - 0.26 * y;   ny =  0.23 * x + 0.22 * y + 1.6
            default:
                nx = -0.15 * x + 0.28 * y;  ny =  0.26 * x + 0.24 * y + 0.44
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
