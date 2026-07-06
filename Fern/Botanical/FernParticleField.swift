import SwiftUI
import MetalKit
import simd

/// Mutable touch state shared from SwiftUI into the renderer each frame.
final class FernTouchState {
    var finger = SIMD2<Float>(0, 0)
    var fingerVel = SIMD2<Float>(0, 0)
    var touching = false
    /// When the finger last moved. The renderer uses this both to time out a
    /// cancelled gesture (SwiftUI never calls onEnded on cancellation — the
    /// fern would stay deformed forever) and to idle the render loop.
    var lastTouch: CFTimeInterval = 0
}

/// Live-tunable physics params. The renderer reads `.params` every frame, so the
/// dev panel (FernLab) can dial the feel without a rebuild. A tuning session
/// persists across launches (UserDefaults) so dialing-in survives a relock.
final class FernTuning: ObservableObject {
    private static let storageKey = "fern.lab.params"

    @Published var params: FernPhysicsParams {
        didSet {
            guard params != oldValue else { return }
            if params == .defaults {
                UserDefaults.standard.removeObject(forKey: Self.storageKey)
            } else if let data = try? JSONEncoder().encode(params) {
                UserDefaults.standard.set(data, forKey: Self.storageKey)
            }
        }
    }

    init(_ params: FernPhysicsParams = .defaults) {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(FernPhysicsParams.self, from: data) {
            self.params = saved
        } else {
            self.params = params
        }
    }
}

/// Packed constants handed to every shader. Field order + types must match the
/// `FernUniforms` struct in FernParticles.metal exactly.
private struct FernUniforms {
    var tint = SIMD4<Float>(0, 0, 0, 1)
    var viewSize = SIMD2<Float>(1, 1)
    var finger = SIMD2<Float>(0, 0)
    var fingerVel = SIMD2<Float>(0, 0)
    var dt: Float = 1.0 / 120
    var touching: Float = 0
    var springK: Float = 0
    var damping: Float = 0
    var globalDamp: Float = 0
    var fingerRadius: Float = 0
    var pushStrength: Float = 0
    var dragCoupling: Float = 0
    var pointSize: Float = 0
    var toneGamma: Float = 0
    var toneFloor: Float = 0
    var densityDenom: Float = 0
}

