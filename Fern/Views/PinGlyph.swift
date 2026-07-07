import SwiftUI
import UIKit

/// A hand-drawn thumbtack in Fern's line-art language — the same voice as the
/// compose pencil: thin strokes, round caps, set on a slight diagonal as if
/// just pressed into the page. Flat head, collar, tapered shoulders, needle.
struct ThumbtackGlyph: Shape {
    /// Draw a slash through it (the "unpin" variant).
    var slashed = false

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = w / 2, cy = h / 2

        var p = Path()
        // Head plate (flat top bar).
        p.move(to: CGPoint(x: cx - 0.26 * w, y: 0.08 * h))
        p.addLine(to: CGPoint(x: cx + 0.26 * w, y: 0.08 * h))
        // Sides taper slightly inward down to the collar.
        p.move(to: CGPoint(x: cx - 0.20 * w, y: 0.08 * h))
        p.addLine(to: CGPoint(x: cx - 0.15 * w, y: 0.40 * h))
        p.move(to: CGPoint(x: cx + 0.20 * w, y: 0.08 * h))
        p.addLine(to: CGPoint(x: cx + 0.15 * w, y: 0.40 * h))
        // Collar — the wide flange the thumb presses.
        p.move(to: CGPoint(x: cx - 0.30 * w, y: 0.40 * h))
        p.addLine(to: CGPoint(x: cx + 0.30 * w, y: 0.40 * h))
        // Shoulders narrowing into the needle.
        p.move(to: CGPoint(x: cx - 0.30 * w, y: 0.40 * h))
        p.addLine(to: CGPoint(x: cx - 0.03 * w, y: 0.60 * h))
        p.move(to: CGPoint(x: cx + 0.30 * w, y: 0.40 * h))
        p.addLine(to: CGPoint(x: cx + 0.03 * w, y: 0.60 * h))
        // Needle down to the point.
        p.move(to: CGPoint(x: cx, y: 0.60 * h))
        p.addLine(to: CGPoint(x: cx, y: 0.94 * h))

        // Lean it like the pencil — just pressed in, not standing at attention.
        let lean = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: 0.42)
            .translatedBy(x: -cx, y: -cy)
        var tilted = p.applying(lean)

        if slashed {
            var slash = Path()
            slash.move(to: CGPoint(x: 0.14 * w, y: 0.10 * h))
            slash.addLine(to: CGPoint(x: 0.86 * w, y: 0.90 * h))
            tilted.addPath(slash)
        }
        return tilted
    }
}

/// Template renders of the thumbtack for contexts that only take an `Image`
/// (swipe-action buttons, menu rows). Tinted by the environment like an
/// SF Symbol.
enum PinIcon {
    static let pin = render(slashed: false)
    static let unpin = render(slashed: true)

    /// The tiny inline indicator (entry rows) as a SwiftUI view, stroked live
    /// so it stays crisp at any size.
    static func indicator(size: CGFloat = 10, color: Color) -> some View {
        ThumbtackGlyph()
            .stroke(color, style: StrokeStyle(lineWidth: max(1.1, size * 0.13),
                                              lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }

    private static func render(slashed: Bool) -> UIImage {
        let side: CGFloat = 40
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setLineWidth(3.0)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            let inset = rect.insetBy(dx: 5, dy: 5)
            cg.addPath(ThumbtackGlyph(slashed: slashed).path(in: inset).cgPath)
            cg.strokePath()
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
