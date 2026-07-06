import SwiftUI
import UIKit

/// Renders a Barnsley fern point cloud with Scott Draves' fractal-flame
/// technique — a **log-density histogram**, gamma-corrected and supersampled —
/// for a smooth, tonal, anti-aliased "botanical print" instead of flat dots.
/// Returns a transparent, accent-tinted image that composites over the paper.
enum FlameFern {
    static func image(_ fern: BarnsleyFern, height: CGFloat, tint: UIColor,
                      gamma: Double = 1.6, supersample: CGFloat = 2) -> UIImage? {
        guard !fern.points.isEmpty else { return nil }
        let xs = max(0.001, fern.maxX - fern.minX)
        let ys = max(0.001, fern.maxY)
        let H = max(1, Int((height * supersample).rounded()))
        let W = max(1, Int((CGFloat(H) * CGFloat(xs / ys)).rounded()) + 1)

        // 1. Accumulate a hit histogram (base at the bottom, tip up).
        var hist = [Float](repeating: 0, count: W * H)
        let pad = 0.05
        let s = Double(H) * (1 - 2 * pad) / ys
        let ox = Double(W) / 2 - ((fern.maxX + fern.minX) / 2) * s
        let bottom = Double(H) * (1 - pad)
        for p in fern.points {
            let px = Int(ox + p.x * s)
            let py = Int(bottom - p.y * s)
            if px >= 0, px < W, py >= 0, py < H { hist[py * W + px] += 1 }
        }
        var maxH: Float = 0
        for v in hist where v > maxH { maxH = v }
        guard maxH > 0 else { return nil }
        let denom = log(1 + Double(maxH))

        // 2. Log-density tone map → premultiplied, transparent where sparse.
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        tint.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        var buf = [UInt8](repeating: 0, count: W * H * 4)
        for i in 0..<W * H {
            let h = hist[i]
            if h <= 0 { continue }
            let t = pow(log(1 + Double(h)) / denom, 1 / gamma)          // 0…1
            buf[i * 4 + 0] = UInt8(max(0, min(255, Double(tr) * t * 255)))
            buf[i * 4 + 1] = UInt8(max(0, min(255, Double(tg) * t * 255)))
            buf[i * 4 + 2] = UInt8(max(0, min(255, Double(tb) * t * 255)))
            buf[i * 4 + 3] = UInt8(max(0, min(255, t * 255)))
        }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(buf) as CFData),
              let cg = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: W * 4, space: cs,
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return UIImage(cgImage: cg, scale: supersample, orientation: .up)
    }
}

/// Displays a fern rendered by the flame technique. `sway` gives a gentle,
/// cheap whole-image lean (pivoting at the base) so it still breathes.
struct FlameFernView: View {
    let fern: BarnsleyFern
    var tint: Color = Paper.accent
    var sway: Bool = false
    var renderHeight: CGFloat = 820
    @State private var image: UIImage?

    private var key: String { "\(fern.points.count)-\(Int(fern.maxY * 100))-\(Int(fern.minX * 100))-\(Int(fern.maxX * 100))" }

    var body: some View {
        Group {
            if let image {
                if sway {
                    TimelineView(.animation) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        Image(uiImage: image).resizable().scaledToFit()
                            .rotationEffect(.degrees(sin(t * 0.55) * 1.5 + sin(t * 1.2 + 1) * 0.7), anchor: .bottom)
                            .scaleEffect(x: 1, y: 1 + sin(t * 0.9) * 0.006, anchor: .bottom)
                    }
                } else {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            } else {
                Color.clear
            }
        }
        .task(id: key) {
            let f = fern, h = renderHeight, c = UIColor(tint)
            let img = await Task.detached(priority: .userInitiated) {
                FlameFern.image(f, height: h, tint: c)
            }.value
            image = img
        }
    }
}
