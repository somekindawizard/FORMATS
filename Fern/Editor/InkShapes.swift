import PencilKit
import UIKit

// MARK: - Hold detection

/// Detects the Notes gesture for perfect shapes — finishing a stroke and
/// holding the Pencil still before lifting — from the stroke's OWN recorded
/// timing, at the moment `canvasViewDrawingDidChange` fires (≈ the lift).
///
/// While the tip is stationary PencilKit stops recording moving control
/// points, so "now − time of the last point that actually moved" IS the hold
/// duration. (A parallel UIGestureRecognizer can't do this job: PencilKit's
/// internal drawing recognizer cancels competitors when it claims the touch,
/// so an observer never survives to the lift.)
enum PencilHold {
    static func heldAtEnd(of stroke: PKStroke, holdInterval: TimeInterval = 0.45) -> Bool {
        let path = stroke.path
        guard let last = path.last else { return false }
        // Walk back to the most recent point that is meaningfully away from
        // the final resting position (pressure jitter can append stationary
        // points), then measure how long ago the ink stopped moving.
        var lastMoveOffset = last.timeOffset
        for p in path.reversed() {
            if hypot(p.location.x - last.location.x, p.location.y - last.location.y) > 3 { break }
            lastMoveOffset = p.timeOffset
        }
        let stoppedAt = path.creationDate.addingTimeInterval(lastMoveOffset)
        return Date.now.timeIntervalSince(stoppedAt) >= holdInterval
    }
}

// MARK: - Shape recognition

/// Fits a hand-drawn stroke to a perfect primitive — line, circle, ellipse,
/// triangle, or rectangle/quad — returning the idealized outline points, or
/// nil when the stroke doesn't convincingly match anything.
enum InkShapes {

    static func recognize(_ pts: [CGPoint]) -> [CGPoint]? {
        guard pts.count >= 8 else { return nil }
        let length = pathLength(pts)
        guard length > 30 else { return nil }

        // Open stroke → line?
        let gap = hypot(pts[0].x - pts[pts.count - 1].x, pts[0].y - pts[pts.count - 1].y)
        let closed = gap < max(24, 0.22 * length)
        if !closed {
            return fitLine(pts, length: length)
        }

        // Closed stroke → ellipse first, then polygon by corner count.
        if let ellipse = fitEllipse(pts) { return ellipse }
        let corners = simplify(pts, epsilon: max(8, 0.045 * length))
        switch corners.count {
        case 3: return polygon(corners)
        case 4: return fitQuad(corners)
        default: return nil
        }
    }

    // MARK: line

    private static func fitLine(_ pts: [CGPoint], length: CGFloat) -> [CGPoint]? {
        let a = pts[0], b = pts[pts.count - 1]
        let tol = max(5, 0.035 * length)
        for p in pts where perpDistance(p, a, b) > tol { return nil }
        return sampleSegment(a, b)
    }

    // MARK: ellipse / circle

