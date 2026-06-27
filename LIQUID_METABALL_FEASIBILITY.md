# Liquid Metaball Backdrop — Feasibility Assessment

## Verdict

**Feasible on iOS 17.5+, performant if scoped correctly.** The idea decomposes into
three independent, well-supported pieces: (1) metaball *rendering*, (2) particle
*physics* with gravity, (3) *shake* impulse. None require anything newer than what
the project already uses.

The main risk is **not capability, it's the GPU/thermal cost of a full-screen
effect running continuously at 60fps**. That's controllable with the right
rendering approach and throttling.

## What the codebase already gives us

- **Deployment target is iOS 17.5** (main app target). All APIs below are 17.0+.
- **The project already ships a `[[stitchable]]` Metal shader** (`Shaders/RippleEffect.metal`)
  driven by SwiftUI's `.layerEffect`. So the Shader toolchain, build setup, and
  patterns are proven here — no new infrastructure.
- **`MotionManager` already runs `CMDeviceMotion`** via `CMMotionManager`. It only
  exposes `tiltAngle` today, but `motion.gravity` (x/y/z) and `motion.userAcceleration`
  are already in hand — we just surface more of them.
- Backdrop is already rendered full-screen behind content with `.ignoresSafeArea()`
  at `opacity(0.2)` in `ContentView` — the "whole screen is the container" requirement
  is already how it's wired.

## The three pieces

### 1. Metaball rendering — DECISION: true scalar-field Metal shader

**Chosen: a `[[stitchable]]` `.colorEffect` shader computing a real metaball field.**
Pass ball positions/radii to the shader and compute `Σ r/dist` (or `Σ r²/dist²`) per
pixel, then threshold the sum with `smoothstep` to get the isosurface. iOS 17's
`Shader.Argument.floatArray([Float])` carries the balls as a packed array — SwiftUI
auto-injects the count as a trailing `int`, so the shader signature is
`(float2 position, half4 color, float2 bounds, device const float *balls, int count)`.
This is the same lightweight Shader pattern already in `RippleEffect.metal` — no
`MTKView`, no new infrastructure.

**Why not blur + alpha threshold?** Two reasons, and performance is the lesser one:

1. **It can't render the look we want.** The blur trick only merges shapes whose
   blur halos overlap — it produces *no* thin necks and *no* detached droplet
   strings. Splashing/flying droplets and stretchy liquid bridges are exactly what
   a true scalar field renders and the blur trick physically cannot.
2. **Worse full-screen performance.** A convincing gooey blur needs a large radius
   (community examples use 15–32). A separable Gaussian at radius 32 is ~64
   taps/pixel/axis — the dominant GPU cost, and punishing full-screen every frame.
   The standard advice is "don't run a big blur full-screen." A field shader is a
   single fragment pass, `O(pixels × balls)`; at ~20–30 balls that's a 30-iteration
   loop per pixel — typically *cheaper* than a large full-screen blur and easily
   60fps on the A12+ floor. (Reference: a Metal metaball shader ran full-screen at
   60fps / ~19% CPU on a 2015 iPhone 6S.)

The blur+threshold approach (SwiftUI `Canvas` + `GraphicsContext.addFilter`,
no Metal, iOS 15+) would only win for a small confined region — not our full-screen
backdrop. Recorded here only as the rejected alternative.

**Shader arg limits to respect:** shaders can't size arrays dynamically, so the
loop runs `0..<count` over a `device const float *`; keep an upper bound
(`MAX_BALLS`, e.g. 48) in mind when sizing the particle pool.

### 2. Physics (gravity + container)

A lightweight custom particle sim — **no SpriteKit needed**:
- Each metaball = a particle with position + velocity.
- Integrate per frame (Verlet or semi-implicit Euler) inside `TimelineView(.animation)`
  (already used in this view) or a `CADisplayLink`.
- **Gravity direction** comes from `motion.gravity` (x, y) — liquid pools toward the
  physical "down" as the device rotates. `MotionManager` already has this.
- **Container** = screen bounds (full rect, safe area ignored). Walls = clamp +
  velocity reflection with damping.
- Soft inter-particle repulsion keeps blobs from fully collapsing.

15–40 particles is plenty for a convincing liquid and is trivial CPU cost.

### 3. Shake → splash / droplets

- Read `motion.userAcceleration` magnitude; above a threshold, inject randomized
  upward/outward velocity impulses into particles → "splashing".
- Optionally spawn a few short-lived small droplet particles on a strong shake,
  recycled from a fixed pool (no unbounded allocation).
