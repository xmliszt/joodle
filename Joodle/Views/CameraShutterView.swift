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
          ShutterBlade(progress: progress, bladeIndex: i, bladeCount: bladeCount)
            .fill(Color(white: 0.18))
          ShutterBlade(progress: progress, bladeIndex: i, bladeCount: bladeCount)
            .stroke(Color.black.opacity(0.9), lineWidth: 1)
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

/// Single shutter blade — a pie slice between two adjacent outer pivots, with
/// its inner edge curved along the aperture circle. The aperture shrinks from
/// outside the canvas (open) to 0 (closed). The inner arc twists with `progress`
/// to mimic real-shutter rotation; adjacent blades share the same twist so they
/// continue to tile the annulus perfectly with no overlap.
private struct ShutterBlade: Shape {
  var progress: Double
  var bladeIndex: Int
  var bladeCount: Int

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let diagonal = sqrt(rect.width * rect.width + rect.height * rect.height)
    // Outer ring sits well outside the canvas square so the outer edges of
    // every blade live in the clipped-away region.
    let outerR = diagonal * 0.85
    // Open aperture is bigger than the canvas's half-diagonal, so when open
    // the entire visible canvas falls inside the aperture (no blade covers it).
    let openApertureR = diagonal * 0.6
    let apertureR = openApertureR * (1.0 - progress)
    // Twist the inner arc as the shutter closes — visually mimics blades
    // rotating around their pivots. Same twist for every blade preserves
    // exact tiling of the annulus.
    let maxTwist: Double = .pi / 5
    let twist = maxTwist * progress

    let angleStep = 2 * .pi / Double(bladeCount)
    let thetaA = Double(bladeIndex) * angleStep - .pi / 2
    let thetaB = thetaA + angleStep

    let outerA = CGPoint(
      x: center.x + cos(thetaA) * outerR,
      y: center.y + sin(thetaA) * outerR
    )
    let outerB = CGPoint(
      x: center.x + cos(thetaB) * outerR,
      y: center.y + sin(thetaB) * outerR
    )
    let innerA = CGPoint(
      x: center.x + cos(thetaA + twist) * apertureR,
      y: center.y + sin(thetaA + twist) * apertureR
    )

    var p = Path()
    p.move(to: outerA)
    p.addLine(to: innerA)
    // Curved inner edge — arc on the aperture circle.
    p.addArc(
      center: center,
      radius: apertureR,
      startAngle: .radians(thetaA + twist),
      endAngle: .radians(thetaB + twist),
      clockwise: false
    )
    p.addLine(to: outerB)
    // Close via the outer ring (clipped away, but still defines the polygon).
    p.addArc(
      center: center,
      radius: outerR,
      startAngle: .radians(thetaB),
      endAngle: .radians(thetaA),
      clockwise: true
    )
    p.closeSubpath()
    return p
  }
}