    private static func fitEllipse(_ pts: [CGPoint]) -> [CGPoint]? {
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for p in pts {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        var a = (maxX - minX) / 2, b = (maxY - minY) / 2
        guard a > 8, b > 8 else { return nil }

        // Mean squared residual of the implicit ellipse equation.
        var err: CGFloat = 0
        for p in pts {
            let dx = (p.x - cx) / a, dy = (p.y - cy) / b
            err += abs(dx * dx + dy * dy - 1)
        }
        err /= CGFloat(pts.count)
        guard err < 0.18 else { return nil }

        // Nearly-equal axes snap to a true circle.
        if abs(a - b) < 0.18 * max(a, b) { let r = (a + b) / 2; a = r; b = r }

        var out: [CGPoint] = []
        let n = 72
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n) * 2 * .pi
            out.append(CGPoint(x: cx + a * cos(t), y: cy + b * sin(t)))
        }
        return out
    }

    // MARK: polygons

    private static func fitQuad(_ corners: [CGPoint]) -> [CGPoint]? {
        // Near-axis-aligned quads snap to the perfect bounding rectangle;
        // otherwise keep the drawn orientation, just straighten the edges.
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        var axisAligned = true
        for i in 0..<4 {
            let p = corners[i], q = corners[(i + 1) % 4]
            let angle = abs(atan2(q.y - p.y, q.x - p.x))
            let offAxis = min(angle, abs(angle - .pi / 2), abs(angle - .pi))
            if offAxis > .pi / 12 { axisAligned = false }   // > 15°
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        if axisAligned {
            return polygon([CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: minY),
                            CGPoint(x: maxX, y: maxY), CGPoint(x: minX, y: maxY)])
        }
        return polygon(corners)
    }

    /// Dense outline through the corners (closed).
    private static func polygon(_ corners: [CGPoint]) -> [CGPoint] {
        var out: [CGPoint] = []
        for i in 0..<corners.count {
            out += sampleSegment(corners[i], corners[(i + 1) % corners.count]).dropLast()
        }
        out.append(corners[0])
        return out
    }

    // MARK: geometry helpers

    private static func pathLength(_ pts: [CGPoint]) -> CGFloat {
        var len: CGFloat = 0
        for i in 1..<pts.count { len += hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y) }
        return len
    }

    private static func perpDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = hypot(dx, dy)
        guard len > 0.001 else { return hypot(p.x - a.x, p.y - a.y) }
        return abs(dy * p.x - dx * p.y + b.x * a.y - b.y * a.x) / len
    }

    /// Straight segment sampled every ~6pt (PKStrokePath smooths between
    /// control points; dense collinear samples keep edges straight).
    private static func sampleSegment(_ a: CGPoint, _ b: CGPoint) -> [CGPoint] {
        let len = hypot(b.x - a.x, b.y - a.y)
        let n = max(2, Int(len / 6))
        return (0...n).map { i in
            let t = CGFloat(i) / CGFloat(n)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }

    /// Ramer–Douglas–Peucker corner extraction over a closed stroke. The
    /// farthest-from-start point splits the loop so corners on both halves
    /// survive; endpoints are then merged if they collapsed together.
    private static func simplify(_ pts: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard pts.count > 4 else { return pts }
        var farIdx = pts.count / 2
        var farDist: CGFloat = 0
        for (i, p) in pts.enumerated() {
            let d = hypot(p.x - pts[0].x, p.y - pts[0].y)
            if d > farDist { farDist = d; farIdx = i }
        }
        let half1 = rdp(Array(pts[0...farIdx]), epsilon: epsilon)
        let half2 = rdp(Array(pts[farIdx...]), epsilon: epsilon)
        var corners = half1.dropLast() + half2.dropLast()
        // Merge a duplicated seam corner (start ≈ end).
        if let f = corners.first, let l = corners.last,
           hypot(f.x - l.x, f.y - l.y) < epsilon { corners = corners.dropLast() }
        return Array(corners)
    }

    private static func rdp(_ pts: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard pts.count > 2 else { return pts }
        var maxDist: CGFloat = 0
        var index = 0
        for i in 1..<pts.count - 1 {
            let d = perpDistance(pts[i], pts[0], pts[pts.count - 1])
            if d > maxDist { maxDist = d; index = i }
        }
        if maxDist > epsilon {
            let left = rdp(Array(pts[0...index]), epsilon: epsilon)
            let right = rdp(Array(pts[index...]), epsilon: epsilon)
            return left.dropLast() + right
        }
        return [pts[0], pts[pts.count - 1]]
    }

    // MARK: stroke synthesis

    /// A perfect-shape PKStroke in the same ink and weight as the original.
    static func stroke(points: [CGPoint], like original: PKStroke) -> PKStroke {
        let size = original.path.first.map(\.size) ?? CGSize(width: 4, height: 4)
        let controls = points.enumerated().map { i, p in
            PKStrokePoint(location: p, timeOffset: Double(i) * 0.01, size: size,
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: original.ink, path: PKStrokePath(controlPoints: controls,
                                                              creationDate: Date()))
    }
}
