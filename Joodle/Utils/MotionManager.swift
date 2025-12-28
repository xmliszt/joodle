//
//  MotionManager.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import CoreMotion
import SwiftUI

/// Manages device motion data for gyroscope-based UI effects
/// Thread-safe singleton that provides device roll angle for water level tilting
@MainActor
final class MotionManager: ObservableObject {
  static let shared = MotionManager()

  private let motionManager = CMMotionManager()
  private var referenceCount = 0

  /// Device roll angle in radians (-π to π)
  /// Positive = tilted right, Negative = tilted left
  @Published private(set) var roll: Double = 0.0

  /// Device pitch angle in radians
  @Published private(set) var pitch: Double = 0.0

  /// Whether motion updates are currently active
  @Published private(set) var isActive: Bool = false

  /// Maximum tilt angle to apply (in radians) - clamps extreme tilts
  private let maxTiltAngle: Double = .pi / 4  // 45 degrees

  /// Smoothing factor for roll updates (0-1, lower = smoother)
  private let smoothingFactor: Double = 0.15

  private init() {}

  /// Start receiving motion updates
  /// Uses reference counting to allow multiple views to share the manager
  func startUpdates() {
    referenceCount += 1

    guard referenceCount == 1 else { return }
    guard motionManager.isDeviceMotionAvailable else {
      print("MotionManager: Device motion not available")
      return
    }

    motionManager.startDeviceMotionUpdates(
      using: .xArbitraryZVertical,
      to: .main
    ) { [weak self] motion, error in
      guard let self = self, let motion = motion else {
        if let error = error {
          print("MotionManager error: \(error.localizedDescription)")
        }
        return
      }

      Task { @MainActor in
        self.processMotionUpdate(motion)
      }
    }

    isActive = true
  }

  /// Stop receiving motion updates
  /// Only actually stops when all references are released
  func stopUpdates() {
    referenceCount = max(0, referenceCount - 1)

    guard referenceCount == 0 else { return }

    motionManager.stopDeviceMotionUpdates()
    isActive = false
  }

  /// Process incoming motion data with smoothing
  private func processMotionUpdate(_ motion: CMDeviceMotion) {
    let attitude = motion.attitude

    // Get roll from device attitude
    // Roll represents rotation around the Y axis (left-right tilt when holding phone upright)
    let newRoll = attitude.roll

    // Clamp to max tilt angle
    let clampedRoll = max(-maxTiltAngle, min(maxTiltAngle, newRoll))

    // Apply exponential smoothing for fluid motion
    roll = roll + (clampedRoll - roll) * smoothingFactor

    // Also track pitch for potential future use
    pitch = attitude.pitch
  }

  /// Reset motion values to neutral
  func reset() {
    roll = 0.0
    pitch = 0.0
  }

  deinit {
    motionManager.stopDeviceMotionUpdates()
  }
}
