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

  private let bladeCount: Int = 12
  private let closeDuration: Double = 0.65
  private let openDuration: Double = 0.55
  private let fastCloseDuration: Double = 0.3

  var body: some View {
    ApertureBlades(progress: progress, bladeCount: bladeCount)
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

// Blade geometry and shapes (`CurvedBlade`, `BladeLeadingEdge`) are shared
// with `AperturePrototypeView` — see that file for the geometry definition
// and tile-invariance notes.
