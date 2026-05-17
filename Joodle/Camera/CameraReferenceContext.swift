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
  /// Toggled true on shutter tap and back to false ~250ms later to drive a
  /// brief white flash over the live preview, mimicking a real-camera capture.
  @Published var captureFlashActive: Bool = false

  let controller: CameraReferenceController
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
  }

  var session: AVCaptureSession { controller.session }
  var isFrontFacing: Bool { controller.position == .front }

  func enterLive() async {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      // Already authorized — flip UI immediately, kick off session start async.
      withAnimation(.easeInOut(duration: 0.25)) { mode = .live }
      Task { await controller.start() }
    case .notDetermined:
      // First-time request must await the system prompt before we know whether
      // to enter live mode at all.
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      if granted {
        controller.permissionState = .granted
        withAnimation(.easeInOut(duration: 0.25)) { mode = .live }
        Task { await controller.start() }
      } else {
        controller.permissionState = .denied
        showPermissionDeniedAlert = true
      }
    case .denied, .restricted:
      showPermissionDeniedAlert = true
    @unknown default:
      showPermissionDeniedAlert = true
    }
  }

  func cancelLive() {
    controller.stop()
    withAnimation(.easeInOut(duration: 0.25)) { mode = .idle }
  }

  func flip() {
    controller.flip()
  }

  func capture() async {
    guard mode == .live else { return }
    // Kick off the shutter flash animation immediately so it appears the moment
    // the user taps the button, even before the photo callback returns.
    withAnimation(.easeOut(duration: 0.05)) {
      captureFlashActive = true
    }
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 200_000_000)
      withAnimation(.easeOut(duration: 0.3)) {
        captureFlashActive = false
      }
    }
    let image = await controller.capturePhoto()
    if let image {
      backdropImage = image
    }
    controller.stop()
    withAnimation(.easeInOut(duration: 0.25)) { mode = .idle }
  }

  /// Fully reset — called when drawing canvas dismisses.
  func reset() {
    controller.stop()
    mode = .idle
    backdropImage = nil
  }
}


