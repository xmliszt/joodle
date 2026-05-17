//
//  CameraReferenceContext.swift
//  Joodle
//
//  Shared camera state owned by ContentView and consumed by both DrawingCanvasView
//  (for the in-canvas live preview, top-row controls, in-sheet shutter on non-DI)
//  and ContentView itself (for the fullscreen blurred backdrop and the DI shutter
//  overlay rendered outside the drawing container).
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

enum CameraReferenceMode: Equatable {
  case idle
  case live
}

@MainActor
final class CameraReferenceContext: ObservableObject {
  @Published var mode: CameraReferenceMode = .idle
  @Published var backdropImage: UIImage? = nil
  @Published var showPermissionDeniedAlert: Bool = false
  /// Mirrors the controller's session-running state so views observing this
  /// context can show a "Turning on camera..." placeholder while the session
  /// is still spinning up.
  @Published var isSessionRunning: Bool = false
  /// Mirror of `controller.currentDevice` so views observing the context
  /// re-render whenever the active capture device changes (e.g. flip).
  @Published var currentDevice: AVCaptureDevice?
  /// Mirror of `shutter.isFullyClosed`. Republished here so views observing
  /// the context (rather than the nested controller directly) re-render when
  /// the shutter reaches the fully-closed state.
  @Published private(set) var isShutterFullyClosed: Bool = false
  /// Mirror of `shutter.isCycling`. Republished for the same reason — used to
  /// disable camera-affecting buttons for the entire close → open sequence.
  @Published private(set) var isShutterCycling: Bool = false
  /// When true, parents should unmount the live preview entirely. Used during
  /// a flip cycle to prevent the old device's last frame from lingering on
  /// the shared preview layer while the session swaps inputs.
  @Published private(set) var suppressPreview: Bool = false

  let controller: CameraReferenceController
  /// Drives the shutter overlay; every camera-mode transition is bracketed by
  /// a shutter cycle so the swap happens behind closed blades.
  let shutter = CameraShutterController()
  private var cancellables: Set<AnyCancellable> = []

  init() {
    let controller = CameraReferenceController()
    self.controller = controller
    controller.$isRunning
      .receive(on: DispatchQueue.main)
      .assign(to: &$isSessionRunning)
    controller.$currentDevice
      .receive(on: DispatchQueue.main)
      .assign(to: &$currentDevice)
    shutter.$isFullyClosed
      .receive(on: DispatchQueue.main)
      .assign(to: &$isShutterFullyClosed)
    shutter.$isCycling
      .receive(on: DispatchQueue.main)
      .assign(to: &$isShutterCycling)
  }

  var session: AVCaptureSession { controller.session }
  var isFrontFacing: Bool { controller.position == .front }

  func enterLive() async {
    let granted: Bool = await {
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized:
        return true
      case .notDetermined:
        let ok = await AVCaptureDevice.requestAccess(for: .video)
        controller.permissionState = ok ? .granted : .denied
        return ok
      case .denied, .restricted:
        return false
      @unknown default:
        return false
      }
    }()
    guard granted else {
      showPermissionDeniedAlert = true
      return
    }
    shutter.cycle {
      // Give SwiftUI a beat to finish the close animation before we kick off
      // the heavy mode-flip + session-start work — otherwise that work
      // crashes into the tail of the close and the last few blade frames
      // stutter.
      try? await Task.sleep(nanoseconds: 120_000_000)
      withAnimation(.easeInOut(duration: 0.2)) { self.mode = .live }
      await self.controller.start()
      // Block the open until the session has actually started producing frames,
      // otherwise the shutter would reveal a black preview surface.
      if !self.isSessionRunning {
        await self.waitUntilSessionRunning()
      }
    }
  }

  func cancelLive() {
    shutter.cycle {
      self.controller.stop()
      withAnimation(.easeInOut(duration: 0.2)) { self.mode = .idle }
      try? await Task.sleep(nanoseconds: 300_000_000)
    }
  }

  func flip() {
    shutter.cycle {
      // Tear the preview down before reconfiguring so the previous device's
      // last frame isn't held on the layer while the session swaps inputs.
      self.suppressPreview = true
      try? await Task.sleep(nanoseconds: 16_000_000)
      self.controller.flip()
      // Let the session swap inputs and start producing frames from the new
      // device before we remount the preview.
      try? await Task.sleep(nanoseconds: 250_000_000)
      self.suppressPreview = false
      // Tiny extra dwell so the remounted layer has actually drawn a new
      // frame before the shutter starts opening.
      try? await Task.sleep(nanoseconds: 150_000_000)
    }
  }

  func capture() async {
    guard mode == .live else { return }
    // Give SwiftUI a beat to finish the close animation before we kick off
    // the heavy mode-flip + session-start work — otherwise that work
    // crashes into the tail of the close and the last few blade frames
    // stutter.
    try? await Task.sleep(nanoseconds: 120_000_000)
    shutter.cycle(fastClose: true) {
      let image = await self.controller.capturePhoto()
      if let image {
        self.backdropImage = image
      }
      self.controller.stop()
      withAnimation(.easeInOut(duration: 0.2)) { self.mode = .idle }
    }
  }

  /// Used when the drawing canvas / DI view is being dismissed while the
  /// camera is live. Detach the live preview layer and stop the session
  /// synchronously, then hand control back so the caller can collapse its
  /// container. We deliberately do NOT run a shutter cycle here: racing the
  /// blade close/open against the container collapse caused the UI to appear
  /// frozen mid-close (the preview layer kept updating during the collapse
  /// and the cycle's open phase fought with `reset()` tearing it down).
  /// Keeping `mode == .live` preserves the dark canvas background, so the
  /// preview unmount reveals black (not white) while the container animates
  /// away.
  func dismissLiveCamera(completion: @escaping @MainActor () -> Void) {
    guard mode == .live else {
      completion()
      return
    }
    suppressPreview = true
    controller.stop()
    completion()
  }

  /// Fully reset — called when drawing canvas dismisses or the app backgrounds.
  /// Wraps state mutations in a no-animation transaction so the implicit
  /// `.animation(value: isCameraLive)` in DrawingCanvasView doesn't kick off
  /// an interpolation that gets stranded mid-frame (e.g. when the app is
  /// suspended and resumed, buttons can end up rendered at an intermediate
  /// transition state).
  func reset() {
    controller.stop()
    var tx = Transaction()
    tx.disablesAnimations = true
    withTransaction(tx) {
      mode = .idle
      backdropImage = nil
      suppressPreview = false
    }
    shutter.forceReset()
  }

  private func waitUntilSessionRunning() async {
    for await running in $isSessionRunning.values where running {
      return
    }
  }
}
