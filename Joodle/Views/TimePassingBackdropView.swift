//
//  TimePassingBackdropView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// A backdrop view that visualizes the passing of time as a draining water level
/// - The water level starts full at 00:00:00 and drains throughout the day
/// - Features animated wave effects on the water surface
/// - Responds to device tilt via gyroscope for realistic water behavior
struct TimePassingBackdropView: View {
  @StateObject private var motionManager = MotionManager.shared

  /// Whether the backdrop should be visible
  var isVisible: Bool = true

  /// Current time progress through the day (0 = midnight, 1 = end of day)
  @State private var dayProgress: Double = 0.0

  /// Timer for updating time
  @State private var timer: Timer?

  /// Animated visibility offset for water rising/draining effect (0 = fully visible, 1 = fully hidden below screen)
  /// Initialized based on isVisible state
  @State private var visibilityOffset: Double?

  /// Wave animation parameters
  private let primaryWaveAmplitude: CGFloat = 8
  private let secondaryWaveAmplitude: CGFloat = 5
  private let tertiaryWaveAmplitude: CGFloat = 3
  private let waveFrequency: CGFloat = 1.5

  /// Wave animation speed (seconds per full cycle)
  private let waveAnimationDuration: Double = 3.0

  /// Duration for water rising animation (appearing)
  private let waterRiseDuration: Double = 2.5

  /// Duration for water draining animation (disappearing)
  private let waterDrainDuration: Double = 0.8

  var body: some View {
    TimelineView(.animation) { timeline in
      let elapsedTime = timeline.date.timeIntervalSinceReferenceDate
      let wavePhase = (elapsedTime / waveAnimationDuration) * .pi * 2

      GeometryReader { geometry in
        let fillLevel = 1.0 - dayProgress
        // Use tiltAngle for tilt - based on gravity.x, independent of forward/backward pitch
        // sin(tiltAngle) gives bounded tilt effect (-1 to 1) that works at all orientations
        // including landscape and upside-down without blowing up like tan() would
        let tiltOffset = CGFloat(sin(motionManager.tiltAngle)) * geometry.size.width * 0.5

        ZStack {
          // Water fill with wave top
          WaterWaveShape(
            progress: fillLevel,
            wavePhase: wavePhase,
            primaryAmplitude: primaryWaveAmplitude,
            secondaryAmplitude: secondaryWaveAmplitude,
            tertiaryAmplitude: tertiaryWaveAmplitude,
            frequency: waveFrequency,
            tiltOffset: tiltOffset
          )
          .fill(Color.appAccent.opacity(0.85))

          // Secondary wave layer for depth effect
          WaterWaveShape(
            progress: fillLevel,
            wavePhase: wavePhase + .pi / 3,
            primaryAmplitude: primaryWaveAmplitude * 0.7,
            secondaryAmplitude: secondaryWaveAmplitude * 0.6,
            tertiaryAmplitude: tertiaryWaveAmplitude * 0.5,
            frequency: waveFrequency * 1.2,
            tiltOffset: tiltOffset * 0.8
          )
          .fill(Color.appAccent.opacity(0.4))
        }
        // Apply vertical offset to push water down when hidden
        // Use actual water height (fillLevel * height) so animation distance matches visible water
        .offset(y: geometry.size.height * fillLevel * (visibilityOffset ?? (isVisible ? 0.0 : 1.0)))
      }
    }
    .opacity(isVisible ? 0.2 : 0.0)
    .onAppear {
      // Set initial offset based on visibility without animation
      if visibilityOffset == nil {
        visibilityOffset = isVisible ? 0.0 : 1.0
      }
      startUpdates()
    }
    .onDisappear {
      stopUpdates()
    }
    .onChange(of: isVisible) { _, newValue in
      animateVisibilityChange(visible: newValue)
    }
  }

  /// Start time and motion updates
  private func startUpdates() {
    updateDayProgress()
    motionManager.startUpdates()

    // Update time every second
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      updateDayProgress()
    }
  }

  /// Stop all updates
  private func stopUpdates() {
    timer?.invalidate()
    timer = nil
    motionManager.stopUpdates()
  }

  /// Calculate and update the current day progress
  private func updateDayProgress() {
    let calendar = Calendar.current
    let now = Date()
    let startOfDay = calendar.startOfDay(for: now)
    let secondsSinceMidnight = now.timeIntervalSince(startOfDay)
    let totalSecondsInDay: Double = 24 * 60 * 60

    withAnimation(.linear(duration: 0.5)) {
      dayProgress = secondsSinceMidnight / totalSecondsInDay
    }
  }

  /// Animate the water rising or draining based on visibility change
  private func animateVisibilityChange(visible: Bool) {
    if visible {
      // Water rises up from bottom - slower, gentle easing
      withAnimation(.easeOut(duration: waterRiseDuration)) {
        visibilityOffset = 0.0
      }
    } else {
      // Water drains down - slightly faster
      withAnimation(.easeIn(duration: waterDrainDuration)) {
        visibilityOffset = 1.0
      }
    }
  }
}

