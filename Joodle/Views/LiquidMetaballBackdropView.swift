//
//  LiquidMetaballBackdropView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Observation
import SwiftUI

/// An experimental backdrop that simulates a body of liquid using true metaballs.
///
/// A small pool of particles falls under device gravity, pools against the
/// physical "down" edge of the screen, and splashes into flying droplets when the
/// device is shaken. The particles are rendered as a single connected liquid
/// surface by `Metaball.metal`, a scalar-field color effect. The whole screen is
/// the container — safe areas are ignored.
struct LiquidMetaballBackdropView: View {
  @StateObject private var motionManager = MotionManager.shared

  /// Overall opacity of the liquid backdrop.
  var liquidOpacity: Double = 0.2

  /// The metaball field is rasterized on a layer shrunk by this factor and scaled
  /// back up, cutting shader fill-rate by `renderScale²` (2 → a quarter of the
  /// pixels). The field is smooth and the backdrop faint, so the upscale is
  /// effectively invisible; raise toward 3 for more savings if edges still read clean.
  private let renderScale: CGFloat = 2

  @State private var simulation = LiquidSimulation()

  var body: some View {
    GeometryReader { geometry in
      TimelineView(.animation) { timeline in
        let _ = simulation.advance(
          to: timeline.date.timeIntervalSinceReferenceDate,
          bounds: geometry.size,
          gravityX: motionManager.gravityX,
          gravityY: motionManager.gravityY,
          shakeMagnitude: motionManager.shakeMagnitude,
          fillLevel: Self.fillLevel(at: timeline.date)
        )

        // A color effect needs a non-transparent source to rasterize over, so the
        // base rectangle is filled solid; the shader replaces every pixel, carving
        // the blobs with its own alpha and tinting them with the accent color.
        // The rectangle is sized down by `renderScale` so the shader runs over
        // fewer pixels, then scaled back up from the top-leading origin (the same
        // origin the simulation uses) to cover the screen. When the container is
        // empty we render nothing at all.
        if simulation.ballData.isEmpty {
          Color.clear
        } else {
          Rectangle()
            .fill(.white)
            .frame(
              width: geometry.size.width / renderScale,
              height: geometry.size.height / renderScale
            )
            .colorEffect(
              ShaderLibrary.metaballs(
                .color(.appAccent),
                .float(LiquidSimulation.fieldThreshold),
                .float(LiquidSimulation.fieldEdgeSoftness),
                .float(Float(LiquidSimulation.influenceRadius)),
                .float(Float(renderScale)),
                .floatArray(simulation.ballData)
              )
            )
            .scaleEffect(renderScale, anchor: .topLeading)
        }
      }
    }
    .opacity(liquidOpacity)
    .ignoresSafeArea()
    .onAppear { motionManager.startUpdates() }
    .onDisappear { motionManager.stopUpdates() }
  }

  /// Remaining fraction of the day: 1 at 00:00 (full container), 0 at end of day.
  /// Honors the debug time-of-day override when set, otherwise the device clock.
  private static func fillLevel(at date: Date) -> Double {
    let totalSecondsInDay: Double = 24 * 60 * 60
    let secondsSinceMidnight = LiquidBackdropDebug.shared.simulatedSecondsSinceMidnight
      ?? date.timeIntervalSince(Calendar.current.startOfDay(for: date))
    return max(0, min(1, 1 - secondsSinceMidnight / totalSecondsInDay))
  }
}

// MARK: - Debug

/// Debug-only override for the time of day that drives the liquid drain level.
/// `nil` (the default, and the only value in release builds) follows the device
/// clock; the experimental-features debug controls set it to simulate any time.
@Observable
final class LiquidBackdropDebug {
  static let shared = LiquidBackdropDebug()
  private init() {}

  /// Seconds since midnight (0 ..< 86400) to simulate, or `nil` to follow the clock.
  var simulatedSecondsSinceMidnight: Double?
}

// MARK: - Simulation

/// A single liquid particle. Position is in the view's local point space.
private struct LiquidParticle {
  var position: CGPoint
  var velocity: CGVector
}

