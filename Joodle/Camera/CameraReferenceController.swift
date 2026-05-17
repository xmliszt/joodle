//
//  CameraReferenceController.swift
//  Joodle
//

import AVFoundation
import ImageIO
import Photos
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
  private var didRegisterRunningObservers = false

  private var captureContinuation: CheckedContinuation<UIImage?, Never>?
  /// Whether the next finished capture should be persisted to the user's
  /// Photos album. Set on the main actor immediately before invoking
  /// `photoOutput.capturePhoto` and read by the delegate callback.
  private var saveNextCaptureToAlbum: Bool = false

  /// Bridge AVCaptureSession's running notifications to `isRunning`. Reading
  /// `session.isRunning` synchronously right after `startRunning()` can return
  /// `false` while the session is still finishing interruption recovery (e.g.
  /// after iOS auto-paused it for a background transition) — that one-shot
  /// read would otherwise leave `isRunning` stuck at `false` forever, hanging
  /// `waitUntilSessionRunning` on the next live-mode entry.
  private func registerRunningObserversIfNeeded() {
    guard !didRegisterRunningObservers else { return }
    didRegisterRunningObservers = true
    let center = NotificationCenter.default
    center.addObserver(
      forName: .AVCaptureSessionDidStartRunning,
      object: session,
      queue: .main
    ) { [weak self] _ in
      self?.isRunning = true
    }
    center.addObserver(
      forName: .AVCaptureSessionDidStopRunning,
      object: session,
      queue: .main
    ) { [weak self] _ in
      self?.isRunning = false
    }
  }

  @MainActor
  func start() async {
    let granted = await ensureAuthorized()
    guard granted else { return }
    // Kick off session config + startRunning on the dedicated queue but do NOT
    // block here — the UI flips to camera mode immediately, and CameraPreviewView
    // retries connection setup until the session is running.
    registerRunningObserversIfNeeded()
    sessionQueue.async { [weak self] in
      guard let self else { return }
      self.configureSessionIfNeeded()
      if !self.session.isRunning {
        self.session.startRunning()
      }
      // `isRunning` is published by the didStartRunning notification observer;
      // don't write it here — `session.isRunning` can read false right after
      // `startRunning()` returns during interruption recovery.
    }
  }

  func stop() {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      if self.session.isRunning {
        self.session.stopRunning()
      }
      // `isRunning` is published by the didStopRunning notification observer.
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
  func capturePhoto(saveToAlbum: Bool = false) async -> UIImage? {
    guard isRunning else { return nil }
    let currentPosition = position
    self.saveNextCaptureToAlbum = saveToAlbum
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
        settings.photoQualityPrioritization = .speed
        // Batch all connection mutations into a single reconfigure. Without
        // begin/commitConfiguration each property write to a running session
        // can trigger its own XPC round-trip to mediaserverd, which on slow
        // configurations surfaces as `FigCaptureSourceRemote err=-17281` log
        // spam. We also skip writes that match the current value to avoid
        // touching the configuration at all when flip/init already set it.
        let wantMirrored = (currentPosition == .front)
        self.session.beginConfiguration()
        for connection in self.photoOutput.connections {
          if connection.isVideoMirroringSupported {
            if connection.automaticallyAdjustsVideoMirroring {
              connection.automaticallyAdjustsVideoMirroring = false
            }
            if connection.isVideoMirrored != wantMirrored {
              connection.isVideoMirrored = wantMirrored
            }
          }
          if let angle = captureAngle,
             connection.videoRotationAngle != angle,
             connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
          }
        }
        self.session.commitConfiguration()
        self.photoOutput.capturePhoto(with: settings, delegate: self)
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
    if let error {
      // AVFoundation occasionally fails a capture under thermal pressure or
      // mid-reconfigure (often co-occurring with the FigCaptureSourceRemote
      // err=-17281 console spam). We surface it to the log instead of
      // swallowing silently, but still resume the continuation with nil so
      // the caller falls back to idle mode cleanly.
      print("[CameraReferenceController] photo capture failed: \(error)")
    }
    let data = photo.fileDataRepresentation()
    // Image processing path used to be: UIImage(data:) → full-size upright
    // render → full-size square crop → downsample render. Three full bitmap
    // renders of a 12-MP photo on the photo-output delegate queue, which on
    // intermittent CPU pressure ballooned to ~800ms and starved the main
    // thread of frames during the fully-closed-to-open shutter transition.
    // ImageIO decodes once, downsamples in-decoder, and bakes the EXIF
    // orientation in a single pass — typically 30–60ms total.
    let image: UIImage? = data.flatMap { Self.makeBackdrop(from: $0, maxPixelDimension: 1024) }
    let shouldSave = saveNextCaptureToAlbum
    saveNextCaptureToAlbum = false
    if shouldSave, let data {
      Self.saveJPEGToPhotosAlbum(data: data)
    }
    let continuation = self.captureContinuation
    self.captureContinuation = nil
    continuation?.resume(returning: image)
  }

  /// Persist the full-resolution JPEG to the user's Photos album. Requests
  /// add-only authorization on first use; silently no-ops if the user denies.
  private static func saveJPEGToPhotosAlbum(data: Data) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else { return }
      PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, data: data, options: nil)
      } completionHandler: { success, error in
        if let error {
          print("[CameraReferenceController] save to album failed: \(error)")
        } else if !success {
          print("[CameraReferenceController] save to album returned !success")
        }
      }
    }
  }

  /// Decodes JPEG `data` into a square, orientation-baked, downsampled
  /// `UIImage` suitable for use as the canvas backdrop. Uses ImageIO so the
  /// 12-MP source is never materialized as a full bitmap.
  private static func makeBackdrop(from data: Data, maxPixelDimension: CGFloat) -> UIImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      // Oversample slightly so the post-thumbnail square crop still meets the
      // target pixel dimension on its shortest side.
      kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelDimension * 1.5),
    ]
    guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      return nil
    }
    let w = CGFloat(thumb.width)
    let h = CGFloat(thumb.height)
    let side = min(w, h)
    let cropRect = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
    let cropped = thumb.cropping(to: cropRect) ?? thumb
    return UIImage(cgImage: cropped, scale: 1, orientation: .up)
  }
}