// MARK: - Water Wave Shape

/// Custom shape that draws a water surface with multiple overlapping sine waves
/// Supports tilt offset for gyroscope-based leveling effect
struct WaterWaveShape: Shape {
  /// Fill level from 0 (empty) to 1 (full)
  var progress: Double

  /// Phase offset for wave animation
  var wavePhase: Double

  /// Amplitude of the primary wave
  var primaryAmplitude: CGFloat

  /// Amplitude of the secondary wave
  var secondaryAmplitude: CGFloat

  /// Amplitude of the tertiary wave
  var tertiaryAmplitude: CGFloat

  /// Frequency multiplier for waves
  var frequency: CGFloat

  /// Horizontal offset from device tilt
  var tiltOffset: CGFloat

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()

    let waterLevel = rect.height * (1 - progress)
    let width = rect.width

    // Start from bottom-left
    path.move(to: CGPoint(x: 0, y: rect.height))

    // Draw left edge up to water level
    path.addLine(to: CGPoint(x: 0, y: waterLevel + calculateTiltY(at: 0, width: width)))

    // Draw wave across the top
    let stepSize: CGFloat = 2
    var x: CGFloat = 0

    while x <= width {
      let relativeX = x / width
      let tiltY = calculateTiltY(at: x, width: width)

      // Combine multiple sine waves for organic look
      let primary = sin(relativeX * .pi * 2 * frequency + wavePhase) * primaryAmplitude
      let secondary = sin(relativeX * .pi * 4 * frequency + wavePhase * 1.5) * secondaryAmplitude
      let tertiary = sin(relativeX * .pi * 6 * frequency + wavePhase * 0.7) * tertiaryAmplitude

      let waveY = primary + secondary + tertiary
      let y = waterLevel + waveY + tiltY

      path.addLine(to: CGPoint(x: x, y: y))
      x += stepSize
    }

    // Complete the shape
    path.addLine(to: CGPoint(x: width, y: rect.height))
    path.closeSubpath()

    return path
  }

  /// Calculate Y offset at a given X position based on tilt
  /// Creates the effect of water staying level when device is tilted
  private func calculateTiltY(at x: CGFloat, width: CGFloat) -> CGFloat {
    // Normalize x to -0.5 to 0.5 range (center = 0)
    let normalizedX = (x / width) - 0.5
    // Apply tilt - when tilted right (positive), left side goes up, right side goes down
    return -normalizedX * tiltOffset * 2
  }
}

// MARK: - Preview

#Preview("Time Passing Backdrop") {
  ZStack {
    Color.backgroundColor

    TimePassingBackdropView()
  }
  .ignoresSafeArea()
}

#Preview("Hidden State") {
  ZStack {
    Color.backgroundColor

    TimePassingBackdropView(isVisible: false)
  }
  .ignoresSafeArea()
}

#Preview("50% Progress") {
  ZStack {
    Color.backgroundColor

    GeometryReader { geometry in
      WaterWaveShape(
        progress: 0.5,
        wavePhase: 0,
        primaryAmplitude: 8,
        secondaryAmplitude: 5,
        tertiaryAmplitude: 3,
        frequency: 1.5,
        tiltOffset: 0
      )
      .fill(Color.appAccent.opacity(0.85))
    }
  }
  .ignoresSafeArea()
}

#Preview("25% Progress - Morning") {
  ZStack {
    Color.backgroundColor

    GeometryReader { geometry in
      WaterWaveShape(
        progress: 0.75,
        wavePhase: 0,
        primaryAmplitude: 8,
        secondaryAmplitude: 5,
        tertiaryAmplitude: 3,
        frequency: 1.5,
        tiltOffset: 0
      )
      .fill(Color.appAccent.opacity(0.85))
    }
  }
  .ignoresSafeArea()
}

#Preview("Tilted Right") {
  ZStack {
    Color.backgroundColor

    GeometryReader { geometry in
      WaterWaveShape(
        progress: 0.5,
        wavePhase: 0,
        primaryAmplitude: 8,
        secondaryAmplitude: 5,
        tertiaryAmplitude: 3,
        frequency: 1.5,
        tiltOffset: 100
      )
      .fill(Color.appAccent.opacity(0.85))
    }
  }
  .ignoresSafeArea()
}
