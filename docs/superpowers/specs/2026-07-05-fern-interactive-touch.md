# Fern — Interactive touch-responsive lock-screen fern

**Date:** 2026-07-05
**Status:** Design approved (pending spec review)
**Scope:** The lock-screen (LockGate) fern only.

## Goal

When you run a finger across the fern on the lock screen, it responds like a
physical thing: the points it's made of are pushed aside in the finger's wake
and then flow back to rest with a soft, slightly overshooting spring. At rest it
looks identical to today's flame fern. A quick tap still unlocks the app.

Chosen interpretation (from the user): **points scatter & flow back** — the
fern's ~800k Barnsley points become a particle field with per-point physics. Not
per-frond skeletal bending, not an image warp.

## Why Metal

The scatter effect depends on the *dense* point cloud — reducing to a few
thousand CPU-simulated points stops reading as a fern. ~800k particles with
per-frame physics + rendering is only real-time on the GPU. Metal is therefore a
new (approved) subsystem. Additive GPU blending also reproduces the flame
look natively: overlapping points accumulate density = brightness, which is the
live-rendering equivalent of the CPU log-density tone map in `FlameFern`.

## Architecture

Interactivity is scoped to `LockGate`. All other fern surfaces (onboarding,
streak flourish, library empty state, share card / `PaperCard`) keep the
existing static `FlameFernView` / `FlameFern.image` and are untouched.

### Components

1. **`Fern/Botanical/FernParticles.metal`** — three shaders:
   - `fern_physics` (compute): integrate one physics step per point.
   - `fern_splat` (vertex + fragment): draw each point as a small additive,
     accent-tinted sprite into an offscreen float/accumulation texture.
   - `fern_tonemap` (fullscreen fragment): map accumulated density → the paper-
     composited accent color using the same gamma/floor curve as `FlameFern`.

2. **`Fern/Botanical/FernParticleField.swift`** — `UIViewRepresentable`
   wrapping an `MTKView` and an `FernParticleRenderer` (`MTKViewDelegate`).
   Owns the GPU state and pipelines. Public inputs:
   - `homePoints: [SIMD2<Float>]` — the fern's rest positions (from
     `BarnsleyFern.points`, mapped into the view's coordinate space).
   - `tint: UIColor`
   - touch state: current finger position + velocity in view space, and a
     `touching` flag (set by the SwiftUI layer).
   - `params: FernPhysicsParams` — the tunable feel constants (below).

3. **`Fern/Botanical/InteractiveFernView.swift`** — SwiftUI view that composes
   `FernParticleField` with a paper background sizing, runs the gesture, and
   distinguishes tap from drag:
   - `DragGesture(minimumDistance: 0)` updates finger position/velocity and sets
     `touching = true`; `.onEnded` sets `touching = false`.
   - **Tap vs. drag:** on `.onEnded`, if total translation < ~10 pt and duration
     < ~0.3 s, treat as a tap and call `onTap()` (the existing unlock path).
     Otherwise it was play; do nothing (the field springs back on its own).
   - Public API: `InteractiveFernView(fern: BarnsleyFern, tint:, onTap: () -> Void)`.

4. **`Fern/Views/LockGate.swift`** — replace the veil's
   `FlameFernView(fern: fern, sway: true)` with
   `InteractiveFernView(fern: fern) { Task { await reactAndUnlock() } }`.
   The existing pulse/shake/dissolve and `reactAndUnlock()` logic is reused
   verbatim; only the fern view and its tap wiring change. The whole-image
   `sway` is dropped (the physics idle can carry a faint drift instead; see
   Feel). Fern regeneration on relock is unchanged.

### Data flow (per frame, on the GPU)

```
finger(pos, vel, touching) ─┐
homeBuf, posBuf, velBuf ────┼─▶ fern_physics (compute) ─▶ updates posBuf, velBuf
                            │
posBuf ─▶ fern_splat (additive) ─▶ accumTexture(float) ─▶ fern_tonemap ─▶ drawable
```