final class FernParticleRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let physics: MTLComputePipelineState
    private let splat: MTLRenderPipelineState
    private let tonemap: MTLRenderPipelineState

    private var fern: BarnsleyFern
    private var fernKey: String
    private let tuning: FernTuning
    private var tint: SIMD4<Float>
    let touch: FernTouchState
    /// When the sim was last disturbed — drives the idle throttle.
    private var lastActive = CACurrentMediaTime()

    private var homeBuf: MTLBuffer?
    private var posBuf: MTLBuffer?
    private var velBuf: MTLBuffer?
    private var count: UInt32 = 0
    private var accum: MTLTexture?
    private var lastTime = CACurrentMediaTime()

    private static func key(of fern: BarnsleyFern) -> String {
        "\(fern.points.count)-\(fern.maxY)-\(fern.minX)-\(fern.maxX)"
    }

    private static func resolve(_ tint: UIColor) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        tint.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), 1)
    }

    init?(fern: BarnsleyFern, tint: UIColor, tuning: FernTuning, touch: FernTouchState) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let lib = device.makeDefaultLibrary() else { return nil }
        self.device = device; self.queue = queue
        self.fern = fern; self.fernKey = Self.key(of: fern)
        self.tuning = tuning; self.touch = touch
        self.tint = Self.resolve(tint)

        guard let kf = lib.makeFunction(name: "fern_physics"),
              let sv = lib.makeFunction(name: "fern_splat_v"),
              let sf = lib.makeFunction(name: "fern_splat_f"),
              let fv = lib.makeFunction(name: "fern_fullscreen_v"),
              let tf = lib.makeFunction(name: "fern_tonemap_f"),
              let physics = try? device.makeComputePipelineState(function: kf)
        else { return nil }
        self.physics = physics

        let sd = MTLRenderPipelineDescriptor()
        sd.vertexFunction = sv; sd.fragmentFunction = sf
        sd.colorAttachments[0].pixelFormat = .r16Float
        sd.colorAttachments[0].isBlendingEnabled = true
        sd.colorAttachments[0].rgbBlendOperation = .add
        sd.colorAttachments[0].alphaBlendOperation = .add
        sd.colorAttachments[0].sourceRGBBlendFactor = .one
        sd.colorAttachments[0].destinationRGBBlendFactor = .one
        sd.colorAttachments[0].sourceAlphaBlendFactor = .one
        sd.colorAttachments[0].destinationAlphaBlendFactor = .one
        guard let splat = try? device.makeRenderPipelineState(descriptor: sd) else { return nil }
        self.splat = splat

        let td = MTLRenderPipelineDescriptor()
        td.vertexFunction = fv; td.fragmentFunction = tf
        td.colorAttachments[0].pixelFormat = .bgra8Unorm
        td.colorAttachments[0].isBlendingEnabled = true
        td.colorAttachments[0].rgbBlendOperation = .add
        td.colorAttachments[0].alphaBlendOperation = .add
        td.colorAttachments[0].sourceRGBBlendFactor = .one
        td.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        td.colorAttachments[0].sourceAlphaBlendFactor = .one
        td.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        guard let tonemap = try? device.makeRenderPipelineState(descriptor: td) else { return nil }
        self.tonemap = tonemap
        super.init()
    }

    /// Map the fern's points into `size` (points), base at the bottom, centered.
    private func build(for size: CGSize) {
        let pts = fern.points
        guard !pts.isEmpty, size.width > 1, size.height > 1 else { return }
        let ys = max(0.001, fern.maxY)
        let pad = 0.06
        let s = Double(size.height) * (1 - 2 * pad) / ys
        let ox = Double(size.width) / 2 - ((fern.maxX + fern.minX) / 2) * s
        let bottom = Double(size.height) * (1 - pad)
        var homes = [SIMD2<Float>](); homes.reserveCapacity(pts.count)
        for p in pts {
            homes.append(SIMD2<Float>(Float(ox + p.x * s), Float(bottom - p.y * s)))
        }
        count = UInt32(homes.count)
        let len = homes.count * MemoryLayout<SIMD2<Float>>.stride
        homeBuf = device.makeBuffer(bytes: homes, length: len)
        posBuf = device.makeBuffer(bytes: homes, length: len)          // start at rest
        velBuf = device.makeBuffer(length: len, options: .storageModeShared)
        if let vb = velBuf { memset(vb.contents(), 0, len) }
    }

    /// Adopt a new fern (relock regenerates one while the veil is still up) or
    /// a re-resolved tint (dark-mode flip) without recreating the renderer.
    func update(fern: BarnsleyFern, tint: UIColor, view: MTKView) {
        self.tint = Self.resolve(tint)
        let key = Self.key(of: fern)
        if key != fernKey {
            self.fern = fern
            fernKey = key
            build(for: view.bounds.size)
            lastActive = CACurrentMediaTime()
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let td = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r16Float, width: Int(size.width),
            height: Int(size.height), mipmapped: false)
        td.usage = [.renderTarget, .shaderRead]
        td.storageMode = .private
        accum = device.makeTexture(descriptor: td)
        let scale = max(1, view.contentScaleFactor)
        build(for: CGSize(width: size.width / scale, height: size.height / scale))
    }

    private func uniforms(viewSize: CGSize, dt: Float) -> FernUniforms {
        let params = tuning.params
        var u = FernUniforms()
        u.tint = tint
        u.viewSize = SIMD2<Float>(Float(viewSize.width), Float(viewSize.height))
        u.finger = touch.finger
        u.fingerVel = touch.fingerVel
        u.dt = dt
        u.touching = touch.touching ? 1 : 0
        u.springK = params.springK; u.damping = params.damping
        u.globalDamp = params.globalDamp; u.fingerRadius = params.fingerRadius
        u.pushStrength = params.pushStrength; u.dragCoupling = params.dragCoupling
        u.pointSize = params.pointSize
        u.toneGamma = params.toneGamma; u.toneFloor = params.toneFloor
        u.densityDenom = params.densityDenom
        return u
    }

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()

        // A cancelled gesture (call, alert) never gets onEnded — without this
        // timeout the finger force would pin the fern deformed forever.
        if touch.touching && now - touch.lastTouch > 0.8 {
            touch.touching = false
            touch.fingerVel = .zero
        }
        if touch.touching { lastActive = now }

        // Idle throttle: at rest the sim is pixel-identical frame to frame —
        // rendering an 800k-point pipeline at 120fps while the gate sits idle
        // was pure battery burn. Give the physics ~4s to settle after the last
        // touch, then stop presenting (the last drawable stays on screen) and
        // drop the callback rate to a heartbeat.
        let active = now - lastActive < 4
        view.preferredFramesPerSecond = active ? 120 : 10
        guard active else { lastTime = now; return }

        guard let accum, let posBuf, let velBuf, let homeBuf, count > 0,
              let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer() else { return }

        let dt = Float(min(1.0 / 30.0, max(1.0 / 240.0, now - lastTime)))
        lastTime = now
        var u = uniforms(viewSize: view.bounds.size, dt: dt)
        // pointSize is a pixel quantity; keep the splat's physical size constant
        // across 2x/3x screens (params are calibrated at 3x). This also keeps
        // per-pixel density roughly scale-invariant, so the tone map matches.
        u.pointSize *= Float(max(1, view.contentScaleFactor) / 3)
        var cnt = count

        // 1. physics
        if let ce = cmd.makeComputeCommandEncoder() {
            ce.setComputePipelineState(physics)
            ce.setBuffer(posBuf, offset: 0, index: 0)
            ce.setBuffer(velBuf, offset: 0, index: 1)
            ce.setBuffer(homeBuf, offset: 0, index: 2)
            ce.setBytes(&u, length: MemoryLayout<FernUniforms>.stride, index: 3)
            ce.setBytes(&cnt, length: MemoryLayout<UInt32>.stride, index: 4)
            let w = physics.threadExecutionWidth
            ce.dispatchThreads(MTLSize(width: Int(count), height: 1, depth: 1),
                               threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
            ce.endEncoding()
        }

        // 2. splat -> accum
        let apd = MTLRenderPassDescriptor()
        apd.colorAttachments[0].texture = accum
        apd.colorAttachments[0].loadAction = .clear
        apd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        apd.colorAttachments[0].storeAction = .store
        if let re = cmd.makeRenderCommandEncoder(descriptor: apd) {
            re.setRenderPipelineState(splat)
            re.setVertexBuffer(posBuf, offset: 0, index: 0)
            re.setVertexBytes(&u, length: MemoryLayout<FernUniforms>.stride, index: 1)
            re.drawPrimitives(type: .point, vertexStart: 0, vertexCount: Int(count))
            re.endEncoding()
        }

        // 3. tonemap -> drawable
        if let re = cmd.makeRenderCommandEncoder(descriptor: rpd) {
            re.setRenderPipelineState(tonemap)
            re.setFragmentTexture(accum, index: 0)
            re.setFragmentBytes(&u, length: MemoryLayout<FernUniforms>.stride, index: 0)
            re.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            re.endEncoding()
        }
        cmd.present(drawable)
        cmd.commit()
    }
}

struct FernParticleField: UIViewRepresentable {
    let fern: BarnsleyFern
    let tint: UIColor
    let tuning: FernTuning
    let touch: FernTouchState
    /// True when the scene isn't active — stops the render loop entirely.
    var paused = false

    func makeCoordinator() -> FernParticleRenderer? {
        FernParticleRenderer(fern: fern, tint: tint, tuning: tuning, touch: touch)
    }

    func makeUIView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.colorPixelFormat = .bgra8Unorm
        v.framebufferOnly = true             // drawable is never sampled
        v.isOpaque = false
        v.backgroundColor = .clear
        v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        v.enableSetNeedsDisplay = false
        v.isPaused = false
        v.preferredFramesPerSecond = 120     // renderer throttles itself when idle
        v.delegate = context.coordinator
        v.isUserInteractionEnabled = false   // SwiftUI handles the gesture
        return v
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.isPaused = paused
        // Adopt a regenerated fern (relock while the veil is up) or a
        // re-resolved tint without recreating the renderer.
        context.coordinator?.update(fern: fern, tint: tint, view: uiView)
    }
}