- Alternative trigger: UIKit `motionEnded(_:with:.motionShake)` for a discrete
  "shake gesture", but the accelerometer-magnitude approach gives finer, continuous
  response which suits liquid better.

## Performance plan (the actual risk)

| Concern | Mitigation |
|---|---|
| `O(pixels × balls)` fragment cost full-screen | Keep the pool small (~20–30 balls, hard cap `MAX_BALLS = 48`). Field-sum loop is cheap per iteration. If needed, run the `colorEffect` on a slightly downscaled layer. |
| 60fps continuous GPU load / thermals | Cap to 30fps when idle (no motion), ramp to 60fps only during active motion/shake. Pause entirely when `isVisible == false` / view off-screen. |
| Per-pixel `length()`/divide cost | Use `max(d, ε)` to avoid singularities; `smoothstep` threshold; cheap `r/dist` form rather than `sqrt`-heavy variants. |
| Battery | Stop motion + animation when backgrounded or covered by the bottom sheet (the view already toggles on `isVisible`). |

Target devices on iOS 17.5 are A12+ (iPhone XS era and newer). A full-screen
metaball field shader with ~30 particles is comfortably within budget at 60fps on
that hardware (a 2015 iPhone 6S held 60fps full-screen at ~19% CPU). This is the
same class of effect — and the same `[[stitchable]]` Shader API — already proven in
`RippleEffect.metal`.

## Recommended implementation shape

```
PassingTimeBackdropView
├─ LiquidSimulation (ObservableObject / struct)   // particle state, stepped per frame
│    ├─ particles: [Particle]                       // pos, vel, radius
│    ├─ step(dt:, gravity: CGVector, bounds:)       // integrate + collide
│    └─ applyShakeImpulse(strength:)
├─ MotionManager (extend)                            // expose gravity.x/.y + userAccel magnitude
└─ Render
     Color.clear (full-screen)
       .colorEffect(ShaderLibrary.metaballs(.float2(bounds), .floatArray(ballData)))
     wrapped in TimelineView(.animation), .ignoresSafeArea()
     // ballData = particles.flatMap { [x, y, radius] }, rebuilt each frame
```

`Metaball.metal` would be a new `[[stitchable]] half4` color effect:

```metal
[[stitchable]] half4 metaballs(float2 position, half4 color,
                               float2 bounds,
                               device const float *balls, int count) {
    float field = 0.0;
    for (int i = 0; i + 2 < count; i += 3) {
        float2 c = float2(balls[i], balls[i+1]);
        float  r = balls[i+2];
        field += r / max(length(position - c), 0.001);
    }
    float a = smoothstep(0.95, 1.05, field);   // isosurface → soft alpha
    return half4(/* Color.appAccent.rgb */ ) * a;
}
```

## Open product questions — prototype defaults chosen

1. **Time-of-day fill semantic** → dropped for the prototype; this is now pure
   ambient liquid physics. Easy to reintroduce later by scaling particle count or
   a "fill line" by `dayProgress`.
2. **Opacity** → kept subtle (`liquidOpacity` default `0.2`, matching the existing
   backdrop). Preview uses `0.6` so the effect is visible without a device.
3. **Replace vs variant** → shipped as a **new `LiquidMetaballBackdropView`**;
   `PassingTimeBackdropView` is left untouched. Swapping is a one-line change in
   `ContentView` (line ~133).

## Prototype status (branch `feature/liquid-metaball`)

Implemented:
- `Joodle/Shaders/Metaball.metal` — finite-support scalar-field color effect.
- `Joodle/Utils/MotionManager.swift` — extended with `gravityX`/`gravityY` and
  `shakeMagnitude` (userAcceleration), lightly smoothed.
- `Joodle/Views/LiquidMetaballBackdropView.swift` — `LiquidSimulation` particle
  sim (28 balls, gravity + soft repulsion + wall bounce + shake impulses) driven
  by `TimelineView(.animation)`, rendered through the shader.

Not yet done (follow-ups): adaptive frame-rate throttling when idle; on-device
tuning of constants (gravity, separation, threshold); wiring into `ContentView`
behind a setting; reintroducing day-progress if wanted.

## Bottom line

Green-light. No iOS 17.5 compatibility gap, no new dependencies, reuses the existing
shader + motion infrastructure. Approach locked in: **a true metaball scalar-field
`.colorEffect` Metal shader + a small custom particle sim driven by CoreMotion
gravity, with shake impulses**. Budget the work around performance throttling
(small ball pool + adaptive frame rate), which is where the effort actually lives.
