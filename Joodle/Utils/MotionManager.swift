//
//  MotionManager.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import CoreMotion
import SwiftUI

/// Manages device motion data for gyroscope-based UI effects
/// Thread-safe singleton that provides device roll angle for liquid level tilting
@MainActor
final class MotionManager: ObservableObject {
  static let shared = MotionManager()

  private let motionManager = CMMotionManager()
  private var referenceCount = 0

  /// Device tilt angle based on gravity's X component in radians (-π/2 to π/2)
  /// Uses asin(gravity.x) for stable readings independent of forward/backward pitch
  /// No discontinuities - works smoothly at all orientations including landscape and upside-down
  /// Positive = tilted right, Negative = tilted left
  @Published private(set) var tiltAngle: Double = 0.0

  /// Whether motion updates are currently active
  @Published private(set) var isActive: Bool = false

  /// Raw gravity direction components (device space, each in -1...1).
  /// `gravityX` is positive when the device is tilted right; `gravityY` is
  /// positive toward the top of the device. Consumers map these into screen
  /// space (screen-down ≈ `(gravityX, -gravityY)`) to drive liquid physics.
  @Published private(set) var gravityX: Double = 0.0
  @Published private(set) var gravityY: Double = -1.0

  /// Magnitude of user-induced acceleration in Gs (gravity removed), lightly
  /// smoothed. Spikes when the device is shaken; used to trigger liquid splashes.
  @Published private(set) var shakeMagnitude: Double = 0.0

  /// Smoothing factor for tilt updates (0-1, lower = smoother)
  private let smoothingFactor: Double = 0.15

  /// Lighter smoothing for the gravity vector so liquid stays responsive to tilt
  private let gravitySmoothingFactor: Double = 0.3

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
  /// Uses gravity vector for stable tilt detection independent of forward/backward pitch
  private func processMotionUpdate(_ motion: CMDeviceMotion) {
    let gravity = motion.gravity

    // Calculate tilt angle using asin(gravity.x)
    // gravity.x directly measures left-right tilt:
    // - 0 when device has no left-right tilt (portrait or upside-down)
    // - 1 when tilted 90° right (landscape, right edge down)
    // - -1 when tilted 90° left (landscape, left edge down)
    //
    // Using asin() converts this to an angle (-π/2 to π/2):
    // - No discontinuities at any orientation
    // - Independent of forward/backward pitch (gravity.z doesn't affect gravity.x)
    // - Works smoothly through landscape and upside-down orientations
    let clampedGravityX = max(-1.0, min(1.0, gravity.x))
    let newTiltAngle = asin(clampedGravityX)

    // Apply exponential smoothing for fluid motion
    tiltAngle = tiltAngle + (newTiltAngle - tiltAngle) * smoothingFactor

    // Smoothed gravity vector for liquid physics
    gravityX = gravityX + (gravity.x - gravityX) * gravitySmoothingFactor
    gravityY = gravityY + (gravity.y - gravityY) * gravitySmoothingFactor

    // User acceleration magnitude (gravity already removed by CoreMotion)
    let userAcceleration = motion.userAcceleration
    let magnitude = sqrt(
      userAcceleration.x * userAcceleration.x
        + userAcceleration.y * userAcceleration.y
        + userAcceleration.z * userAcceleration.z
    )
    shakeMagnitude = shakeMagnitude + (magnitude - shakeMagnitude) * 0.5
  }

  /// Reset motion values to neutral
  func reset() {
    tiltAngle = 0.0
    gravityX = 0.0
    gravityY = -1.0
    shakeMagnitude = 0.0
  }

  deinit {
    motionManager.stopDeviceMotionUpdates()
  }
}
