# Interactive Touch-Responsive Fern — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the lock screen, running a finger over the fern pushes the points it's made of aside in the finger's wake; they flow back to rest with a soft, slightly overshooting spring. A quick tap still unlocks.

**Architecture:** A Metal particle field simulates ~800k points on the GPU (spring-to-home + damping + finger force), renders them as additive splats into a float texture, then tone-maps that density into the accent-tinted fern (matching `FlameFern`). Scoped to `LockGate`; all other fern surfaces keep the static renderer.

**Tech Stack:** Metal (compute + 2 render passes via `MTKView`), SwiftUI `UIViewRepresentable`, existing `BarnsleyFern` point cloud.

---

## File structure

- Create `Fern/Botanical/FernParticles.metal` — physics compute + splat + tonemap shaders.
- Create `Fern/Botanical/FernPhysics.swift` — shared `FernUniforms` struct + `FernPhysicsParams` defaults + pure-Swift `FernPhysicsStep` (unit-testable integrator mirror).
- Create `Fern/Botanical/FernParticleField.swift` — `FernParticleRenderer` (MTKViewDelegate) + `FernParticleField` (UIViewRepresentable).
- Create `Fern/Botanical/InteractiveFernView.swift` — SwiftUI wrapper: gesture, tap/drag classification, Metal-unavailable fallback.
- Modify `Fern/Views/LockGate.swift` — swap the veil fern to `InteractiveFernView`.
- Create `FernTests/FernPhysicsTests.swift` — integrator unit tests.

---

## Task 1: Physics types + CPU integrator (TDD)

**Files:**
- Create: `Fern/Botanical/FernPhysics.swift`
- Test: `FernTests/FernPhysicsTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// FernTests/FernPhysicsTests.swift
import XCTest
import simd
@testable import Fern

final class FernPhysicsTests: XCTestCase {
    private let p = FernPhysicsParams.defaults

    // A displaced point, untouched, moves back toward home.
    func testReturnsTowardHome() {
        let home = SIMD2<Float>(0, 0)
        var pos = SIMD2<Float>(50, 0)
        var vel = SIMD2<Float>(0, 0)
        for _ in 0..<20 {
            (pos, vel) = FernPhysicsStep.step(pos: pos, vel: vel, home: home,
                finger: .zero, touching: false, params: p, dt: 1.0/120)
        }
        XCTAssertLessThan(abs(pos.x), 50, "should have moved back toward home")
    }

    // Energy decays: after long settling, it's essentially at rest at home.
    func testSettlesAtHome() {
        let home = SIMD2<Float>(10, -5)
        var pos = SIMD2<Float>(120, 90)
        var vel = SIMD2<Float>(0, 0)
        for _ in 0..<2000 {
            (pos, vel) = FernPhysicsStep.step(pos: pos, vel: vel, home: home,
                finger: .zero, touching: false, params: p, dt: 1.0/120)
        }
        XCTAssertLessThan(distance(pos, home), 0.5)
        XCTAssertLessThan(length(vel), 0.5)
    }

    // Underdamped: it overshoots home at least once (crosses to the far side).
    func testUnderdampedOvershoots() {
        var soft = FernPhysicsParams.defaults
        soft.springK = 220; soft.damping = 1.2   // lively, low damping
        soft.globalDamp = 1.0
        let home = SIMD2<Float>(0, 0)
        var pos = SIMD2<Float>(40, 0)
        var vel = SIMD2<Float>(0, 0)
        var overshot = false
        for _ in 0..<400 {
            (pos, vel) = FernPhysicsStep.step(pos: pos, vel: vel, home: home,
                finger: .zero, touching: false, params: soft, dt: 1.0/120)
            if pos.x < -0.5 { overshot = true; break }
        }
        XCTAssertTrue(overshot, "an underdamped spring should overshoot home")
    }

    // A touching finger pushes a nearby point away from the finger.
    func testFingerPushesAway() {
        var params = FernPhysicsParams.defaults
        let home = SIMD2<Float>(0, 0)
        var pos = SIMD2<Float>(0, 0)         // sitting at home, finger just left of it
        var vel = SIMD2<Float>(0, 0)
        let finger = SIMD2<Float>(-8, 0)     // within radius
        (pos, vel) = FernPhysicsStep.step(pos: pos, vel: vel, home: home,
            finger: finger, touching: true, params: params, dt: 1.0/120)
        XCTAssertGreaterThan(vel.x, 0, "point should be shoved to the right, away from finger")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild -project Fern.xcodeproj -scheme Fern -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:FernTests/FernPhysicsTests`
