//
//  DrawingAnimationConfig.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Foundation

/// Configuration for drawing animation timing and export settings
struct DrawingAnimationConfig {
  /// Maximum total animation duration in seconds
  let maxDuration: Double

  /// Duration per pixel of stroke length (seconds)
  let durationPerPixel: Double

  /// Minimum duration for very short strokes/dots
  let minStrokeDuration: Double

  /// Frame rate for export (frames per second)
  let frameRate: Int

  /// Total number of frames to generate
  var totalFrameCount: Int {
    Int(ceil(maxDuration * Double(frameRate)))
  }

  /// Duration per frame in seconds
  var frameDuration: Double {
    1.0 / Double(frameRate)
  }

  // MARK: - Presets

  /// Default configuration matching DrawingDisplayView animation
  static let `default` = DrawingAnimationConfig(
    maxDuration: 3.0,
    durationPerPixel: 0.2 / 50.0,
    minStrokeDuration: 0.05,
    frameRate: 15
  )
  
  /// Configuration optimized for video export (higher frame rate, smoother)
  static let video = DrawingAnimationConfig(
    maxDuration: 3.0,
    durationPerPixel: 0.2 / 50.0,
    minStrokeDuration: 0.05,
    frameRate: 30
  )

  // MARK: - Timing Calculation

  /// Calculate stroke timing info for a set of paths
  /// - Parameter pathsWithMetadata: The paths with their metadata
  /// - Returns: Tuple of (durations per stroke, total duration, cumulative end times)
  func calculateStrokeTiming(for pathsWithMetadata: [PathWithMetadata]) -> (durations: [Double], totalDuration: Double, cumulativeEndTimes: [Double]) {
    guard !pathsWithMetadata.isEmpty else {
      return ([], 0, [])
    }

    // Calculate raw duration for each stroke based on length
    var rawDurations: [Double] = pathsWithMetadata.map { pathWithMetadata in
      if pathWithMetadata.metadata.isDot {
        return minStrokeDuration
      } else {
        let lengthBasedDuration = Double(pathWithMetadata.metadata.length) * durationPerPixel
        return max(minStrokeDuration, lengthBasedDuration)
      }
    }

    let rawTotal = rawDurations.reduce(0, +)

    // If total exceeds max, scale down all durations proportionally
    if rawTotal > maxDuration {
      let scaleFactor = maxDuration / rawTotal
      rawDurations = rawDurations.map { $0 * scaleFactor }
    }

    let totalDuration = min(rawTotal, maxDuration)

    // Calculate cumulative end times for each stroke
    var cumulativeEndTimes: [Double] = []
    var cumulative: Double = 0
    for duration in rawDurations {
      cumulative += duration
      cumulativeEndTimes.append(cumulative)
    }

    return (rawDurations, totalDuration, cumulativeEndTimes)
  }

  /// Apply easeOut curve to linear progress
  /// - Parameter linearProgress: Progress value from 0.0 to 1.0
  /// - Returns: Eased progress value
  static func applyEaseOut(_ linearProgress: CGFloat) -> CGFloat {
    // EaseOut curve: 1 - (1 - t)^2
    return 1.0 - pow(1.0 - linearProgress, 2)
  }
}