/// Lightweight particle simulation driving the metaball field.
///
/// A reference type stepped imperatively from the `TimelineView` render closure —
/// it deliberately publishes nothing, since the `TimelineView` already re-renders
/// every frame. Integration uses semi-implicit Euler with fixed sub-steps for
/// stability and clamped frame deltas so returning from the background can't
/// explode the system.
final class LiquidSimulation {
  // Field tuning (shared with Metaball.metal). With this kernel an isolated ball's
  // visible radius ≈ influenceRadius * sqrt(1 - sqrt(threshold)).
  static let fieldThreshold: Float = 0.5
  static let fieldEdgeSoftness: Float = 0.08

  /// Hard cap on ball count, since the shader cost is O(pixels × balls). At this
  /// coarse grain a full phone needs only ~140; the cap is a safety ceiling that
  /// protects larger screens (iPad) from an unaffordable fill.
  static let maxBallCount = 600

  /// Repulsion rest length — balls push apart when closer than this.
  private let separation: CGFloat = 64
  /// Spacing used to size a full pool. Slightly smaller than `separation` because
  /// the liquid still compresses a little under gravity; with the stiffer (more
  /// incompressible) springs below it's close to the rest length. Tune to set how
  /// full a full container looks.
  private let fillSpacing: CGFloat = 56
  /// Field radius shared by every ball; passed to the shader as a single uniform.
  static let influenceRadius: CGFloat = 100

  // Physics constants (points / seconds). Tuned to read like real water: free-fall
  // in air (almost no drag), a nearly incompressible body, and inelastic contacts.
  private let gravityAcceleration: CGFloat = 4000
  /// Stiff repulsion so the body is nearly incompressible (real water barely
  /// compresses). Soft springs let the pool collapse under its own weight, which
  /// reads as the liquid sinking rather than sitting. Stiff enough to hold the
  /// column, kept stable by the sub-steps below.
  private let repulsionStiffness: CGFloat = 2600
  /// Damping along ball-to-ball contacts. Set slightly *over* critical damping
  /// (critical ≈ 2·√stiffness ≈ 102) so contacts are inelastic and energy-absorbing:
  /// balls settle into each other instead of bouncing like rubber, which is what
  /// stops the pool jittering perpetually at high fill. Clamped to never pull.
  private let contactDamping: CGFloat = 110
  /// Hydrostatic-leveling gain, as a fraction of gravity. A radial-repulsion body can
  /// hold a static force chain — it has the shear strength real water lacks — so a
  /// tilted pool jams as a coating along the down-wall and a column can cling to a side
  /// wall instead of flowing flat. `computeLeveling` adds the shallow-water pressure
  /// term directly: it measures each column's surface height and pushes every ball
  /// *down the surface slope* with `gravityAcceleration * levelingGain * slope`. Driven
  /// by surface shape rather than local repulsion, it can't be fooled by the fluid's
  /// free edges (a per-ball repulsion heuristic reads those as cohesion and balls up
  /// the pool), and it self-cancels once the surface is flat. Tunable: raise to level
  /// faster, lower if a settled pool overshoots into a standing wave.
  private let levelingGain: CGFloat = 0.6
  /// Largest surface slope the leveling term reacts to, so a single stray shallow ball
  /// in a column can't spike the push. 1 ≈ 45°.
  private let maxLevelingSlope: CGFloat = 1.0
  /// Rebound off the side/top walls so droplets spring away and fall instead of
  /// clinging and running down the surface. Scaled per wall by how much it faces
  /// gravity (see `resolveWalls`), so the floor stays inelastic and the pool rests.
  private let wallRestitution: CGFloat = 0.5
  /// Low air drag so airborne water still free-falls rather than drifting down at a
  /// floaty terminal velocity. Most energy is dissipated by inelastic contacts; this
  /// adds a little bulk bleed so a settled pool comes fully to rest.
  private let linearDamping: CGFloat = 0.2
  private let maxSpeed: CGFloat = 6000

  // Shake response. The impulse is scaled by frame delta so it can't accumulate
  // across frames; `shakeThreshold` is in Gs of user acceleration (normal handling
  // sits well below 1G, a deliberate shake is 2G+).
  private let shakeThreshold: Double = 1.8
  private let shakeForce: CGFloat = 9000