Expected: FAIL — `FernPhysicsStep` / `FernPhysicsParams` not defined.

- [ ] **Step 3: Implement `FernPhysics.swift`**

```swift
// Fern/Botanical/FernPhysics.swift
import simd
import CoreGraphics

/// Tunable feel constants for the interactive fern. Shared by the CPU mirror
/// (tests) and the GPU (packed into `FernUniforms`).
struct FernPhysicsParams {
    var springK: Float        // pull back toward home
    var damping: Float        // velocity damping (per-force)
    var globalDamp: Float     // per-step velocity multiplier (stability)
    var fingerRadius: Float   // points; influence radius of the finger
    var pushStrength: Float   // radial shove away from finger
    var dragCoupling: Float   // how much the finger's motion sweeps points
    var pointSize: Float      // px splat diameter
    var toneGamma: Float      // matches FlameFern
    var toneFloor: Float      // matches FlameFern
    var densityDenom: Float   // log-density normalizer (tuned for the point count)

    static let defaults = FernPhysicsParams(
        springK: 120, damping: 6, globalDamp: 0.985,
        fingerRadius: 90, pushStrength: 26000, dragCoupling: 2.2,
        pointSize: 2.2, toneGamma: 2.3, toneFloor: 0.55, densityDenom: 5.2)
}

/// Pure integrator for one point, one step. The Metal `fern_physics` kernel is a
/// line-for-line port of this — keep them in sync.
enum FernPhysicsStep {
    static func step(pos: SIMD2<Float>, vel: SIMD2<Float>, home: SIMD2<Float>,
                     finger: SIMD2<Float>, touching: Bool,
                     params p: FernPhysicsParams, dt: Float)
    -> (SIMD2<Float>, SIMD2<Float>) {
        var v = vel
        var F = p.springK * (home - pos) - p.damping * v
        if touching {
            let d = pos - finger
            let r = simd_length(d)
            if r < p.fingerRadius && r > 1e-4 {
                var fall = 1 - r / p.fingerRadius
                fall = fall * fall * (3 - 2 * fall)     // smoothstep
                F += p.pushStrength * fall * (d / r)
                // fingerVel is folded into `finger` motion at the call site for
                // the GPU; the CPU mirror models the radial shove only.
            }
        }
        v += F * dt
        v *= p.globalDamp
        let np = pos + v * dt
        return (np, v)
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: same as Step 2.
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Fern/Botanical/FernPhysics.swift FernTests/FernPhysicsTests.swift
git commit -m "Fern: physics params + CPU integrator for interactive fern (TDD)"
```

---

## Task 2: Metal shaders

**Files:**
- Create: `Fern/Botanical/FernParticles.metal`

- [ ] **Step 1: Write the shader file**

