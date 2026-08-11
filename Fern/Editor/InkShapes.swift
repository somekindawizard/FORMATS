import PencilKit
import UIKit

// MARK: - Shape recognition

/// Fits a hand-drawn stroke to a perfect primitive — line, circle, ellipse,
/// triangle, or rectangle/quad — returning the idealized outline points, or
/// nil when the stroke doesn't convincingly match anything.
enum InkShapes {

    static func recognize(_ pts: [CGPoint]) -> [CGPoint]? {
        guard pts.count >= 8 else { return nil }
        let length = pathLength(pts)
        guard length > 30 else { return nil }

        // Open stroke → line, else arrow (template).
        let gap = hypot(pts[0].x - pts[pts.count - 1].x, pts[0].y - pts[pts.count - 1].y)
        let closed = gap < max(24, 0.22 * length)
        if !closed {
            if let line = fitLine(pts, length: length) { return line }
            guard let (outline, cloud) = matchTemplate(pts, in: ShapeTemplates.open),
                  cloud < 0.045 else { return nil }
            return outline
        }

        // Closed stroke → score EVERY interpretation (ellipse, polygon/star,
        // templates) against the drawn points and take the lowest error, the
        // way PaleoSketch-style recognizers do — first-match-wins let a
        // mediocre polygon beat a good circle whose fit barely errored out.
        let sample = resample(pts, to: 64)
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for p in pts {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let diag = hypot(maxX - minX, maxY - minY)
        guard diag > 1 else { return nil }

        /// Mean distance from the drawn points to the candidate outline,
        /// normalized by the bounding-box diagonal (dimensionless, so all
        /// shape classes compete on equal terms).
        func fitError(_ outline: [CGPoint]) -> CGFloat {
            var sum: CGFloat = 0
            for p in sample {
                var best = CGFloat.greatestFiniteMagnitude
                for q in outline {
                    let d = hypot(p.x - q.x, p.y - q.y)
                    if d < best { best = d }
                }
                sum += best
            }
            return sum / CGFloat(sample.count) / diag
        }

        var candidates: [(points: [CGPoint], score: CGFloat)] = []
        if let ellipse = fitEllipse(pts) {
            candidates.append((ellipse, fitError(ellipse)))
        }
        if let corners = polygonCorners(pts) {
            var shape: [CGPoint]?
            switch corners.count {
            case 3:      shape = polygon(corners)
            case 4:      shape = fitQuad(corners)
            case 5...7:  shape = polygon(corners)
            case 8...12: shape = fitStar(corners) ?? polygon(corners)
            default:     break
            }
            if let s = shape {
                // Small per-corner penalty so a many-gon can't edge out a
                // simpler interpretation on raw error alone.
                candidates.append((s, fitError(s) + 0.002 * CGFloat(corners.count)))
            }
        }
        if let (outline, cloud) = matchTemplate(pts, in: ShapeTemplates.closed), cloud < 0.045 {
            // Templates compete on their calibrated cloud distance — a drawn
            // heart legitimately differs in proportion from the parametric
            // ideal, so nearest-point error would unfairly punish it. The
            // 0.045 gate is the calibrated accept threshold (hearts ~0.03,
            // circle 0.06, lumpy blob 0.09).
            candidates.append((outline, cloud))
        }
        guard let best = candidates.min(by: { $0.score < $1.score }),
              best.score < 0.05 else { return nil }
        return best.points
    }

    // MARK: line

    private static func fitLine(_ pts: [CGPoint], length: CGFloat) -> [CGPoint]? {
        let a = pts[0], b = pts[pts.count - 1]
        let tol = max(5, 0.035 * length)
        for p in pts where perpDistance(p, a, b) > tol { return nil }
        return sampleSegment(a, b)
    }

    // MARK: ellipse / circle (PCA-oriented — handles tilted ovals)

    private static func fitEllipse(_ pts: [CGPoint]) -> [CGPoint]? {
        // Principal axis from the point covariance, so an oval drawn at any
        // angle is fitted in its own frame (an axis-aligned bbox fit rejected
        // every tilted ellipse).
        let n = CGFloat(pts.count)
        let cx = pts.map(\.x).reduce(0, +) / n
        let cy = pts.map(\.y).reduce(0, +) / n
        var sxx: CGFloat = 0, syy: CGFloat = 0, sxy: CGFloat = 0
        for p in pts {
            let dx = p.x - cx, dy = p.y - cy
            sxx += dx * dx; syy += dy * dy; sxy += dx * dy
        }
        let theta = 0.5 * atan2(2 * sxy, sxx - syy)
        let ct = cos(theta), st = sin(theta)

        // Rotate into the principal frame; fit semi-axes by least squares
        // (mean |coordinate| — for an ellipse E|u| = 2a/π), not max extents:
        // one overshoot at the seam inflated an extent-based axis and pushed
        // every other residual past the threshold, so wobbly circles fell
        // through to the corner finder and came back as pentagons.
        var sumU: CGFloat = 0, sumV: CGFloat = 0
        let local = pts.map { p -> CGPoint in
            let dx = p.x - cx, dy = p.y - cy
            let u = dx * ct + dy * st, v = -dx * st + dy * ct
            sumU += abs(u); sumV += abs(v)
            return CGPoint(x: u, y: v)
        }
        var a = sumU / n * .pi / 2, b = sumV / n * .pi / 2
        guard a > 8, b > 8 else { return nil }

        var err: CGFloat = 0
        for p in local {
            let du = p.x / a, dv = p.y / b
            err += abs(du * du + dv * dv - 1)
        }
        err /= n
        // Loose sanity gate only — the candidate scorer makes the real call.
        guard err < 0.35 else { return nil }

        // Nearly-equal axes snap to a true circle.
        if abs(a - b) < 0.18 * max(a, b) { let r = (a + b) / 2; a = r; b = r }

        var out: [CGPoint] = []
        for i in 0...72 {
            let t = CGFloat(i) / 72 * 2 * .pi
            let u = a * cos(t), v = b * sin(t)
            out.append(CGPoint(x: cx + u * ct - v * st, y: cy + u * st + v * ct))
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

    // MARK: star

    /// Corners alternating far/near from the centroid → a perfect N-point
    /// star (outer/inner radii averaged, phase from the farthest corner).
    private static func fitStar(_ corners: [CGPoint]) -> [CGPoint]? {
        guard corners.count % 2 == 0 else { return nil }
        let n = corners.count / 2
        let cx = corners.map(\.x).reduce(0, +) / CGFloat(corners.count)
        let cy = corners.map(\.y).reduce(0, +) / CGFloat(corners.count)
        let radii = corners.map { hypot($0.x - cx, $0.y - cy) }

        // Order corners by angle, then radii must alternate far/near.
        let indexed = corners.indices.sorted {
            atan2(corners[$0].y - cy, corners[$0].x - cx) <
            atan2(corners[$1].y - cy, corners[$1].x - cx)
        }
        let ordered = indexed.map { radii[$0] }
        var outer: [CGFloat] = [], inner: [CGFloat] = []
        let firstIsOuter = ordered[0] > ordered[1]
        for (i, r) in ordered.enumerated() {
            if (i % 2 == 0) == firstIsOuter { outer.append(r) } else { inner.append(r) }
        }
        let R = outer.reduce(0, +) / CGFloat(outer.count)
        let r = inner.reduce(0, +) / CGFloat(inner.count)
        guard R > 12, r > 4, r < 0.75 * R else { return nil }
        // Alternation must be consistent (every outer > every neighboring inner).
        guard outer.min()! > inner.max()! else { return nil }

        // Phase from the farthest drawn corner.
        let farIdx = radii.firstIndex(of: radii.max()!) ?? 0
        let phase = atan2(corners[farIdx].y - cy, corners[farIdx].x - cx)

        var tips: [CGPoint] = []
        for i in 0..<(2 * n) {
            let a = phase + CGFloat(i) * .pi / CGFloat(n)
            let rad = i % 2 == 0 ? R : r
            tips.append(CGPoint(x: cx + rad * cos(a), y: cy + rad * sin(a)))
        }
        return polygon(tips)
    }

    // MARK: drawn-shape templates ($1-style matcher)

    /// Normalize a stroke: resample to 64 points, translate centroid to the
    /// origin, scale the bounding box to a unit square.
    fileprivate static func normalize(_ pts: [CGPoint]) -> [CGPoint] {
        let resampled = resample(pts, to: 64)
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for p in resampled {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let w = max(1, maxX - minX), h = max(1, maxY - minY)
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        return resampled.map { CGPoint(x: ($0.x - cx) / w, y: ($0.y - cy) / h) }
    }

    fileprivate static func resample(_ pts: [CGPoint], to n: Int) -> [CGPoint] {
        guard pts.count > 1 else { return pts }
        let step = pathLength(pts) / CGFloat(n - 1)
        guard step > 0 else { return pts }
        var out: [CGPoint] = [pts[0]]
        var carry: CGFloat = 0
        var prev = pts[0]
        for p in pts.dropFirst() {
            var d = hypot(p.x - prev.x, p.y - prev.y)
            while carry + d >= step, out.count < n {
                let t = (step - carry) / d
                let q = CGPoint(x: prev.x + t * (p.x - prev.x),
                                y: prev.y + t * (p.y - prev.y))
                out.append(q)
                prev = q
                d = hypot(p.x - prev.x, p.y - prev.y)
                carry = 0
            }
            carry += d
            prev = p
        }
        while out.count < n { out.append(pts[pts.count - 1]) }
        return out
    }

    /// $P/$Q-style greedy cloud distance (Vatavu/Anthony/Wobbrock): points are
    /// matched as an unordered cloud, so start point and drawing direction
    /// don't matter by construction — no sample-order rotation hacks. A small
    /// geometric-rotation search (±30°) tolerates tilted drawings.
    private static func templateDistance(_ stroke: [CGPoint], _ template: [CGPoint]) -> CGFloat {
        func cloudDistance(_ a: [CGPoint], _ b: [CGPoint], start: Int) -> CGFloat {
            let n = a.count
            var matched = [Bool](repeating: false, count: n)
            var sum: CGFloat = 0
            var i = start
            repeat {
                var minD = CGFloat.greatestFiniteMagnitude
                var index = -1
                for j in 0..<n where !matched[j] {
                    let d = hypot(a[i].x - b[j].x, a[i].y - b[j].y)
                    if d < minD { minD = d; index = j }
                }
                if index >= 0 { matched[index] = true }
                let weight = 1 - CGFloat((i - start + n) % n) / CGFloat(n)
                sum += weight * minD
                i = (i + 1) % n
            } while i != start
            return sum
        }
        func greedyMatch(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
            let n = a.count
            let step = 8   // ⌊n^(1−ε)⌋ for n=64, ε=0.5
            var best = CGFloat.greatestFiniteMagnitude
            for start in stride(from: 0, to: n, by: step) {
                best = min(best, cloudDistance(a, b, start: start),
                                 cloudDistance(b, a, start: start))
            }
            return best / CGFloat(n)   // normalize by cloud size
        }
        var best = CGFloat.greatestFiniteMagnitude
        for degrees in [-30.0, -15, 0, 15, 30] {
            let r = CGFloat(degrees) * .pi / 180
            let rotated = stroke.map {
                CGPoint(x: $0.x * cos(r) - $0.y * sin(r),
                        y: $0.x * sin(r) + $0.y * cos(r))
            }
            best = min(best, greedyMatch(rotated, template))
        }
        return best
    }

    /// Best template match with its cloud distance — closed shapes feed the
    /// candidate scorer (which applies its own gate), open shapes gate here.
    private static func matchTemplate(_ pts: [CGPoint], in templates: [ShapeTemplate]) -> (points: [CGPoint], cloud: CGFloat)? {
        let norm = normalize(pts)
        var bestScore = CGFloat.greatestFiniteMagnitude
        var bestTemplate: ShapeTemplate?
        for t in templates {
            let d = templateDistance(norm, t.normalizedSamples)
            if d < bestScore { bestScore = d; bestTemplate = t }
        }
        // Calibrated for the cloud metric: noisy hearts score ~0.03, a 25°-
        // tilted heart ~0.04, a circle ~0.06, a lumpy blob ~0.09.
        guard let match = bestTemplate, bestScore < 0.06 else { return nil }

        // Emit the ideal outline scaled to the drawn bounding box.
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for p in pts {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let w = maxX - minX, h = maxY - minY
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        let outline = match.ideal.map { CGPoint(x: cx + $0.x * w, y: cy + $0.y * h) }
        return (outline, bestScore)
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

    /// Angle-based corner finding over a closed stroke (IStraw-style,
    /// Xiong & LaViola): corners are local minima of the turn angle that
    /// stay sharp as the measuring window shrinks — a real corner keeps its
    /// angle at any scale, while a smooth curve flattens toward 180° up
    /// close. This catches a star's obtuse inner corners (which ShortStraw's
    /// chord test missed, collapsing stars to just their tips) and rejects
    /// curve noise. Returns nil — "not a polygon at all" — unless every
    /// inter-corner segment passes a straight-line test, so circles and
    /// hearts can never come back polygonal.
    private static func polygonCorners(_ pts: [CGPoint]) -> [CGPoint]? {
        let r = resample(pts, to: 64)
        let n = r.count
        guard n >= 16 else { return nil }

        func angle(_ i: Int, _ k: Int) -> CGFloat {
            let a = r[(i - k + n) % n], b = r[(i + k) % n], p = r[i]
            let v1x = a.x - p.x, v1y = a.y - p.y
            let v2x = b.x - p.x, v2y = b.y - p.y
            let m = hypot(v1x, v1y) * hypot(v2x, v2y)
            guard m > 0.001 else { return .pi }
            return acos(max(-1, min(1, (v1x * v2x + v1y * v2y) / m)))
        }

        let sharp = 152 * CGFloat.pi / 180
        let sharpClose = 160 * CGFloat.pi / 180
        var idxs: [Int] = []
        for i in 0..<n {
            let a3 = angle(i, 3)
            guard a3 < sharp else { continue }
            // Local minimum of the wide-window angle.
            guard a3 <= angle((i - 1 + n) % n, 3), a3 < angle((i + 1) % n, 3) else { continue }
            // Multi-scale test: still sharp at the smaller window, or a curve.
            guard angle(i, 2) < sharpClose else { continue }
            idxs.append(i)
        }

        // Merge candidates closer than 4 samples (keep the sharper one),
        // including the wraparound pair.
        var merged: [Int] = []
        for i in idxs {
            if let last = merged.last, i - last < 4 {
                if angle(i, 3) < angle(last, 3) { merged[merged.count - 1] = i }
            } else {
                merged.append(i)
            }
        }
        if merged.count >= 2, let f = merged.first, let l = merged.last,
           (f + n - l) < 4 {
            if angle(f, 3) < angle(l, 3) { merged.removeLast() }
            else { merged.removeFirst() }
        }
        guard merged.count >= 3, merged.count <= 12 else { return nil }

        // Line test (the published ShortStraw post-process this file used to
        // skip): every segment between consecutive corners must be straight
        // (chord ≈ path). One curved side means the stroke isn't a polygon.
        for k in 0..<merged.count {
            let i = merged[k], j = merged[(k + 1) % merged.count]
            var path: CGFloat = 0
            var m = i
            while m != j {
                let next = (m + 1) % n
                path += hypot(r[next].x - r[m].x, r[next].y - r[m].y)
                m = next
            }
            let chord = hypot(r[j].x - r[i].x, r[j].y - r[i].y)
            if path > 12, chord / path < 0.92 { return nil }
        }
        return merged.map { r[$0] }
    }

    // MARK: templates

    struct ShapeTemplate {
        let name: String
        /// Ideal outline in a unit box centered on the origin (x, y ∈ −0.5…0.5).
        let ideal: [CGPoint]
        /// The same outline normalized like a stroke, for matching.
        let normalizedSamples: [CGPoint]

        init(name: String, ideal: [CGPoint]) {
            self.name = name
            self.ideal = ideal
            self.normalizedSamples = InkShapes.normalize(ideal)
        }
    }

    enum ShapeTemplates {
        /// Closed drawn shapes recognized by outline matching.
        static let closed: [ShapeTemplate] = [heart]
        /// Open drawn shapes (after the straight-line fit fails).
        static let open: [ShapeTemplate] = [arrow]

        /// The classic parametric heart, upright, unit box, y-down for screen.
        static let heart: ShapeTemplate = {
            var pts: [CGPoint] = []
            let n = 96
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n) * 2 * .pi
                let x = 16 * pow(sin(t), 3)
                let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
                pts.append(CGPoint(x: x / 34, y: -y / 34))   // ≈ unit box, y flipped
            }
            return ShapeTemplate(name: "heart", ideal: pts)
        }()

        /// A rightward arrow drawn as one stroke: shaft, then the head
        /// retraced (the way arrows are actually drawn without lifting).
        static let arrow: ShapeTemplate = {
            let outline: [CGPoint] = [
                CGPoint(x: -0.5, y: 0),
                CGPoint(x: 0.5, y: 0),
                CGPoint(x: 0.22, y: -0.2),
                CGPoint(x: 0.5, y: 0),
                CGPoint(x: 0.22, y: 0.2),
            ]
            // Densify each segment so matching and synthesis are smooth.
            var pts: [CGPoint] = []
            for i in 0..<outline.count - 1 {
                let a = outline[i], b = outline[i + 1]
                for s in 0..<12 {
                    let t = CGFloat(s) / 12
                    pts.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                }
            }
            pts.append(outline[outline.count - 1])
            return ShapeTemplate(name: "arrow", ideal: pts)
        }()
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