  private var particles: [LiquidParticle] = []
  /// Ball count for a full container, derived from the screen size.
  private var fullCount = 0
  /// How many of `particles` are currently "in the container". Drains over the day.
  private var activeCount = 0
  private var bounds: CGSize = .zero
  private var lastTimestamp: TimeInterval?

  /// Per-ball repulsion accumulator, reused across frames so the pass never
  /// reallocates. Sized to `particles.count`; only `0..<activeCount` is meaningful.
  private var repulsions: [CGVector] = []

  /// Uniform-grid acceleration structure for the repulsion pass, reused across
  /// frames. `cellHeads[cell]` is the index of one ball in that cell (or -1) and
  /// `cellNext[i]` chains to the next ball in the same cell.
  private var cellHeads: [Int] = []
  private var cellNext: [Int] = []

  /// Hydrostatic-leveling scratch, reused across frames. `levelingAccel[i]` is the
  /// per-ball acceleration along the horizontal (gravity-perpendicular) axis;
  /// `levelingSurface[c]` is column `c`'s surface depth; `levelingColumnOf[i]` is the
  /// column a ball fell into. Recomputed once per frame in `computeLeveling`.
  private var levelingAccel: [CGFloat] = []
  private var levelingSurface: [CGFloat] = []
  private var levelingColumnOf: [Int] = []

  /// Packed [x, y, …] for the shader, reused across frames.
  private(set) var ballData: [Float] = []

  /// Step the simulation up to `timestamp`. Returns nothing; reads `ballData` after.
  func advance(
    to timestamp: TimeInterval,
    bounds size: CGSize,
    gravityX: Double,
    gravityY: Double,
    shakeMagnitude: Double,
    fillLevel: Double
  ) {
    guard size.width > 0, size.height > 0 else { return }

    // The container is the full screen, not the resizable split pane. The pane
    // reaches full screen whenever no bottom sheet is shown, so latch the largest
    // size ever seen and never shrink it: sliding the split up then slides a panel
    // over a fixed body of liquid instead of reflowing it to the smaller pane.
    let container = CGSize(
      width: max(size.width, bounds.width),
      height: max(size.height, bounds.height)
    )
    if container != bounds {
      bounds = container
      // Enough balls to tile the container at the settled (compressed) spacing, so
      // a full pool fills the whole height once it settles and the fill level maps
      // proportionally to height. Grow the pool in place rather than reseeding.
      fullCount = min(Self.maxBallCount, Int((bounds.width * bounds.height / (fillSpacing * fillSpacing)).rounded(.up)))
      resizePool(to: fullCount)
    }

    // Drain the container as the day passes: full pool at the start of the day,
    // empty by its end. Removing balls lowers the level because the remaining
    // ones re-settle under gravity and repulsion.
    activeCount = min(particles.count, max(0, Int((Double(fullCount) * fillLevel).rounded())))

    guard let last = lastTimestamp else {
      lastTimestamp = timestamp
      rebuildBallData()
      return
    }
    lastTimestamp = timestamp

    // Clamp the frame delta so a stall or background return can't blow up.
    let frameDelta = min(max(timestamp - last, 0), 1.0 / 30.0)
    guard frameDelta > 0 else { return }

    // Screen-space gravity: device-down maps to (gravityX, -gravityY).
    let gravity = CGVector(dx: CGFloat(gravityX), dy: CGFloat(-gravityY))

    if shakeMagnitude > shakeThreshold {
      applyShake(intensity: shakeMagnitude, delta: frameDelta)
    }

    // Surface-leveling accelerations, computed once per frame (the surface moves
    // slowly relative to a frame) and reused across every sub-step below.
    let gravityLength = hypot(gravity.dx, gravity.dy)
    if gravityLength > 0.01 {
      computeLeveling(downX: gravity.dx / gravityLength, downY: gravity.dy / gravityLength)
    }

    // Fixed sub-steps keep the repulsion springs stable under explicit integration
    // (smaller steps → higher stable stiffness/damping). The far smaller ball count
    // at this grain makes the extra sub-step cheap.
    let subStepCount = 5
    let subDelta = frameDelta / CGFloat(subStepCount)
    for _ in 0..<subStepCount {
      integrate(delta: subDelta, gravity: gravity)
    }

    rebuildBallData()
  }

