import SwiftUI

/// A coiled fiddlehead that can uncoil into a stem with leaflets.
/// `unfurl` ∈ [0,1] is animatable: 0 = fully coiled, 1 = open.
struct FiddleheadShape: Shape {
    var unfurl: Double

    var animatableData: Double {
        get { unfurl }
        set { unfurl = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let baseY = rect.maxY * 0.95
        let coilCenter = CGPoint(x: cx, y: rect.minY + rect.height * 0.32)

        // Spiral parameters
        let a = rect.width * 0.07
        let b = 0.18
        let turns = 3.0
        let thetaMax = 2 * .pi * turns
        // As unfurl grows, the coil consumes fewer turns; the rest becomes stem length.
        let visibleCoilTheta = thetaMax * (1.0 - unfurl)
        let stemLength = (baseY - coilCenter.y) * unfurl

        // Stem — straight line from base up to where the coil begins.
        p.move(to: CGPoint(x: cx, y: baseY))
        p.addLine(to: CGPoint(x: cx, y: baseY - stemLength))

        // Coil — sample the spiral inside-out.
        if visibleCoilTheta > 0 {
            let stepCount = 80
            for i in 0...stepCount {
                let t = Double(i) / Double(stepCount)
                let theta = visibleCoilTheta * t
                let r = a * exp(b * theta)
                let x = coilCenter.x + cos(theta) * r
                let y = (baseY - stemLength) + sin(theta) * r
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
        }

        // Leaflets sketched along the stem as it opens (only visible when unfurled).
        if unfurl > 0.4 {
            let leafletReveal = min(1.0, (unfurl - 0.4) / 0.6)
            let nLeaflets = 6
            for i in 0..<nLeaflets {
                let f = (Double(i) + 0.5) / Double(nLeaflets)
                if f > leafletReveal { break }
                let lx = cx
                let ly = baseY - stemLength * f
                let leafW = rect.width * 0.12 * (1 - f * 0.5)
                let side: CGFloat = (i % 2 == 0) ? 1 : -1
                let tip = CGPoint(x: lx + side * leafW, y: ly - leafW * 0.4)
                p.move(to: CGPoint(x: lx, y: ly))
                p.addQuadCurve(to: tip,
                               control: CGPoint(x: lx + side * leafW * 0.4,
                                                y: ly - leafW * 0.15))
            }
        }

        return p
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach([0.0, 0.5, 1.0], id: \.self) { v in
            FiddleheadShape(unfurl: v)
                .stroke(Paper.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 180, height: 240)
        }
    }
    .padding()
    .background(Paper.bg)
}
