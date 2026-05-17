//
//  CameraReferenceController.swift
//  Joodle
//

import AVFoundation
import SwiftUI
import UIKit

enum CameraPermissionState {
  case unknown
  case granted
  case denied
}

extension Notification.Name {
  /// Posted (on main) after the camera session has been reconfigured — e.g. on
  /// flipping the active camera. Allows the preview layer's coordinator to
  /// re-apply orientation/mirroring to the freshly-rebuilt connection, since
  /// `didStartRunningNotification` doesn't fire for mid-flight reconfigures.
  static let cameraSessionConfigurationDidChange = Notification.Name("CameraSessionConfigurationDidChange")
}

final class CameraReferenceController: NSObject, ObservableObject, @unchecked Sendable {
  @Published var position: AVCaptureDevice.Position = .back
  @Published var permissionState: CameraPermissionState = .unknown
  @Published var isRunning: Bool = false
  /// The capture device currently feeding the session. Consumers (e.g. the
  /// preview layer's rotation coordinator) observe this to know which device
  /// to track for orientation/mirror.
  @Published var currentDevice: AVCaptureDevice?

  let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "dev.liyuxuan.joodle.camera.session")
  private let photoOutput = AVCapturePhotoOutput()
  private var currentInput: AVCaptureDeviceInput?
  private var didConfigure = false

  private var captureContinuation: CheckedContinuation<UIImage?, Never>?

  @MainActor
  func start() async {
    let granted = await ensureAuthorized()
    guard granted else { return }
    // Kick off session config + startRunning on the dedicated queue but do NOT
    // block here — the UI flips to camera mode immediately, and CameraPreviewView
    // retries connection setup until the session is running.
    sessionQueue.async { [weak self] in
      guard let self else { return }
      self.configureSessionIfNeeded()
      if !self.session.isRunning {
        self.session.startRunning()
      }
      let running = self.session.isRunning
      DispatchQueue.main.async { [weak self] in
        self?.isRunning = running
      }
    }
  }

  func stop() {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      if self.session.isRunning {
        self.session.stopRunning()
      }
      DispatchQueue.main.async { [weak self] in
        self?.isRunning = false
      }
    }
  }

  @MainActor
  func flip() {
    let newPosition: AVCaptureDevice.Position = (position == .back) ? .front : .back
    position = newPosition
    sessionQueue.async { [weak self] in
      guard let self else { return }
      self.session.beginConfiguration()
      if let current = self.currentInput {
        self.session.removeInput(current)
      }
      var newDevice: AVCaptureDevice?
      if let newInput = Self.makeInput(position: newPosition),
         self.session.canAddInput(newInput) {
        self.session.addInput(newInput)
        self.currentInput = newInput
        newDevice = newInput.device
        self.applyMirroring(for: newPosition)
      }
      self.session.commitConfiguration()
      let sessionRef = self.session
      DispatchQueue.main.async { [weak self] in
        self?.currentDevice = newDevice
        NotificationCenter.default.post(
          name: .cameraSessionConfigurationDidChange,
          object: sessionRef
        )
      }
    }
  }

  /// Captured atomically when capturePhoto is invoked so the delegate callback
  /// can post-process based on which camera was active at trigger time.
  private var positionAtCapture: AVCaptureDevice.Position = .back

  @MainActor
  func capturePhoto() async -> UIImage? {
    guard isRunning else { return nil }
    let currentPosition = position
    // Compute the correct capture rotation angle for the active device using
    // Apple's rotation coordinator (per-device, accounts for front-camera's
    // mirrored/flipped sensor orientation).
    let captureAngle: CGFloat? = {
      guard let device = currentDevice else { return nil }
      let coord = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
      return coord.videoRotationAngleForHorizonLevelCapture
    }()
    return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
      self.captureContinuation = continuation
      self.positionAtCapture = currentPosition
      sessionQueue.async { [weak self] in
        guard let self else { return }
        let settings = AVCapturePhotoSettings()
        self.applyCaptureMirror(for: currentPosition)
        if let angle = captureAngle {
          for connection in self.photoOutput.connections {
            if connection.isVideoRotationAngleSupported(angle) {
              connection.videoRotationAngle = angle
            }
          }
        }
        self.photoOutput.capturePhoto(with: settings, delegate: self)
      }
    }
  }

  private func applyCaptureMirror(for position: AVCaptureDevice.Position) {
    for connection in photoOutput.connections {
      if connection.isVideoMirroringSupported {
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = (position == .front)
      }
    }
  }

  // MARK: - Permission

  @MainActor
  private func ensureAuthorized() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      permissionState = .granted
      return true
    case .notDetermined:
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      permissionState = granted ? .granted : .denied
      return granted
    case .denied, .restricted:
      permissionState = .denied
      return false
    @unknown default:
      permissionState = .denied
      return false
    }
  }

  // MARK: - Session config (called on sessionQueue)

  private func configureSessionIfNeeded() {
    guard !didConfigure else { return }
    didConfigure = true
    let initialPosition: AVCaptureDevice.Position = .back
    session.beginConfiguration()
    session.sessionPreset = .photo
    var initialDevice: AVCaptureDevice?
    if let input = Self.makeInput(position: initialPosition), session.canAddInput(input) {
      session.addInput(input)
      currentInput = input
      initialDevice = input.device
    }
    if session.canAddOutput(photoOutput) {
      session.addOutput(photoOutput)
    }
    applyMirroring(for: initialPosition)
    session.commitConfiguration()
    DispatchQueue.main.async { [weak self] in
      self?.currentDevice = initialDevice
    }
  }

  private static func makeInput(position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
      return nil
    }
    return try? AVCaptureDeviceInput(device: device)
  }

  private func applyMirroring(for position: AVCaptureDevice.Position) {
    for connection in photoOutput.connections {
      if connection.isVideoMirroringSupported {
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = (position == .front)
      }
      if #available(iOS 17.0, *) {
        if connection.isVideoRotationAngleSupported(90) {
          connection.videoRotationAngle = 90
        }
      }
    }
  }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraReferenceController: AVCapturePhotoCaptureDelegate {
  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    let data = photo.fileDataRepresentation()
    let image: UIImage? = {
      guard let data, let raw = UIImage(data: data) else { return nil }
      // Bake imageOrientation into pixels first so subsequent cropping works in
      // the visible coordinate space — otherwise front-camera (which arrives
      // with mirrored/right-rotated EXIF) gets cropped from the wrong region.
      let upright = Self.upright(raw)
      return Self.centerCroppedSquare(upright)
    }()
    let continuation = self.captureContinuation
    self.captureContinuation = nil
    continuation?.resume(returning: image)
  }

  /// Renders the image into a new bitmap with `imageOrientation == .up`,
  /// preserving the visible content exactly as the user saw it in the preview
  /// (including any mirroring applied by the capture connection).
  private static func upright(_ image: UIImage) -> UIImage {
    if image.imageOrientation == .up { return image }
    let format = UIGraphicsImageRendererFormat()
    format.scale = image.scale
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }

  private static func centerCroppedSquare(_ image: UIImage) -> UIImage {
    let s: CGFloat = min(image.size.width, image.size.height)
    let format = UIGraphicsImageRendererFormat()
    format.scale = image.scale
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: format)
    return renderer.image { _ in
      let xOff = (image.size.width - s) / 2
      let yOff = (image.size.height - s) / 2
      image.draw(at: CGPoint(x: -xOff, y: -yOff))
    }
  }
}
