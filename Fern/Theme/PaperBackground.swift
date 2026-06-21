import SwiftUI

/// The full-bleed paper canvas: a soft cool-white wash with the faintest
/// vignette and a low, static grain so the surface feels printed.
struct PaperBackground: View {
    var body: some View {
        ZStack {
            Paper.bg
            LinearGradient(
                colors: [
                    Color.white.opacity(0.20),
                    Color.clear,
                    Paper.sunken.opacity(0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.clear, Paper.ink.opacity(0.04)],
                center: .center,
                startRadius: 280,
                endRadius: 620
            )
            PaperGrain().opacity(0.04)
        }
        .ignoresSafeArea()
    }
}

/// A cheap, static speckle drawn once into a Canvas — just enough tooth
/// to read as paper rather than flat color. Seeded so it never shimmers.
private struct PaperGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededGenerator(seed: 4_211)
            let count = Int(size.width * size.height / 1000)
            for _ in 0..<count {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let s = Double.random(in: 0.5...1.3, using: &rng)
                let rect = CGRect(x: x, y: y, width: s, height: s)
                context.fill(Path(ellipseIn: rect), with: .color(Paper.ink))
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

/// Deterministic generator so the grain doesn't shimmer on every redraw.
struct SeededGenerator: RandomNumberGenerator {
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
