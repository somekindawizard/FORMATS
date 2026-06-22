import SwiftUI

/// The full-bleed paper canvas: a soft wash with the faintest vignette and a
/// low, static grain so the surface feels printed. Adapts to dark mode.
struct PaperBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Paper.bg
            LinearGradient(
                colors: scheme == .dark
                    ? [Color.white.opacity(0.04), .clear, Color.black.opacity(0.22)]
                    : [Color.white.opacity(0.20), .clear, Paper.sunken.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.clear, (scheme == .dark ? Color.black.opacity(0.28) : Paper.ink.opacity(0.04))],
                center: .center,
                startRadius: 280,
                endRadius: 620
            )
            PaperGrain(scheme: scheme).opacity(scheme == .dark ? 0.05 : 0.04)
        }
        .ignoresSafeArea()
    }
}

/// A cheap, static speckle drawn once into a Canvas — just enough tooth to read
/// as paper rather than flat color. Seeded so it never shimmers. In dark mode
/// the speckle is light and lightens rather than darkens.
private struct PaperGrain: View {
    let scheme: ColorScheme
    var body: some View {
        Canvas { context, size in
            var rng = SeededGenerator(seed: 4_211)
            let count = Int(size.width * size.height / 1000)
            let dot: Color = scheme == .dark ? .white : Color(red: 0.110, green: 0.102, blue: 0.090)
            for _ in 0..<count {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let s = Double.random(in: 0.5...1.3, using: &rng)
                let rect = CGRect(x: x, y: y, width: s, height: s)
                context.fill(Path(ellipseIn: rect), with: .color(dot))
            }
        }
        .blendMode(scheme == .dark ? .plusLighter : .multiply)
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
