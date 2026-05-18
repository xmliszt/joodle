//
//  CameraShutterView.swift
//  Joodle
//
//  Animated camera shutter overlay. Driven by a `CameraShutterController` —
//  callers invoke `controller.cycle { ... }` to run a sequential close →
//  await-work → open animation. The closure runs while the blades fully cover
//  the canvas, so any state swap (camera mount/unmount, backdrop install,
//  device flip) happens hidden behind the shutter.
//

import SwiftUI

@MainActor
final class CameraShutterController: ObservableObject {
  /// True while the blades fully cover the canvas. Parents gate camera preview
  /// mount/unmount on this so the live feed never appears outside the closed
  /// window.
  @Published private(set) var isFullyClosed: Bool = false

  /// True for the entire close → whileClosed → open sequence. Parents disable
  /// camera-affecting buttons while this is true so a second cycle can't
  /// interrupt the one currently animating.
  @Published private(set) var isCycling: Bool = false

  /// Most-recent cycle request. The shutter view observes the `id` and starts
  /// the corresponding animation pipeline.
  @Published fileprivate var pendingCycle: Cycle?

  fileprivate struct Cycle {
    let id = UUID()
    let fastClose: Bool
    let whileClosed: () async -> Void
  }

  /// Runs the shutter cycle: close → await `whileClosed` → open. Replaces any
  /// in-flight cycle (its animation is interrupted and its closure is
  /// abandoned mid-await if still running — make sure your `whileClosed` work
  /// is safe to drop).
  func cycle(fastClose: Bool = false, _ whileClosed: @escaping () async -> Void) {
    pendingCycle = Cycle(fastClose: fastClose, whileClosed: whileClosed)
  }

  /// Snaps the shutter back to fully open with no animation and abandons any
  /// in-flight cycle. Use when tearing down camera state out-of-band (e.g.
  /// when the drawing sheet is dismissed mid-cycle).
  func forceReset() {
    pendingCycle = nil
    isFullyClosed = false
    isCycling = false
    resetTrigger &+= 1
  }

  fileprivate func setCycling(_ value: Bool) {
    isCycling = value
  }

  @Published fileprivate var resetTrigger: Int = 0

  fileprivate func setFullyClosed(_ value: Bool) {
    isFullyClosed = value
  }
}

struct CameraShutterView: View {
  @ObservedObject var controller: CameraShutterController

  @State private var progress: Double = 0
  @State private var cycleTask: Task<Void, Never>?

  private let bladeCount: Int = 8
  private let closeDuration: Double = 0.45
  private let openDuration: Double = 0.55
  private let fastCloseDuration: Double = 0.25

