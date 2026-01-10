//
//  VideoExporter.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import AVFoundation
import UIKit
import CoreMedia

/// Exports an array of UIImages as an MP4 video
class VideoExporter {

  enum ExportError: Error, LocalizedError {
    case noFrames
    case failedToCreateWriter
    case failedToCreatePixelBuffer
    case writingFailed(Error?)
    case cancelled

    var errorDescription: String? {
      switch self {
      case .noFrames:
        return "No frames to export"
      case .failedToCreateWriter:
        return "Failed to create video writer"
      case .failedToCreatePixelBuffer:
        return "Failed to create pixel buffer"
      case .writingFailed(let error):
        return "Video writing failed: \(error?.localizedDescription ?? "Unknown error")"
      case .cancelled:
        return "Export was cancelled"
      }
    }
  }

  /// Create an MP4 video from an array of frames
  /// - Parameters:
  ///   - frames: Array of UIImage frames
  ///   - frameRate: Frames per second
  ///   - outputURL: Optional output URL (will create temp file if nil)
  /// - Returns: URL to the video file
  func createVideo(
    from frames: [UIImage],
    frameRate: Int,
    outputURL: URL? = nil
  ) async throws -> URL {
    guard !frames.isEmpty else {
      throw ExportError.noFrames
    }

    guard let firstFrame = frames.first, let cgImage = firstFrame.cgImage else {
      throw ExportError.noFrames
    }

    let size = CGSize(width: cgImage.width, height: cgImage.height)

    // Create output URL if not provided
    let videoURL: URL
    if let outputURL = outputURL {
      videoURL = outputURL
    } else {
      let tempDir = FileManager.default.temporaryDirectory
      let fileName = "Joodle-Animated-\(UUID().uuidString).mp4"
      videoURL = tempDir.appendingPathComponent(fileName)
    }

    // Remove existing file if present
    if FileManager.default.fileExists(atPath: videoURL.path) {
      try? FileManager.default.removeItem(at: videoURL)
    }

    // Create asset writer
    let writer: AVAssetWriter
    do {
      writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
    } catch {
      throw ExportError.failedToCreateWriter
    }

    // Video settings for H.264 encoding
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: Int(size.width),
      AVVideoHeightKey: Int(size.height),
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: Int(size.width * size.height * 4), // Reasonable bitrate
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: frameRate // Keyframe every second
      ]
    ]

    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    writerInput.expectsMediaDataInRealTime = false

    // Pixel buffer attributes
    let sourcePixelBufferAttributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
      kCVPixelBufferWidthKey as String: Int(size.width),
      kCVPixelBufferHeightKey as String: Int(size.height),
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: writerInput,
      sourcePixelBufferAttributes: sourcePixelBufferAttributes
    )

    guard writer.canAdd(writerInput) else {
      throw ExportError.failedToCreateWriter
    }

    writer.add(writerInput)

    // Start writing
    guard writer.startWriting() else {
      throw ExportError.writingFailed(writer.error)
    }

    writer.startSession(atSourceTime: .zero)

    let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

    // Write frames
    for (index, frame) in frames.enumerated() {
      // Wait for input to be ready
      while !writerInput.isReadyForMoreMediaData {
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
      }

      // Check for cancellation
      try Task.checkCancellation()

      // Create pixel buffer from image
      guard let pixelBuffer = createPixelBuffer(from: frame, size: size, adaptor: adaptor) else {
        continue
      }

      let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))

      guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
        throw ExportError.writingFailed(writer.error)
      }
    }

    // Finish writing
    writerInput.markAsFinished()

    await writer.finishWriting()

    if writer.status == .failed {
      throw ExportError.writingFailed(writer.error)
    }

    return videoURL
  }

  /// Create an MP4 video with configuration-based settings
  /// - Parameters:
  ///   - frames: Array of UIImage frames
  ///   - config: Animation configuration containing frame rate
  /// - Returns: URL to the video file
  func createVideo(
    from frames: [UIImage],
    config: DrawingAnimationConfig
  ) async throws -> URL {
    return try await createVideo(from: frames, frameRate: config.frameRate)
  }

  /// Create a pixel buffer from a UIImage
  private func createPixelBuffer(
    from image: UIImage,
    size: CGSize,
    adaptor: AVAssetWriterInputPixelBufferAdaptor
  ) -> CVPixelBuffer? {
    guard let cgImage = image.cgImage else { return nil }

    var pixelBuffer: CVPixelBuffer?

    // Try to get from pool first
    if let pool = adaptor.pixelBufferPool {
      let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
      guard status == kCVReturnSuccess else { return nil }
    } else {
      // Create manually if pool not available
      let attributes: [String: Any] = [
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        kCVPixelBufferWidthKey as String: Int(size.width),
        kCVPixelBufferHeightKey as String: Int(size.height),
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)
      ]

      let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        Int(size.width),
        Int(size.height),
        kCVPixelFormatType_32ARGB,
        attributes as CFDictionary,
        &pixelBuffer
      )

      guard status == kCVReturnSuccess else { return nil }
    }

    guard let buffer = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    guard let context = CGContext(
      data: CVPixelBufferGetBaseAddress(buffer),
      width: Int(size.width),
      height: Int(size.height),
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
    ) else {
      return nil
    }

    // Draw the image directly without flipping - UIImage's cgImage is already in correct orientation
    context.draw(cgImage, in: CGRect(origin: .zero, size: size))

    return buffer
  }
}