  /// Grow or shrink the particle pool to `count`, preserving existing particles so
  /// resizing the container doesn't reset settled liquid.
  private func resizePool(to count: Int) {
    if count > particles.count {
      particles += (particles.count..<count).map { _ in seededParticle() }
    } else if count < particles.count {
      particles = Array(particles.prefix(count))
    }
  }

  /// A new particle seeded in the lower portion of the container, so the first
  /// frame reads as pooled liquid rather than droplets raining from the top.
  private func seededParticle() -> LiquidParticle {
    LiquidParticle(
      position: CGPoint(
        x: .random(in: 0...bounds.width),
        y: .random(in: (bounds.height * 0.5)...bounds.height)
      ),
      velocity: .zero
    )
  }

  private func applyShake(intensity: Double, delta: CGFloat) {
    // Scale by how far the shake exceeds the threshold and by the frame delta, so
    // sustained shaking ramps up smoothly instead of exploding every frame.
    let excess = CGFloat(min(intensity - shakeThreshold, 3.0))
    let strength = shakeForce * excess * delta
    for index in 0..<activeCount {
      particles[index].velocity.dx += .random(in: -strength...strength)
      // Bias upward (screen -y) so a shake throws the liquid up into droplets.
      particles[index].velocity.dy += .random(in: (-strength * 1.2)...(-strength * 0.2))
    }
  }

  private func integrate(delta: CGFloat, gravity: CGVector) {
    computeRepulsions()
    let gravityLength = hypot(gravity.dx, gravity.dy)
    let hasGravity = gravityLength > 0.01
    // Unit gravity ("down") direction, for the leveling axis and the wall rebound.
    let downX = hasGravity ? gravity.dx / gravityLength : 0
    let downY = hasGravity ? gravity.dy / gravityLength : 0
    // Unit axis perpendicular to gravity — the horizontal the surface levels toward.
    let tangentX = -downY
    let tangentY = downX
    let damping = max(0, 1 - linearDamping * delta)
    let maxSpeedSq = maxSpeed * maxSpeed

    for index in 0..<activeCount {
      var velocity = particles[index].velocity
      let repulsion = repulsions[index]

      velocity.dx += (gravity.dx * gravityAcceleration + repulsion.dx) * delta
      velocity.dy += (gravity.dy * gravityAcceleration + repulsion.dy) * delta

      // Hydrostatic leveling: push the ball down the surface slope of its column so a
      // jammed coating or a wall-clinging column flows flat. See `computeLeveling`.
      if hasGravity {
        let leveling = levelingAccel[index]
        velocity.dx += tangentX * leveling * delta
        velocity.dy += tangentY * leveling * delta
      }

      velocity.dx *= damping
      velocity.dy *= damping

      let speedSq = velocity.dx * velocity.dx + velocity.dy * velocity.dy
      if speedSq > maxSpeedSq {
        let scale = maxSpeed / speedSq.squareRoot()
        velocity.dx *= scale
        velocity.dy *= scale
      }

      particles[index].velocity = velocity
      particles[index].position.x += velocity.dx * delta
      particles[index].position.y += velocity.dy * delta
      resolveWalls(&particles[index], downX: downX, downY: downY)
    }
  }