```metal
// Fern/Botanical/FernParticles.metal
#include <metal_stdlib>
using namespace metal;

struct FernUniforms {
    float4 tint;        // accent rgb (a unused)
    float2 viewSize;    // points
    float2 finger;      // points
    float2 fingerVel;   // points/sec
    float  dt;
    float  touching;    // 0/1
    float  springK;
    float  damping;
    float  globalDamp;
    float  fingerRadius;
    float  pushStrength;
    float  dragCoupling;
    float  pointSize;   // px
    float  toneGamma;
    float  toneFloor;
    float  densityDenom;
};

// --- Physics: one step per point (port of FernPhysicsStep.step) ---
kernel void fern_physics(device float2*        pos      [[buffer(0)]],
                         device float2*        vel      [[buffer(1)]],
                         const device float2*  home     [[buffer(2)]],
                         constant FernUniforms& U        [[buffer(3)]],
                         uint id [[thread_position_in_grid]],
                         constant uint& count [[buffer(4)]]) {
    if (id >= count) return;
    float2 p = pos[id];
    float2 v = vel[id];
    float2 F = U.springK * (home[id] - p) - U.damping * v;
    if (U.touching > 0.5) {
        float2 d = p - U.finger;
        float r = length(d);
        if (r < U.fingerRadius && r > 1e-4) {
            float fall = 1.0 - r / U.fingerRadius;
            fall = fall * fall * (3.0 - 2.0 * fall);          // smoothstep
            F += U.pushStrength * fall * (d / r);             // shove away
            F += U.dragCoupling * fall * U.fingerVel;         // sweep with finger
        }
    }
    v += F * U.dt;
    v *= U.globalDamp;
    p += v * U.dt;
    pos[id] = p;
    vel[id] = v;
}

// --- Splat: draw each point as an additive round sprite into accum texture ---
struct SplatOut {
    float4 position [[position]];
    float  psize    [[point_size]];
};

vertex SplatOut fern_splat_v(const device float2* pos [[buffer(0)]],
                             constant FernUniforms& U  [[buffer(1)]],
                             uint vid [[vertex_id]]) {
    float2 p = pos[vid];
    float2 ndc = float2((p.x / U.viewSize.x) * 2.0 - 1.0,
                        1.0 - (p.y / U.viewSize.y) * 2.0);   // flip y
    SplatOut o;
    o.position = float4(ndc, 0.0, 1.0);
    o.psize = U.pointSize;
    return o;
}

fragment float4 fern_splat_f(float2 pc [[point_coord]]) {
    float2 q = pc - 0.5;
    float d2 = dot(q, q);
    if (d2 > 0.25) discard_fragment();
    float a = smoothstep(0.25, 0.0, d2);   // soft round core
    return float4(a, 0.0, 0.0, 0.0);       // density accumulates in .r (additive)
}

// --- Tonemap: density -> premultiplied accent over transparent paper ---
struct FSOut { float4 position [[position]]; float2 uv; };

vertex FSOut fern_fullscreen_v(uint vid [[vertex_id]]) {
    float2 p[3] = { float2(-1,-1), float2(3,-1), float2(-1,3) };
    FSOut o;
    o.position = float4(p[vid], 0, 1);
    o.uv = (p[vid] * 0.5 + 0.5);
    o.uv.y = 1.0 - o.uv.y;
    return o;
}

fragment float4 fern_tonemap_f(FSOut in [[stage_in]],
                               texture2d<float> accum [[texture(0)]],
                               constant FernUniforms& U [[buffer(0)]]) {
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge);
    float D = accum.sample(s, in.uv).r;
    if (D < 0.0025) return float4(0.0);
    float base = pow(clamp(log(1.0 + D) / U.densityDenom, 0.0, 1.0), 1.0 / U.toneGamma);
    float t = U.toneFloor + (1.0 - U.toneFloor) * base;
    return float4(U.tint.rgb * t, t);      // premultiplied
}
```

- [ ] **Step 2: Commit** (compiles as part of Task 4 build)

```bash
git add Fern/Botanical/FernParticles.metal
git commit -m "Fern: Metal shaders for interactive fern (physics, splat, tonemap)"
```

---

## Task 3: Renderer + representable

**Files:**
- Create: `Fern/Botanical/FernParticleField.swift`

- [ ] **Step 1: Implement the renderer and UIViewRepresentable**

