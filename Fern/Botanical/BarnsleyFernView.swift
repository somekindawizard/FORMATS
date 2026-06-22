import SwiftUI

/// Draws a generated Barnsley fern. Cheap and deterministic — the fern's
/// points are computed once (by the caller); we just plot.
struct BarnsleyFernView: View {
    let fern: BarnsleyFern
    var tint: Color = Paper.accent
    var dotSize: CGFloat = 1.2
    var alpha: Double = 0.62

    var body: some View {
        Canvas { ctx, size in
            guard !fern.points.isEmpty else { return }
            let xSpan = max(0.001, fern.maxX - fern.minX)
            let ySpan = max(0.001, fern.maxY)
            // Letterbox-fit, anchored bottom-center.
            let scale = min(size.width / xSpan, size.height / ySpan) * 0.94
            let ox = size.width / 2 - ((fern.maxX + fern.minX) / 2) * scale
            let oy = size.height - (size.height - ySpan * scale) / 2
            ctx.opacity = alpha
            for p in fern.points {
                let r = CGRect(x: ox + p.x * scale,
                               y: oy - p.y * scale,
                               width: dotSize, height: dotSize)
                ctx.fill(Path(ellipseIn: r), with: .color(tint))
            }
        }
    }
}

#Preview {
    BarnsleyFernView(fern: BarnsleyFern(seed: 4_211, count: 24_000))
        .frame(width: 280, height: 380)
        .background(Paper.bg)
}
