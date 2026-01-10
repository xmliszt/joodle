//
//  GIFExporter.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Exports an array of UIImages as an animated GIF
class GIFExporter {

  enum ExportError: Error {
    case noFrames
    case failedToCreateDestination
    case failedToFinalize
    case failedToConvertImage
  }

  /// Create an animated GIF from an array of frames
  /// - Parameters:
  ///   - frames: Array of UIImage frames
  ///   - frameDelay: Delay between frames in seconds
  ///   - loopCount: Number of loops (0 = infinite)
  /// - Returns: GIF data or nil if creation failed
  func createGIF(
    from frames: [UIImage],
    frameDelay: Double,
    loopCount: Int = 0
  ) -> Data? {
    guard !frames.isEmpty else { return nil }

    let fileProperties: [String: Any] = [
      kCGImagePropertyGIFDictionary as String: [
        kCGImagePropertyGIFLoopCount as String: loopCount
      ]
    ]

    let frameProperties: [String: Any] = [
      kCGImagePropertyGIFDictionary as String: [
        kCGImagePropertyGIFDelayTime as String: frameDelay,
        kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay
      ]
    ]

    guard let mutableData = CFDataCreateMutable(nil, 0) else {
      return nil
    }

    guard let destination = CGImageDestinationCreateWithData(
      mutableData,
      UTType.gif.identifier as CFString,
      frames.count,
      nil
    ) else {
      return nil
    }

    CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

    for frame in frames {
      // Ensure we have a CGImage
      guard let cgImage = frame.cgImage else {
        continue
      }
      CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
    }

    guard CGImageDestinationFinalize(destination) else {
      return nil
    }

    return mutableData as Data
  }

  /// Create an animated GIF and save to a temporary file
  /// - Parameters:
  ///   - frames: Array of UIImage frames
  ///   - frameDelay: Delay between frames in seconds
  ///   - loopCount: Number of loops (0 = infinite)
  /// - Returns: URL to the temporary GIF file
  func createGIFFile(
    from frames: [UIImage],
    frameDelay: Double,
    loopCount: Int = 0
  ) throws -> URL {
    guard !frames.isEmpty else {
      throw ExportError.noFrames
    }

    guard let gifData = createGIF(from: frames, frameDelay: frameDelay, loopCount: loopCount) else {
      throw ExportError.failedToFinalize
    }

    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "Joodle-Animated-\(UUID().uuidString).gif"
    let fileURL = tempDir.appendingPathComponent(fileName)

    try gifData.write(to: fileURL)

    return fileURL
  }

  /// Create an animated GIF with optimized settings for sharing
  /// - Parameters:
  ///   - frames: Array of UIImage frames
  ///   - config: Animation configuration containing frame rate
  ///   - loopCount: Number of loops (0 = infinite)
  /// - Returns: URL to the temporary GIF file
  func createGIFFile(
    from frames: [UIImage],
    config: DrawingAnimationConfig,
    loopCount: Int = 0
  ) throws -> URL {
    let frameDelay = config.frameDuration
    return try createGIFFile(from: frames, frameDelay: frameDelay, loopCount: loopCount)
  }
}