```swift
// Fern/Botanical/FernParticleField.swift
import SwiftUI
import MetalKit
import simd

/// Mutable touch state shared from SwiftUI into the renderer each frame.
final class FernTouchState {
    var finger = SIMD2<Float>(0, 0)
    var fingerVel = SIMD2<Float>(0, 0)
    var touching = false
}

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

    private let fern: BarnsleyFern
    private let params: FernPhysicsParams
    private let tint: SIMD4<Float>
    let touch: FernTouchState

    private var homeBuf, posBuf, velBuf: MTLBuffer!
    private var count: UInt32 = 0
    private var accum: MTLTexture!
    private var builtSize: CGSize = .zero
    private var lastTime = CACurrentMediaTime()

    init?(fern: BarnsleyFern, tint: UIColor, params: FernPhysicsParams, touch: FernTouchState) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let lib = device.makeDefaultLibrary() else { return nil }
        self.device = device; self.queue = queue
        self.fern = fern; self.params = params; self.touch = touch
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        tint.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.tint = SIMD4<Float>(Float(r), Float(g), Float(b), 1)

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
        let xs = max(0.001, fern.maxX - fern.minX)
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
        memset(velBuf.contents(), 0, len)
        _ = xs
        builtSize = size
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let td = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r16Float, width: max(1, Int(size.width)),
            height: max(1, Int(size.height)), mipmapped: false)
        td.usage = [.renderTarget, .shaderRead]
        td.storageMode = .private
        accum = device.makeTexture(descriptor: td)
        let pointSize = CGSize(width: size.width / view.contentScaleFactor,
                               height: size.height / view.contentScaleFactor)
        build(for: pointSize)
    }

    private func uniforms(viewSize: CGSize, dt: Float) -> FernUniforms {
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
        u.pointSize = params.pointSize * Float(1)   // px
        u.toneGamma = params.toneGamma; u.toneFloor = params.toneFloor
        u.densityDenom = params.densityDenom
        return u
    }

    func draw(in view: MTKView) {
        guard let accum, homeBuf != nil, count > 0,
              let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer() else { return }

        let now = CACurrentMediaTime()
        let dt = Float(min(1.0 / 30.0, max(1.0 / 240.0, now - lastTime)))
        lastTime = now
        let ptSize = CGSize(width: view.bounds.width, height: view.bounds.height)
        var u = uniforms(viewSize: ptSize, dt: dt)
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
    let params: FernPhysicsParams
    let touch: FernTouchState

    func makeCoordinator() -> FernParticleRenderer? {
        FernParticleRenderer(fern: fern, tint: tint, params: params, touch: touch)
    }

    func makeUIView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.colorPixelFormat = .bgra8Unorm
        v.framebufferOnly = false
        v.isOpaque = false
        v.backgroundColor = .clear
        v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        v.enableSetNeedsDisplay = false
        v.isPaused = false
        v.preferredFramesPerSecond = 120
        v.delegate = context.coordinator
        v.isUserInteractionEnabled = false   // SwiftUI handles the gesture
        return v
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}
```

- [ ] **Step 2: Commit** (build verified in Task 5)

```bash
git add Fern/Botanical/FernParticleField.swift
git commit -m "Fern: Metal particle renderer + UIViewRepresentable"
```

---

## Task 4: Interactive SwiftUI view + gesture

**Files:**
- Create: `Fern/Botanical/InteractiveFernView.swift`

- [ ] **Step 1: Implement the view**

```swift
// Fern/Botanical/InteractiveFernView.swift
import SwiftUI
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
    private var metalAvailable: Bool { MTLCreateSystemDefaultDevice() != nil }

    var body: some View {
        GeometryReader { geo in
            Group {
                if metalAvailable {
                    FernParticleField(fern: fern, tint: UIColor(tint),
                                      params: params, touch: model.touch)
                } else {
                    FlameFernView(fern: fern, tint: tint, sway: true)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in model.began(at: v.startLocation)
                        model.move(to: v.location, velocity: v.velocity) }
                    .onEnded { v in
                        let moved = hypot(v.translation.width, v.translation.height)
                        model.end()
                        if moved < 10 && model.wasQuick { onTap() }
                    }
            )
        }
    }
}

/// Bridges SwiftUI gesture values into the renderer's shared touch state.
final class InteractiveFernModel: ObservableObject {
    let touch = FernTouchState()
    private var startTime = CACurrentMediaTime()
    private var started = false
    var wasQuick: Bool { CACurrentMediaTime() - startTime < 0.35 }

    func began(at p: CGPoint) {
        if !started { started = true; startTime = CACurrentMediaTime() }
    }
    func move(to p: CGPoint, velocity: CGSize) {
        touch.finger = SIMD2<Float>(Float(p.x), Float(p.y))
        touch.fingerVel = SIMD2<Float>(Float(velocity.width), Float(velocity.height))
        touch.touching = true
    }
    func end() {
        touch.touching = false
        touch.fingerVel = .zero
        started = false
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Fern/Botanical/InteractiveFernView.swift
git commit -m "Fern: InteractiveFernView with tap/drag classification + fallback"
```