  /// Compute the per-ball hydrostatic-leveling acceleration for this frame.
  ///
  /// Radial springs can transmit shear, so the body jams: a tilted pool sits as a
  /// uniform coating and a column can stand against a side wall, neither flowing to
  /// level the way water must. This adds the shallow-water pressure term directly.
  /// Balls are binned into columns across the horizontal (gravity-perpendicular) axis;
  /// each column's surface height is its highest ball (smallest depth along gravity);
  /// every ball is then accelerated *down* its local surface slope. The drive is set
  /// by surface shape, not local repulsion, so the fluid's free edges don't fool it
  /// (a per-ball repulsion signal reads an edge as cohesion and balls the pool up), and
  /// it self-cancels once the surface is flat. `accel = gravityAcceleration · gain ·
  /// slope` is the tangential gravity of a surface at that slope, so `gain = 1` is the
  /// physical rate; it's tuned below 1 to settle gently.
  private func computeLeveling(downX: CGFloat, downY: CGFloat) {
    let count = activeCount
    if levelingAccel.count < particles.count {
      levelingAccel = Array(repeating: 0, count: particles.count)
      levelingColumnOf = Array(repeating: 0, count: particles.count)
    }
    guard count > 0 else { return }

    // Horizontal axis the surface levels toward; depth runs along gravity.
    let tangentX = -downY
    let tangentY = downX
    let columnWidth = separation

    var minS = CGFloat.greatestFiniteMagnitude
    var maxS = -CGFloat.greatestFiniteMagnitude
    for i in 0..<count {
      let s = particles[i].position.x * tangentX + particles[i].position.y * tangentY
      minS = Swift.min(minS, s)
      maxS = Swift.max(maxS, s)
    }

    let columns = Swift.max(1, Int(((maxS - minS) / columnWidth).rounded(.down)) + 1)
    if levelingSurface.count < columns {
      levelingSurface = Array(repeating: 0, count: columns)
    }
    for c in 0..<columns { levelingSurface[c] = .greatestFiniteMagnitude }

    // Surface of each column = its highest ball (smallest depth along gravity).
    for i in 0..<count {
      let position = particles[i].position
      let s = position.x * tangentX + position.y * tangentY
      let depth = position.x * downX + position.y * downY
      let column = Swift.min(columns - 1, Swift.max(0, Int((s - minS) / columnWidth)))
      levelingColumnOf[i] = column
      if depth < levelingSurface[column] { levelingSurface[column] = depth }
    }

    // Accelerate each ball down its surface slope. Neighbour columns with no liquid
    // fall back to this column's own surface, so the slope is zero at the pool's
    // lateral edges and nothing is pushed out into empty space.
    let gain = gravityAcceleration * levelingGain
    let span = 2 * columnWidth
    for i in 0..<count {
      let column = levelingColumnOf[i]
      let here = levelingSurface[column]
      let left =
        column > 0 && levelingSurface[column - 1] != .greatestFiniteMagnitude
          ? levelingSurface[column - 1] : here
      let right =
        column < columns - 1 && levelingSurface[column + 1] != .greatestFiniteMagnitude
          ? levelingSurface[column + 1] : here
      // Positive slope ⇒ surface deepens toward +tangent ⇒ downhill is +tangent.
      let slope = Swift.max(-maxLevelingSlope, Swift.min(maxLevelingSlope, (right - left) / span))
      levelingAccel[i] = gain * slope
    }
  }