  var body: some View {
    GeometryReader { geo in
      ZStack {
        ForEach(0..<bladeCount, id: \.self) { i in
          ZStack {
            // 1. Base fill — blades tile (no overlap), so each blade paints
            //    its own area in flat dark gray.
            ShutterBlade(progress: progress, bladeIndex: i, bladeCount: bladeCount)
              .fill(Color(white: 0.18))

            // 2. Faked cast-shadow: blurred dark stroke along the leading
            //    side edge only, masked to the blade interior. Reads as a
            //    soft shadow at each seam, mimicking the iPhone aperture's
            //    cyclic-overlap shadow without requiring real overlap.
            ShutterBladeLeadingEdge(progress: progress, bladeIndex: i, bladeCount: bladeCount)
              .stroke(Color.black.opacity(0.9), lineWidth: 12)
              .blur(radius: 6)
              .mask {
                ShutterBlade(progress: progress, bladeIndex: i, bladeCount: bladeCount)
                  .fill(Color.white)
              }
          }
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
    .allowsHitTesting(false)
    .onChange(of: controller.pendingCycle?.id) { _, _ in
      guard let cycle = controller.pendingCycle else { return }
      run(cycle)
    }
    .onChange(of: controller.resetTrigger) { _, _ in
      cycleTask?.cancel()
      progress = 0
    }
  }

  private func run(_ cycle: CameraShutterController.Cycle) {
    cycleTask?.cancel()
    controller.setCycling(true)
    cycleTask = Task { @MainActor in
      let closeDur = cycle.fastClose ? fastCloseDuration : closeDuration
      withAnimation(.easeInOut(duration: closeDur)) {
        progress = 1
      }
      try? await Task.sleep(nanoseconds: UInt64(closeDur * 1_000_000_000))
      if Task.isCancelled { return }
      controller.setFullyClosed(true)

      await cycle.whileClosed()
      if Task.isCancelled { return }

      withAnimation(.easeInOut(duration: openDuration)) {
        progress = 0
      }
      try? await Task.sleep(nanoseconds: UInt64(openDuration * 1_000_000_000))
      if Task.isCancelled { return }
      controller.setFullyClosed(false)
      controller.setCycling(false)
    }
  }
}

// MARK: - Shared blade geometry

/// Geometry parameters for one shutter blade at the given progress. Both
/// shapes below derive their paths from the same anchors so the leading-edge
/// shadow tracks the blade's actual side curve through the animation.
///
/// Each blade is a closed region bounded by:
/// - an outer arc on a ring well outside the canvas (clipped away)
/// - a curved side edge (cubic Bezier) leading from outerA to innerA
/// - a short inner arc on the aperture circle
/// - a curved side edge leading from innerB back out to outerB
///
/// Adjacent blades share their side edges exactly — see `appendSideCurve`
/// for the tile-invariance properties.
private struct ShutterBladeGeometry {
  let center: CGPoint
  let outerA: CGPoint
  let innerA: CGPoint
  let outerB: CGPoint
  let innerB: CGPoint
  let thetaA: Double
  let thetaB: Double
  let twist: Double
  let apertureR: Double
  let outerR: Double
  let curvature: Double

  init(rect: CGRect, progress: Double, bladeIndex: Int, bladeCount: Int) {
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let diagonal = sqrt(rect.width * rect.width + rect.height * rect.height)
    // Outer ring sits well outside the canvas square so the outer edges of
    // every blade live in the clipped-away region.
    let oR = diagonal * 0.85
    // Open aperture is bigger than the canvas's half-diagonal, so when open
    // the entire visible canvas falls inside the aperture (no blade covers it).
    let openApertureR = diagonal * 0.6
    let aR = openApertureR * (1.0 - progress)
    let maxTwist: Double = .pi / 4
    let tw = maxTwist * progress
    let step = 2 * .pi / Double(bladeCount)
    let tA = Double(bladeIndex) * step - .pi / 2
    let tB = tA + step
    func pt(_ r: Double, _ a: Double) -> CGPoint {
      CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
    }
    center = c
    outerR = oR
    apertureR = aR
    twist = tw
    curvature = 0.85
    thetaA = tA
    thetaB = tB
    outerA = pt(oR, tA)
    outerB = pt(oR, tB)
    innerA = pt(aR, tA + tw)
    innerB = pt(aR, tB + tw)
  }

  /// Append a cubic-Bezier side edge between two endpoints lying at known
  /// angles and radii around the aperture center.
  ///
  /// Control points sit 1/3 and 2/3 along the chord, each offset
  /// perpendicular to the chord in the `+θ` direction by `curvature *
  /// (endpoint's radius from center)`. Two key properties:
  ///
  /// - **Tile invariance**: both control offsets use `+tangent` (symmetric
  ///   sign). The formula depends only on endpoint position/angle/radius,
  ///   not traversal direction. Adjacent blades produce identical shared
  ///   edges → no gaps at seams.
  /// - **No center overshoot**: the offset at each control point scales
  ///   with that endpoint's own radius. When closed (`apertureR=0`) the
  ///   inner offset is 0, so the curve collapses cleanly to center instead
  ///   of swirling past it.
  func appendSideCurve(
    path: inout Path,
    from: CGPoint, fromAngle: Double, fromRadius: Double,
    to: CGPoint, toAngle: Double, toRadius: Double
  ) {
    let tFrom = CGPoint(x: -sin(fromAngle), y: cos(fromAngle))
    let tTo = CGPoint(x: -sin(toAngle), y: cos(toAngle))
    let offsetFrom = curvature * fromRadius
    let offsetTo = curvature * toRadius
    let dx = to.x - from.x
    let dy = to.y - from.y
    let mid1 = CGPoint(x: from.x + dx / 3, y: from.y + dy / 3)
    let mid2 = CGPoint(x: from.x + 2 * dx / 3, y: from.y + 2 * dy / 3)
    let c1 = CGPoint(x: mid1.x + tFrom.x * offsetFrom, y: mid1.y + tFrom.y * offsetFrom)
    let c2 = CGPoint(x: mid2.x + tTo.x * offsetTo, y: mid2.y + tTo.y * offsetTo)
    path.addCurve(to: to, control1: c1, control2: c2)
  }
}

// MARK: - Shapes

/// Full curved shutter blade. Closed path bounded by two arcs (outer and
/// inner aperture) and two cubic-Bezier side edges.
private struct ShutterBlade: Shape {
  var progress: Double
  var bladeIndex: Int
  var bladeCount: Int

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let g = ShutterBladeGeometry(rect: rect, progress: progress,
                                 bladeIndex: bladeIndex, bladeCount: bladeCount)
    var path = Path()
    path.move(to: g.outerA)
    g.appendSideCurve(
      path: &path,
      from: g.outerA, fromAngle: g.thetaA, fromRadius: g.outerR,
      to: g.innerA, toAngle: g.thetaA + g.twist, toRadius: g.apertureR
    )
    path.addArc(
      center: g.center, radius: g.apertureR,
      startAngle: .radians(g.thetaA + g.twist),
      endAngle: .radians(g.thetaB + g.twist),
      clockwise: false
    )
    g.appendSideCurve(
      path: &path,
      from: g.innerB, fromAngle: g.thetaB + g.twist, fromRadius: g.apertureR,
      to: g.outerB, toAngle: g.thetaB, toRadius: g.outerR
    )
    path.addArc(
      center: g.center, radius: g.outerR,
      startAngle: .radians(g.thetaB),
      endAngle: .radians(g.thetaA),
      clockwise: true
    )
    path.closeSubpath()
    return path
  }
}

/// Open path tracing ONLY the leading side edge of a shutter blade (side A:
/// outerA → innerA). Stroking this open path produces a single dark band
/// along one edge, used to fake a cast shadow at each seam.
private struct ShutterBladeLeadingEdge: Shape {
  var progress: Double
  var bladeIndex: Int
  var bladeCount: Int

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let g = ShutterBladeGeometry(rect: rect, progress: progress,
                                 bladeIndex: bladeIndex, bladeCount: bladeCount)
    var path = Path()
    path.move(to: g.outerA)
    g.appendSideCurve(
      path: &path,
      from: g.outerA, fromAngle: g.thetaA, fromRadius: g.outerR,
      to: g.innerA, toAngle: g.thetaA + g.twist, toRadius: g.apertureR
    )
    return path
  }
}