---

## Task 5: Wire into LockGate + build

**Files:**
- Modify: `Fern/Views/LockGate.swift` (the veil `VStack`)

- [ ] **Step 1: Replace the fern view in the veil**

In `Fern/Views/LockGate.swift`, replace:

```swift
                FlameFernView(fern: fern, sway: true)
                    .frame(maxWidth: 360)
                    .frame(height: 460)
                    .scaleEffect(pulse ? 1.04 : 1.0)
                    .offset(x: shakeX)
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await reactAndUnlock() } }
```

with:

```swift
                InteractiveFernView(fern: fern, tint: Paper.accent) {
                    Task { await reactAndUnlock() }
                }
                    .frame(maxWidth: 360)
                    .frame(height: 460)
                    .scaleEffect(pulse ? 1.04 : 1.0)
                    .offset(x: shakeX)
```

- [ ] **Step 2: Regenerate project (picks up the new .metal + swift files)**

Run: `cd "/Volumes/Akasha Terminal/Pressed" && xcodegen generate`
Expected: "Created project at …/Fern.xcodeproj"

- [ ] **Step 3: Build for the device**

Run: `xcodebuild -project Fern.xcodeproj -scheme Fern -destination 'generic/platform=iOS' -derivedDataPath "/Volumes/Akasha Terminal/XcodeBuild/DerivedData/Fern" -allowProvisioningUpdates build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run the unit tests on the simulator**

Run: `xcodebuild -project Fern.xcodeproj -scheme Fern -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:FernTests/FernPhysicsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Fern/Views/LockGate.swift Fern.xcodeproj
git commit -m "Fern: interactive touch-responsive fern on the lock screen"
```

---

## Task 6: Install to iPhone 17 Pro Max + on-device feel test

- [ ] **Step 1: Install** to device `8507BF1B-8ED0-53A9-A03C-662B9BC6D9E4` (iPhone 17 Pro Max):

```bash
xcrun devicectl device install app --device 8507BF1B-8ED0-53A9-A03C-662B9BC6D9E4 \
  "/Volumes/Akasha Terminal/XcodeBuild/DerivedData/Fern/Build/Products/Debug-iphoneos/Fern.app"
```
Expected: `App installed`.

- [ ] **Step 2: Device feel test (user).** Lock the app, drag across the fern.
  Confirm: at rest it matches today's fern; dragging sweeps points aside; they
  spring back with a soft wobble; a tap still unlocks. Note any tuning wanted
  (bounciness = `springK`/`damping`; wake size = `fingerRadius`/`pushStrength`;
  darkness = `toneFloor`/`densityDenom`).

- [ ] **Step 3: Push** once feel is confirmed:

```bash
git push
```

---

## Notes for the implementer

- `DragGesture.Value.velocity` requires iOS 17+ (the app targets newer). It is
  the finger's instantaneous velocity in points/sec — feeds the "sweep."
- The CPU integrator (`FernPhysicsStep`) and the Metal `fern_physics` kernel are
  intentional duplicates; if you change one, change both. The tests guard the
  CPU one.
- `densityDenom` (default 5.2) is the live-render analog of `FlameFern`'s
  `log(1+maxH)`. If the resting fern looks too dark, raise it; too light, lower
  it. Tune on device.
- Only `LockGate` uses this. Do not touch `FlameFernView` usages elsewhere.
```