  /// Soft pairwise repulsion so particles spread into a liquid layer instead of
  /// collapsing onto a single point. A uniform grid (cell = `separation`) limits
  /// each ball to its 3×3 cell neighbourhood, so the pass is ~O(n) for an evenly
  /// spread pool rather than O(n²); a squared-distance reject then skips the sqrt
  /// for pairs that don't actually touch, and unsafe buffer access drops bounds
  /// checks from the hot loop. Results land in the reused `repulsions` buffer.
  private func computeRepulsions() {
    let activeCount = self.activeCount
    guard activeCount > 0 else { return }
    if repulsions.count < particles.count {
      repulsions = Array(repeating: .zero, count: particles.count)
    }
    if cellNext.count < particles.count {
      cellNext = Array(repeating: -1, count: particles.count)
    }
    let separation = self.separation
    let separationSq = separation * separation
    let repulsionStiffness = self.repulsionStiffness
    let contactDamping = self.contactDamping

    let cellSize = separation
    let cols = max(1, Int((bounds.width / cellSize).rounded(.up)))
    let rows = max(1, Int((bounds.height / cellSize).rounded(.up)))
    let cellCount = cols * rows
    if cellHeads.count != cellCount {
      cellHeads = Array(repeating: -1, count: cellCount)
    } else {
      for c in 0..<cellCount { cellHeads[c] = -1 }
    }

    repulsions.withUnsafeMutableBufferPointer { acc in
      for i in 0..<activeCount { acc[i] = .zero }
      particles.withUnsafeBufferPointer { p in
        cellHeads.withUnsafeMutableBufferPointer { heads in
          cellNext.withUnsafeMutableBufferPointer { next in
            // Bucket each active ball into its cell (prepend to the cell's chain).
            for i in 0..<activeCount {
              let cx = min(cols - 1, max(0, Int(p[i].position.x / cellSize)))
              let cy = min(rows - 1, max(0, Int(p[i].position.y / cellSize)))
              let cell = cy * cols + cx
              next[i] = heads[cell]
              heads[cell] = i
            }
            // Each ball pulls from its 3×3 cell neighbourhood; the `j > i` guard
            // makes every pair act exactly once.
            for i in 0..<activeCount {
              let pi = p[i]
              let cx = min(cols - 1, max(0, Int(pi.position.x / cellSize)))
              let cy = min(rows - 1, max(0, Int(pi.position.y / cellSize)))
              var accIX = acc[i].dx
              var accIY = acc[i].dy
              for ny in max(0, cy - 1)...min(rows - 1, cy + 1) {
                for nx in max(0, cx - 1)...min(cols - 1, cx + 1) {
                  var j = heads[ny * cols + nx]
                  while j != -1 {
                    guard j > i else { j = next[j]; continue }
                    let pj = p[j]
                    let dx = pi.position.x - pj.position.x
                    let dy = pi.position.y - pj.position.y
                    let distSq = dx * dx + dy * dy
                    if distSq < separationSq {
                      let dist = max(distSq.squareRoot(), 0.001)
                      let overlap = separation - dist
                      let normalX = dx / dist
                      let normalY = dy / dist
                      // Spring push apart, minus a dashpot along the contact normal
                      // that drains the relative approach speed — this is what makes
                      // contacts inelastic (liquid) rather than elastic (rubber).
                      // Clamped to be purely repulsive: a negative force would pull
                      // separating balls together, reading as sticky goo not liquid.
                      let relativeNormalVelocity =
                        (pi.velocity.dx - pj.velocity.dx) * normalX
                        + (pi.velocity.dy - pj.velocity.dy) * normalY
                      let force = max(0, repulsionStiffness * overlap - contactDamping * relativeNormalVelocity)
                      let fx = normalX * force
                      let fy = normalY * force
                      accIX += fx
                      accIY += fy
                      acc[j].dx -= fx
                      acc[j].dy -= fy
                    }
                    j = next[j]
                  }
                }
              }
              acc[i].dx = accIX
              acc[i].dy = accIY
            }
          }
        }
      }
    }
  }

  /// Keep a ball inside the container. A wall reflects the normal velocity scaled by
  /// `wallRestitution`, but only to the degree it isn't the *floor*: the wall gravity
  /// points into stays inelastic so the resting pool doesn't bounce, while side and
  /// top walls rebound droplets so they spring off and fall instead of clinging and
  /// running down the surface. `downX`/`downY` is the unit gravity direction (zero
  /// when the device is flat, which makes every wall inelastic).
  private func resolveWalls(_ particle: inout LiquidParticle, downX: CGFloat, downY: CGFloat) {
    if particle.position.x < 0 {
      particle.position.x = 0
      // Outward normal (-1, 0); how much it faces the floor is dot(normal, down) = -downX.
      particle.velocity.dx = -particle.velocity.dx * wallRestitution * (1 - max(0, -downX))
    } else if particle.position.x > bounds.width {
      particle.position.x = bounds.width
      particle.velocity.dx = -particle.velocity.dx * wallRestitution * (1 - max(0, downX))
    }
    if particle.position.y < 0 {
      particle.position.y = 0
      particle.velocity.dy = -particle.velocity.dy * wallRestitution * (1 - max(0, -downY))
    } else if particle.position.y > bounds.height {
      particle.position.y = bounds.height
      particle.velocity.dy = -particle.velocity.dy * wallRestitution * (1 - max(0, downY))
    }
  }

  private func rebuildBallData() {
    let needed = activeCount * 2
    if ballData.count != needed {
      ballData = [Float](repeating: 0, count: needed)
    }
    ballData.withUnsafeMutableBufferPointer { data in
      particles.withUnsafeBufferPointer { p in
        for i in 0..<activeCount {
          data[2 * i] = Float(p[i].position.x)
          data[2 * i + 1] = Float(p[i].position.y)
        }
      }
    }
  }
}

// MARK: - Preview

#Preview("Liquid Metaball Backdrop") {
  ZStack {
    Color.backgroundColor
    LiquidMetaballBackdropView(liquidOpacity: 0.6)
  }
  .ignoresSafeArea()
}
