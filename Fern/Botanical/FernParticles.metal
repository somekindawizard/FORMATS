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
kernel void fern_physics(device float2*        pos   [[buffer(0)]],
                         device float2*        vel   [[buffer(1)]],
                         const device float2*  home  [[buffer(2)]],
                         constant FernUniforms& U     [[buffer(3)]],
                         constant uint&        count [[buffer(4)]],
                         uint id [[thread_position_in_grid]]) {
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
    float2 p[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
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
