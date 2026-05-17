//
//  CameraPreviewView.swift
//  Joodle
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
  let session: AVCaptureSession
  /// The capture device currently feeding the session. Used to drive an
  /// `AVCaptureDeviceRotationCoordinator` so the preview's rotation tracks
  /// the device's natural orientation reliably across flips.
  var device: AVCaptureDevice?
  var mirrored: Bool = false

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> PreviewUIView {
    let view = PreviewUIView()
    view.backgroundColor = .black
    view.videoPreviewLayer.session = session
    view.videoPreviewLayer.videoGravity = .resizeAspectFill
    context.coordinator.bind(view: view, device: device, mirrored: mirrored)
    return view
  }

  func updateUIView(_ uiView: PreviewUIView, context: Context) {
    if uiView.videoPreviewLayer.session !== session {
      uiView.videoPreviewLayer.session = session
    }
    context.coordinator.bind(view: uiView, device: device, mirrored: mirrored)
  }

  static func dismantleUIView(_ uiView: PreviewUIView, coordinator: Coordinator) {
    coordinator.tearDown()
  }

  // MARK: - Coordinator

  final class Coordinator: NSObject {
    private weak var previewView: PreviewUIView?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var currentDevice: AVCaptureDevice?
    private var currentMirrored: Bool = false
    private var pendingRebuildToken: Int = 0

    /// Rebind the coordinator to the current view/device/mirror state. Idempotent
    /// when nothing changed.
    func bind(view: PreviewUIView, device: AVCaptureDevice?, mirrored: Bool) {
      self.previewView = view
      self.currentMirrored = mirrored

      // Mirror state can be updated on the existing connection without
      // rebuilding the rotation coordinator.
      applyMirror(to: view.videoPreviewLayer.connection)

      // Rotation coordinator must be rebuilt whenever the active device
      // changes (flip). `AVCaptureDevice.RotationCoordinator` is main-thread
      // bound, but its allocation/KVO setup is expensive enough that doing it
      // synchronously here stalls the next render — which on flip is the
      // first frame of the shutter open animation. Defer it one runloop tick
      // so the current commit (including the animation) gets to paint first.
      if device !== currentDevice {
        currentDevice = device
        pendingRebuildToken &+= 1
        let token = pendingRebuildToken
        let layer = view.videoPreviewLayer
        DispatchQueue.main.async { [weak self] in
          guard let self, token == self.pendingRebuildToken else { return }
          self.rebuildRotationCoordinator(for: device, previewLayer: layer)
        }
      }
    }

    func tearDown() {
      rotationObservation?.invalidate()
      rotationObservation = nil
      rotationCoordinator = nil
      previewView = nil
    }

    private func rebuildRotationCoordinator(
      for device: AVCaptureDevice?,
      previewLayer: AVCaptureVideoPreviewLayer
    ) {
      rotationObservation?.invalidate()
      rotationObservation = nil
      rotationCoordinator = nil

      guard let device else { return }

      let coordinator = AVCaptureDevice.RotationCoordinator(
        device: device,
        previewLayer: previewLayer
      )
      rotationCoordinator = coordinator

      // Apply the current preferred angle immediately.
      applyRotation(coordinator.videoRotationAngleForHorizonLevelPreview, to: previewLayer.connection)

      // Observe future changes (e.g. mid-flight reconfigures).
      rotationObservation = coordinator.observe(
        \.videoRotationAngleForHorizonLevelPreview,
         options: [.new]
      ) { [weak self] coord, _ in
        guard let self else { return }
        DispatchQueue.main.async {
          self.applyRotation(
            coord.videoRotationAngleForHorizonLevelPreview,
            to: self.previewView?.videoPreviewLayer.connection
          )
        }
      }
    }

    private func applyRotation(_ angle: CGFloat, to connection: AVCaptureConnection?) {
      guard let connection else { return }
      if connection.isVideoRotationAngleSupported(angle) {
        connection.videoRotationAngle = angle
      }
    }

    private func applyMirror(to connection: AVCaptureConnection?) {
      guard let connection else { return }
      if connection.isVideoMirroringSupported {
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = currentMirrored
      }
    }
  }

  final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
      // swiftlint:disable:next force_cast
      layer as! AVCaptureVideoPreviewLayer
    }
  }
}
