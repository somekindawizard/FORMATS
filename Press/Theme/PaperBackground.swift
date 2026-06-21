import SwiftUI

/// The full-bleed paper canvas: a warm cream wash with the faintest
/// vignette and a low, static grain so the surface feels printed.
struct PaperBackground: View {
    var body: some View {
        ZStack {
            Paper.bg
            // A barely-there warmth from the top, settling darker at the foot.
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.clear,
                    Paper.sunken.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Soft corner vignette to suggest a sheet lifting off the table.
            RadialGradient(
                colors: [Color.clear, Paper.ink.opacity(0.05)],
                center: .center,
                startRadius: 280,
                endRadius: 620
            )
            PaperGrain().opacity(0.05)
        }
        .ignoresSafeArea()
    }
}

/// A cheap, static speckle drawn once into a Canvas — just enough tooth
/// to read as paper rather than flat color.
private struct PaperGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededGenerator(seed: 9_173)
            let count = Int(size.width * size.height / 900)
            for _ in 0..<count {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let s = Double.random(in: 0.5...1.4, using: &rng)
                let rect = CGRect(x: x, y: y, width: s, height: s)
                context.fill(Path(ellipseIn: rect), with: .color(Paper.ink))
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

/// Deterministic generator so the grain doesn't shimmer on every redraw.
private struct SeededGenerator: RandomNumberGenerator {
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
