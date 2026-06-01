//
//  CameraReferenceController.swift
//  Joodle
//

@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
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
  /// Continuously fed by the live preview stream. Capturing the backdrop reads
  /// the most-recent frame here instead of running a full photo capture — a
  /// 12-MP `AVCapturePhotoOutput` shot (sensor read → JPEG encode → re-decode)
  /// added ~hundreds of ms of shutter latency just to produce a downsampled,
  /// 30%-opacity tracing reference. The saved polaroid is only ~1024px, so a
  /// preview-resolution frame is more than enough for both uses.
  private let videoDataOutput = AVCaptureVideoDataOutput()
  private let frameQueue = DispatchQueue(label: "dev.liyuxuan.joodle.camera.frames")
  private let frameLock = NSLock()
  private var latestPixelBuffer: CVPixelBuffer?
  /// Camera position of `latestPixelBuffer`, derived from the delivering
  /// connection so the orientation correction matches the active camera even
  /// across a flip. Guarded by `frameLock`.
  private var latestFramePosition: AVCaptureDevice.Position = .back
  private let backdropContext = CIContext(options: [
    .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
  ])
  private var currentInput: AVCaptureDeviceInput?
  private var didConfigure = false
  private var didRegisterRunningObservers = false

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
      // (Re)attach the frame delegate on each start. `stop()` detaches it so a
      // retained frame can't stall session teardown, so it must be re-armed
      // here rather than once at configuration time.
      self.videoDataOutput.setSampleBufferDelegate(self, queue: self.frameQueue)
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
      // Detach the frame delegate and release the retained frame BEFORE
      // stopping: `stopRunning()` blocks until every buffer vended by the
      // video data output is returned to its pool, so a held `latestPixelBuffer`
      // would stall the stop — which in turn stalled preview/session teardown
      // and left the canvas black for seconds on dismiss.
      self.videoDataOutput.setSampleBufferDelegate(nil, queue: nil)
      self.frameLock.lock()
      self.latestPixelBuffer = nil
      self.frameLock.unlock()
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

  /// Freezes the most-recent live frame into a square, downsampled, upright
  /// `UIImage` for use as the tracing backdrop. Returns instantly — no shutter,
  /// no photo-output round trip.
  func latestBackdrop(maxPixelDimension: CGFloat = 1024) -> UIImage? {
    guard let cg = latestFrameSquareImage(maxPixelDimension: maxPixelDimension) else { return nil }
    return UIImage(cgImage: cg, scale: 1, orientation: .up)
  }

  /// Persists a filtered polaroid built from the latest live frame. Grabs a
  /// *detached* square `CGImage` synchronously (so it survives the subsequent
  /// `stop()` releasing the pool buffer), then runs the colour grade + JPEG
  /// encode on a background queue so the heavy work never blocks the capture.
  func saveLatestFrameToAlbum() {
    guard let square = latestFrameSquareImage(maxPixelDimension: 2048) else { return }
    DispatchQueue.global(qos: .utility).async {
      guard let data = Self.makePolaroid(from: square) else { return }
      Self.savePolaroidToPhotosAlbum(data: data)
    }
  }

  /// Orients the latest live frame upright (per camera position), center-crops
  /// it to a square, and downsamples to `maxPixelDimension` on the short side.
  private func latestFrameSquareImage(maxPixelDimension: CGFloat) -> CGImage? {
    frameLock.lock()
    let buffer = latestPixelBuffer
    let position = latestFramePosition
    frameLock.unlock()
    guard let buffer else { return nil }

    var ciImage = CIImage(cvPixelBuffer: buffer)
    // Frames arrive in raw landscape sensor orientation (we leave the
    // connection's rotation/mirroring untouched — setting them on the video
    // data output both inverts the rotation under mirroring and can stall the
    // front-camera connection after a flip). Rotate to upright portrait in
    // code: back → 90° CW, front → 90° CW + horizontal mirror (selfie).
    let orientation: CGImagePropertyOrientation = (position == .front) ? .leftMirrored : .right
    ciImage = ciImage.oriented(orientation)
    let extent = ciImage.extent
    let side = min(extent.width, extent.height)
    guard side > 0 else { return nil }
    let cropRect = CGRect(
      x: extent.midX - side / 2,
      y: extent.midY - side / 2,
      width: side,
      height: side
    )
    ciImage = ciImage.cropped(to: cropRect)
    let scale = min(1, maxPixelDimension / side)
    if scale < 1 {
      ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
    return backdropContext.createCGImage(ciImage, from: ciImage.extent)
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
    if session.canAddOutput(videoDataOutput) {
      videoDataOutput.alwaysDiscardsLateVideoFrames = true
      videoDataOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
      ]
      // The frame delegate is attached in `start()` (and detached in `stop()`),
      // not here — see `stop()` for why.
      session.addOutput(videoDataOutput)
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
    // Deliver raw, unmirrored, unrotated frames. Orientation/mirroring is
    // applied in code when a frame is grabbed (see `latestFrameSquareImage`),
    // because manipulating the video-data-output connection's rotation here
    // inverted under front-camera mirroring (−90° result) and could stall the
    // front feed after a flip reconfigure.
    for connection in videoDataOutput.connections where connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = false
    }
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraReferenceController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    // Resolve the camera position from the delivering connection so a frame is
    // always oriented for the camera that actually produced it.
    var position: AVCaptureDevice.Position = .back
    for port in connection.inputPorts {
      if let deviceInput = port.input as? AVCaptureDeviceInput {
        position = deviceInput.device.position
        break
      }
    }
    // Keep only the most-recent frame. `alwaysDiscardsLateVideoFrames` plus
    // holding a single buffer keeps us from starving the output's pool.
    frameLock.lock()
    latestPixelBuffer = buffer
    latestFramePosition = position
    frameLock.unlock()
  }

  /// Persist a polaroid-framed, colour-graded version of a square source image
  /// to the user's Photos album.
  private static func savePolaroidToPhotosAlbum(data: Data) {
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

  /// Applies the Fujifilm grade to an already-square `CGImage`, then composites
  /// it onto a white canvas with uniform padding — a polaroid-style framed
  /// JPEG. Falls back to the un-graded image if the grade fails.
  private static func makePolaroid(from squareImage: CGImage) -> Data? {
    let graded = FujifilmFilter.apply(to: squareImage, grade: .classicNegative) ?? squareImage
    let side = CGFloat(min(graded.width, graded.height))
    guard side > 0 else { return nil }
    let photo = UIImage(cgImage: graded, scale: 1, orientation: .up)

    let paddingFraction: CGFloat = 0.08
    let paddingPx = floor(side * paddingFraction)
    let canvasSize = CGSize(width: side + paddingPx * 2, height: side + paddingPx * 2)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
    return renderer.jpegData(withCompressionQuality: 0.9) { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: canvasSize))
      photo.draw(in: CGRect(x: paddingPx, y: paddingPx, width: side, height: side))
    }
  }
}
