import SwiftUI

/// The developmental view of a fern: a coiled fiddlehead (crozier) unrolling
/// into the open frond. The fern's central axis is bent into a logarithmic
/// spiral, and an "unfurl front" travels base→tip; leaflets stay furled until
/// the front passes them. `t` = 0 (coiled) … 1 (open).
enum UnfurlFern {
    static func screenPoints(_ fern: BarnsleyFern, t: Double, in size: CGSize, stride strideN: Int) -> [CGPoint] {
        let maxY = fern.maxY
        guard maxY > 0, !fern.points.isEmpty else { return [] }

        // Integrate the curled axis for this moment.
        let steps = 260
        let ds = maxY / Double(steps)
        let front = t * maxY * 1.25
        let curl = 7.5
        var pos = CGPoint.zero
        var ang = Double.pi / 2                       // pointing up
        var sPos = [CGPoint](repeating: .zero, count: steps + 1)
        var sAng = [Double](repeating: 0, count: steps + 1)
        for i in 0...steps {
            sPos[i] = pos; sAng[i] = ang
            let over = max(0, Double(i) * ds - front)
            ang += curl * (over / maxY) * ds          // increasing curvature → log spiral
            pos = CGPoint(x: pos.x + cos(ang) * ds, y: pos.y + sin(ang) * ds)
        }

        // Fit using the straight-fern bounds so it unrolls in place.
        let xs = max(0.001, fern.maxX - fern.minX)
        let ys = max(0.001, maxY)
        let scale = min(size.width * 0.8 / xs, size.height * 0.9 / ys)
        let ox = size.width / 2 - ((fern.maxX + fern.minX) / 2) * scale
        let bottom = size.height - (size.height - ys * scale) / 2

        var out = [CGPoint](); out.reserveCapacity(fern.points.count / max(1, strideN))
        var idx = 0
        for p in fern.points {
            idx += 1; if idx % strideN != 0 { continue }
            let s = min(maxY, max(0, p.y))
            let i = min(steps, Int(s / ds))
            let base = sPos[i]; let a = sAng[i]
            let openFrac = s <= front ? 1.0 : max(0.10, 1.0 - (s - front) / (maxY * 0.5))
            let d = p.x * openFrac                     // leaflets furled until the front passes
            let rotA = a - Double.pi / 2
            let bx = base.x + d * cos(rotA)
            let by = base.y + d * sin(rotA)
            out.append(CGPoint(x: ox + bx * scale, y: bottom - by * scale))
        }
        return out
    }
}

/// Plays the unfurl (as dots) once, then cross-fades into the flame still,
/// which breathes with the gentle sway.
struct UnfurlingFlameFern: View {
    let fern: BarnsleyFern
    var tint: Color = Paper.accent
    var duration: Double = 2.3

    @State private var open = false
    @State private var start = Date()

    var body: some View {
        ZStack {
            if open {
                FlameFernView(fern: fern, sway: true).transition(.opacity)
            } else {
                TimelineView(.animation) { tl in
                    let e = min(1, max(0, tl.date.timeIntervalSince(start) / duration))
                    let t = 1 - pow(1 - e, 3)          // ease out
                    Canvas { ctx, size in
                        var path = Path()
                        for p in UnfurlFern.screenPoints(fern, t: t, in: size, stride: 3) {
                            path.addEllipse(in: CGRect(x: p.x - 0.6, y: p.y - 0.6, width: 1.2, height: 1.2))
                        }
                        ctx.fill(path, with: .color(tint.opacity(0.62)))
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            open = false
            start = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                withAnimation(.easeInOut(duration: 0.6)) { open = true }
            }
        }
    }
}
