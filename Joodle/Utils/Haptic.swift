//
//  Haptic.swift
//  Joodle
//
//  Created by Li Yuxuan on 14/8/25.
//

import AudioToolbox
import UIKit

struct Haptic {

  /**
   Play a haptic with given intensity

   - Parameters: with intensity: feedback intensity, default light
   */
  static func play(with intensity: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    let isHapticEnabled = UserPreferences.shared.enableHaptic;
    guard isHapticEnabled else { return }

    let impactFeedback = UIImpactFeedbackGenerator(style: intensity)
    impactFeedback.impactOccurred()
  }

  /// A tick detent: a short UI "tock" paired with an impact, mirroring the
  /// click + tap the native Camera zoom control fires as it crosses zoom
  /// detents. Gated behind the same haptic preference so the two feedback
  /// channels stay in sync. `major` uses a heavier tap.
  static func playTick(major: Bool) {
    guard UserPreferences.shared.enableHaptic else { return }

    UIImpactFeedbackGenerator(style: major ? .medium : .light).impactOccurred()
    AudioServicesPlaySystemSound(1157) // short UI tick.
  }
}
