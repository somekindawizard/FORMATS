import SwiftUI
import Foundation

/// Draws a generated Barnsley fern. Cheap and deterministic — the fern's
/// points are computed once (by the caller); we just plot.
///
/// When `sway` is true, the fern breathes with a gentle gust-and-settle
/// motion: a slow whole-frond bend weighted by height (base rooted, tip
/// moving most) plus a faint leaflet flutter. Driven by `TimelineView`.
struct BarnsleyFernView: View {
    let fern: BarnsleyFern
    var tint: Color = Paper.accent
    var dotSize: CGFloat = 1.2
    var alpha: Double = 0.62
    var sway: Bool = false

    var body: some View {
        if sway {
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    draw(ctx, size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        } else {
            Canvas { ctx, size in
                draw(ctx, size, time: nil)
            }
        }
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize, time: TimeInterval?) {
        guard !fern.points.isEmpty else { return }
        var ctx = context
        let xSpan = max(0.001, fern.maxX - fern.minX)
        let ySpan = max(0.001, fern.maxY)
        // Leave a touch more margin when swaying so the tip never clips.
        let fit: CGFloat = sway ? 0.88 : 0.94
        let scale = min(size.width / xSpan, size.height / ySpan) * fit
        let ox = size.width / 2 - ((fern.maxX + fern.minX) / 2) * scale
        let oy = size.height - (size.height - ySpan * scale) / 2
        ctx.opacity = alpha

        // Gentle gust signal (a slow two-sine breath). Static when time is nil.
        let swayScale = 0.30
        let t = time ?? 0
        let gust = 0.6 * sin(t * 0.5) + 0.28 * sin(t * 1.15 + 1.0)

        // Accumulate every dot into a single path and fill once — far faster
        // than a fill per dot, so tens of thousands of points stay smooth even
        // while swaying (redrawing each frame).
        var path = Path()
        for p in fern.points {
            var px = p.x
            if time != nil {
                let h = p.y / fern.maxY                      // 0 at base → 1 at tip
                let bend = swayScale * h * h * gust * sin(t * 0.62 - h * 1.3)
                let flutter = 0.018 * h * sin(t * 2.6 + p.y * 1.9 + p.x * 1.4)
                px = p.x + bend + flutter
            }
            path.addEllipse(in: CGRect(x: ox + px * scale,
                                       y: oy - p.y * scale,
                                       width: dotSize, height: dotSize))
        }
        ctx.fill(path, with: .color(tint))
    }
}

#Preview {
    BarnsleyFernView(fern: BarnsleyFern(seed: 4_211, count: 16_000), sway: true)
        .frame(width: 280, height: 380)
        .background(Paper.bg)
}