Buffers are `MTLBuffer`s of `SIMD2<Float>` (home, pos) and `SIMD2<Float>`
(vel), length = point count. At ~800k points that's ~6.4 MB each (~19 MB
total) — trivial on the target devices.

## Physics model (per point, in `fern_physics`)

Semi-implicit (symplectic) Euler with a fixed substep. For point with home `h`,
position `p`, velocity `v`, finger `f` with finger velocity `u`:

```
F  = k * (h - p)                       // spring pull toward home
F += -c * v                            // velocity damping
if touching:
    d   = p - f
    r   = length(d)
    if r < R:
        fall = (1 - r/R)               // 0..1 falloff, smoothstepped
        F  += push * fall * normalize(d)      // radial shove away from finger
        F  += drag * fall * u                  // sweep: couple to finger motion
v = v + F * dt
v = v * globalDamp                     // extra stability clamp
p = p + v * dt
```

- Underdamped `k`/`c` gives the overshoot/wobble as points return home.
- `push` (radial) + `drag` (finger-velocity coupling) together produce the
  "swept aside in the wake" feel rather than a static repulsion bubble.
- Optional tiny constant idle noise/curl can add life at rest (replaces `sway`).

### Tunable constants — `FernPhysicsParams`

`springK`, `damping`, `globalDamp`, `fingerRadius R`, `pushStrength`,
`dragCoupling`, `pointSize`, `toneGamma`, `toneFloor`, `idleDrift`.
Defaults chosen for a soft, slightly bouncy feel; exposed so feel can be dialed
on-device. Initial tone defaults match current fern: `gamma 2.3`, `floor 0.55`.

## Look-match strategy

At rest (`touching` never fired, points at home), the additive splat +
tone-map must read like today's `FlameFern.image`. Plan:
- Splat size/intensity tuned so overlapping density curve ≈ the CPU histogram.
- `fern_tonemap` applies `t = floor + (1-floor) * pow(density/denom, 1/gamma)`
  then composites accent over paper — identical math to `FlameFern`.
- Accept that an exact pixel match isn't required; a close tonal match is.

## Tap vs. unlock reconciliation

Today, tapping the fern calls `reactAndUnlock()`. That must still work.
Resolution: the drag gesture owns all touches; on end it classifies tap vs.
drag by distance+duration and only calls `onTap()` for taps. Biometrics path,
shake-on-failure, and dissolve are unchanged.

## Fallback / degradation

- If Metal device creation fails (won't on target hardware), `FernParticleField`
  renders nothing and `InteractiveFernView` shows the static `FlameFernView` as a
  fallback, preserving unlock.
- One-line revert available: restore `FlameFernView(sway:)` in `LockGate`.

## Testing

- **Unit-testable:** a CPU mirror of the integrator (`FernPhysicsStep` pure
  function) with tests asserting: a displaced point returns toward home; total
  energy decays under damping; an underdamped config overshoots home at least
  once. This validates the core math without a device.
- **Not meaningfully testable off-device:** the look match, touch feel, and
  performance. Metal + multitouch are not exercised by the simulator in a way
  that reflects the device. Per project guardrails, this feature is
  **device-gated**: build + compile-verify + sim smoke, then hold for on-device
  testing by the user before it is considered done or installed to the fleet.

## Out of scope (YAGNI)

- Per-frond skeletal bending (a different, larger design).
- Interactivity on any surface other than the lock screen.
- Multi-finger / pinch interactions (single finger drag only).
- Persisting disturbed state across app backgrounding (it springs back; relock
  regenerates a fresh fern anyway).

## Risks

1. **Tone match takes iteration** — additive live render vs. CPU histogram may
   need a tuning pass to feel identical at rest. Mitigation: params exposed.
2. **Metal is new to the codebase** — build-system wiring (the `.metal` file in
   the Fern target via XcodeGen), default library loading. Mitigation: standard
   `MTLDevice.makeDefaultLibrary()`; regenerate project with `xcodegen`.
3. **Feel is subjective** — mitigated by exposing all constants for on-device
   dialing with Austin.
