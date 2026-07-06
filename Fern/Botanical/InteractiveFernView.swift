import SwiftUI
import MetalKit
import simd

/// The lock-screen fern you can push around. Falls back to the static flame
/// fern if Metal is unavailable. A short, near-stationary touch = tap (unlock);
/// a moving touch plays with the points.
struct InteractiveFernView: View {
    let fern: BarnsleyFern
    var tint: Color = Paper.accent
    var params: FernPhysicsParams = .defaults
    let onTap: () -> Void

    @StateObject private var model = InteractiveFernModel()
    @StateObject private var tuning = FernTuning()
    @State private var showLab = false
    private var metalAvailable: Bool { MTLCreateSystemDefaultDevice() != nil }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if metalAvailable {
                    FernParticleField(fern: fern, tint: UIColor(tint),
                                      tuning: tuning, touch: model.touch)
                } else {
                    FlameFernView(fern: fern, tint: tint, sway: true)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        model.began()
                        model.move(to: v.location)
                    }
                    .onEnded { v in
                        let moved = hypot(v.translation.width, v.translation.height)
                        let quick = model.wasQuick
                        model.end()
                        if moved < 10 && quick { onTap() }
                    }
            )

            #if DEBUG
            if showLab {
                FernLabPanel(tuning: tuning) { showLab = false }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif
        }
        .overlay(alignment: .topTrailing) { labToggle }
        .onAppear { tuning.params = params }
    }

    @ViewBuilder private var labToggle: some View {
        #if DEBUG
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showLab.toggle() }
        } label: {
            Image(systemName: showLab ? "slider.horizontal.3" : "wrench.adjustable")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Paper.inkSoft.opacity(0.5))
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #endif
    }
}

/// Bridges SwiftUI gesture values into the renderer's shared touch state.
/// Finger velocity is derived from successive positions (robust across SDKs).
final class InteractiveFernModel: ObservableObject {
    let touch = FernTouchState()
    private var startTime = CACurrentMediaTime()
    private var started = false
    private var lastPoint: CGPoint?
    private var lastMove = CACurrentMediaTime()
    var wasQuick: Bool { CACurrentMediaTime() - startTime < 0.35 }

    func began() {
        if !started {
            started = true
            startTime = CACurrentMediaTime()
            lastPoint = nil
        }
    }
    func move(to p: CGPoint) {
        let now = CACurrentMediaTime()
        if let last = lastPoint {
            let dt = max(1.0 / 240.0, now - lastMove)
            let vx = Float((p.x - last.x) / dt)
            let vy = Float((p.y - last.y) / dt)
            // light smoothing so the sweep force isn't jittery
            touch.fingerVel = 0.6 * touch.fingerVel + 0.4 * SIMD2<Float>(vx, vy)
        }
        lastPoint = p
        lastMove = now
        touch.finger = SIMD2<Float>(Float(p.x), Float(p.y))
        touch.touching = true
    }
    func end() {
        touch.touching = false
        touch.fingerVel = .zero
        started = false
        lastPoint = nil
    }
}
