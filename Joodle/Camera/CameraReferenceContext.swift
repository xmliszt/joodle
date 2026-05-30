//
//  CameraReferenceContext.swift
//  Joodle
//
//  Shared camera state owned by ContentView and consumed by both DrawingCanvasView
//  (for the in-canvas live preview, top-row controls, in-sheet shutter on non-DI)
//  and ContentView itself (for the fullscreen blurred backdrop and the DI shutter
//  overlay rendered outside the drawing container).
//

@preconcurrency import AVFoundation
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
  /// the shared preview layer while the session swaps inputs, and during
  /// `.inactive` scene-phase transitions so the iOS snapshot doesn't capture
  /// a live AVCaptureVideoPreviewLayer (which then takes a long time to
  /// reconcile on return to foreground).
  @Published var suppressPreview: Bool = false
  /// Bumped on every photo capture. Consumers observe this to trigger a brief
  /// black-flash overlay — fakes a "shutter snap" so the capture feels
  /// instantaneous, without the latency cost of an actual shutter animation.
  @Published var captureFlashID: UUID? = nil

  #if DEBUG
  /// Debug-only override: when true, the camera behaves as if the user denied
  /// permission — `enterLive()` surfaces the permission-denied alert and
  /// `isCameraAccessBlocked` reports true. Lets us exercise the denial / skip
  /// paths even on the simulator (where the camera is otherwise faked) or on a
  /// device without re-denying in system Settings. In-memory only (resets on
  /// launch), mirroring `AppEnvironment.simulateProductionEnvironment`.
  /// Toggled from Settings → Developer Options.
  static var debugSimulateCameraDenied = false
  #endif

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

  /// True when camera access has been explicitly denied or restricted, so
  /// entering live mode is impossible. Callers (e.g. the tutorial) use this to
  /// avoid re-invoking `enterLive()` — which would just re-trigger the
  /// permission-denied alert — and route around the camera flow instead.
  var isCameraAccessBlocked: Bool {
    #if DEBUG
    if Self.debugSimulateCameraDenied { return true }
    #endif
    // Real authorization status — valid on the simulator too, which tracks
    // camera permission even though it has no hardware.
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .denied, .restricted:
      return true
    default:
      return false
    }
  }

  func enterLive() async {
    #if DEBUG
    // Debug switch to exercise the permission-denied path on demand. Checked
    // before the real flow so it works in either build.
    if Self.debugSimulateCameraDenied {
      showPermissionDeniedAlert = true
      return
    }
    #endif

    // Real camera permission request. This runs on the simulator too — it
    // tracks camera authorization (and shows the system prompt) even without
    // hardware — so the grant/deny flow is testable everywhere. Only the
    // session *start* below has to be faked on the simulator.
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

    #if targetEnvironment(simulator)
    // The simulator has no camera hardware: starting a real session would never
    // produce frames and `waitUntilSessionRunning()` would hang forever. Fake a
    // live session so the camera-reference UI and onboarding tutorial stay
    // testable; SharedCanvasView shows a placeholder in place of the live feed.
    shutter.cycle {
      try? await Task.sleep(nanoseconds: 120_000_000)
      if Task.isCancelled { return }
      withAnimation(.easeInOut(duration: 0.2)) { self.mode = .live }
    }
    #else
    shutter.cycle {
      // Give SwiftUI a beat to finish the close animation before we kick off
      // the heavy mode-flip + session-start work — otherwise that work
      // crashes into the tail of the close and the last few blade frames
      // stutter.
      try? await Task.sleep(nanoseconds: 120_000_000)
      // `reset()` (e.g. canvas dismissed mid-cycle) cancels the cycle's Task.
      // `try?` swallows the cancellation, so without this guard we'd fall
      // through and flip `mode` back to `.live` after `reset()` set it to
      // `.idle`, wedging the next canvas-open in camera UI.
      if Task.isCancelled { return }
      withAnimation(.easeInOut(duration: 0.2)) { self.mode = .live }
      await self.controller.start()
      if Task.isCancelled { return }
      // Block the open until the session has actually started producing frames,
      // otherwise the shutter would reveal a black preview surface.
      if !self.isSessionRunning {
        await self.waitUntilSessionRunning()
      }
    }
    #endif
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
      if Task.isCancelled { return }
      // Arm the notification observer BEFORE asking the controller to flip,
      // so we don't miss the post on fast reconfigures.
      let configChanged = self.awaitNextSessionConfigurationChange()
      self.controller.flip()
      // Wait for the controller's commitConfiguration to post
      // cameraSessionConfigurationDidChange — exact signal that the new device
      // is bound to the session — rather than a fixed sleep that's too short
      // on cold front-camera spin-up and wastefully long otherwise. The helper
      // caps the wait at 600ms so a missed notification can't hang the cycle.
      await configChanged.value
      if Task.isCancelled { return }
      self.suppressPreview = false
      // Tiny dwell so the remounted preview layer has actually drawn a new
      // frame before the shutter starts opening.
      try? await Task.sleep(nanoseconds: 80_000_000)
    }
  }

  func capture() async {
    guard mode == .live else { return }
    captureFlashID = UUID()
    #if targetEnvironment(simulator)
    // No camera to capture from — synthesize a placeholder reference photo so
    // the "trace over your reference" step is reachable on the simulator.
    self.backdropImage = Self.makeSimulatorPlaceholderImage()
    withAnimation(.easeInOut(duration: 0.2)) { self.mode = .idle }
    #else
    let saveToAlbum = UserPreferences.shared.saveCapturedPhotoToAlbum
    let image = await self.controller.capturePhoto(saveToAlbum: saveToAlbum)
    if let image {
      self.backdropImage = image
    }
    self.controller.stop()
    withAnimation(.easeInOut(duration: 0.2)) { self.mode = .idle }
    #endif
  }

  #if targetEnvironment(simulator)
  /// A static stand-in "reference photo" used on the simulator, which has no
  /// camera. Rendered once on demand so the captured-backdrop / trace step
  /// shows something recognizable instead of an empty frame.
  static func makeSimulatorPlaceholderImage() -> UIImage {
    let size = CGSize(width: 1024, height: 1024)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      let cgContext = context.cgContext
      let colors = [UIColor.systemIndigo.cgColor, UIColor.systemPurple.cgColor]
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: [0, 1]
      ) {
        cgContext.drawLinearGradient(
          gradient,
          start: .zero,
          end: CGPoint(x: size.width, y: size.height),
          options: []
        )
      }
      let config = UIImage.SymbolConfiguration(pointSize: 280, weight: .regular)
      if let symbol = UIImage(systemName: "camera.viewfinder", withConfiguration: config)?
        .withTintColor(.white.withAlphaComponent(0.85), renderingMode: .alwaysOriginal) {
        let origin = CGPoint(
          x: (size.width - symbol.size.width) / 2,
          y: (size.height - symbol.size.height) / 2
        )
        symbol.draw(at: origin)
      }
    }
  }
  #endif

  /// Returns a Task that completes the next time the camera controller posts
  /// `cameraSessionConfigurationDidChange`, or after a 600ms safety cap if
  /// the notification is missed.
  private func awaitNextSessionConfigurationChange() -> Task<Void, Never> {
    Task {
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          // Filter by name only — AVCaptureSession isn't Sendable, so passing
          // it as the `object` filter into a detached Task is a concurrency
          // warning. The camera controller is the sole poster of this
          // notification, so a name-only filter is unambiguous.
          let stream = NotificationCenter.default.notifications(
            named: .cameraSessionConfigurationDidChange
          )
          for await _ in stream { return }
        }
        group.addTask {
          try? await Task.sleep(nanoseconds: 600_000_000)
        }
        _ = await group.next()
        group.cancelAll()
      }
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
