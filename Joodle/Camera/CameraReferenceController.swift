//
//  CameraReferenceController.swift
//  Joodle
//

@preconcurrency import AVFoundation
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
    let device = currentDevice
    self.saveNextCaptureToAlbum = saveToAlbum
    return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
      self.captureContinuation = continuation
      self.positionAtCapture = currentPosition
      sessionQueue.async { [weak self] in
        guard let self else { return }
        // Compute the rotation angle on the session queue, not main — the
        // RotationCoordinator initializer touches device internals and on
        // the front camera that's a noticeable synchronous cost. Doing it
        // here keeps main free to start the capture-flash animation
        // immediately after the user's tap.
        let captureAngle: CGFloat? = device.map { d in
          AVCaptureDevice.RotationCoordinator(device: d, previewLayer: nil)
            .videoRotationAngleForHorizonLevelCapture
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .speed
        // Write connection properties live — they do NOT require
        // begin/commitConfiguration on a running session, and wrapping them
        // in one forces an XPC reconfigure with mediaserverd per shot that
        // adds tens of ms before AVFoundation even starts the capture.
        // Guard each write so we only touch the connection when the desired
        // value actually differs.
        let wantMirrored = (currentPosition == .front)
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
      // Cap the photo pipeline at .speed so AVFoundation pre-allocates the
      // lightweight processing path. Without this the output prepares for
      // .balanced (the default cap) and per-shot .speed can't fully claw
      // back the latency. Must be set after the output is added.
      photoOutput.maxPhotoQualityPrioritization = .speed
      // Front-camera capture defaults to applying content-aware distortion
      // correction on TrueDepth devices, which adds ~50–150ms of post-
      // processing per shot. We're using the photo as a small backdrop
      // reference (downsampled to 1024px), not a hero portrait — the
      // correction isn't perceptible at that size.
      if photoOutput.isContentAwareDistortionCorrectionSupported {
        photoOutput.isContentAwareDistortionCorrectionEnabled = false
      }
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
    let continuation = self.captureContinuation
    self.captureContinuation = nil
    continuation?.resume(returning: image)
    if shouldSave, let data {
      DispatchQueue.global(qos: .utility).async {
        Self.savePolaroidToPhotosAlbum(data: data)
      }
    }
  }

  /// Persist a polaroid-framed version of the captured photo to the user's
  /// Photos album. The source JPEG is center-cropped to a square (matching the
  /// canvas viewport) and given a uniform white border.
  private static func savePolaroidToPhotosAlbum(data: Data) {
    guard let polaroidData = makePolaroid(from: data) else { return }
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else { return }
      PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, data: polaroidData, options: nil)
      } completionHandler: { success, error in
        if let error {
          print("[CameraReferenceController] save to album failed: \(error)")
        } else if !success {
          print("[CameraReferenceController] save to album returned !success")
        }
      }
    }
  }

  /// Center-crops the source JPEG to a square, then composites it onto a white
  /// canvas with uniform padding — producing a polaroid-style framed image.
  private static func makePolaroid(from data: Data) -> Data? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: 1024,
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      return nil
    }
    let w = CGFloat(cgImage.width)
    let h = CGFloat(cgImage.height)
    let side = min(w, h)
    let cropRect = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
    guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
    let photo = UIImage(cgImage: cropped, scale: 1, orientation: .up)

    let paddingFraction: CGFloat = 0.08
    let paddingPx = floor(side * paddingFraction)
    let canvasSize = CGSize(width: side + paddingPx * 2, height: side + paddingPx * 2)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
    let polaroid = renderer.jpegData(withCompressionQuality: 0.9) { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: canvasSize))
      photo.draw(in: CGRect(x: paddingPx, y: paddingPx, width: side, height: side))
    }
    return polaroid
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
