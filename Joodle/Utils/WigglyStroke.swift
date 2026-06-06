//
//  WigglyStroke.swift
//  Joodle
//
//  Experimental "wigglypaint" boiling-line effect: a stroke is redrawn with
//  small per-vertex random offsets that flip between a few discrete states at a
//  low frame rate, giving doodles a lively, hand-shaky shimmer.
//

import CoreGraphics
import Foundation
import SwiftUI

/// Stateless generator for the wigglypaint-style boiling-line effect.
///
/// The "boil" is deliberately *discrete*: instead of smoothly interpolating, we
/// snap between a small set of jittered states (`frameCount`) at `fps`. That
/// stepped quality is what reads as a hand-drawn wiggle rather than a wobble.
///
/// Offsets are derived from a hash of `(vertexIndex, frame)`, so a given vertex
/// occupies the same position every time that frame comes around — the loop is
/// stable and allocation-free aside from the rebuilt `Path`.
enum WigglyStroke {
  /// Number of distinct jittered states cycled through.
  static let frameCount = 3

  /// How many times per second the state advances. Low on purpose — a fast boil
  /// looks like noise; ~7fps reads as a lively pen.
  static let fps: Double = 7

  /// Seconds between boil steps. Drives a `.periodic` TimelineView so the canvas
  /// only redraws when the state actually changes (not at the 60fps display rate).
  static var boilInterval: TimeInterval { 1.0 / fps }

  /// Default peak offset, in canvas points (CANVAS_SIZE space). Scaled along
  /// with the rest of the drawing wherever the canvas is drawn smaller.
  static let defaultAmplitude: CGFloat = 1.6

  /// Discrete boil frame for a point in time. Drives the state cycling from a
  /// `TimelineView` clock.
  static func frameIndex(at time: TimeInterval) -> Int {
    let tick = Int((time * fps).rounded(.down))
    return ((tick % frameCount) + frameCount) % frameCount
  }

  /// Build a jittered path for one stroke at a given boil frame.
  ///
  /// - Parameters:
  ///   - points: the stroke's polyline vertices in canvas space.
  ///   - isDot: dots are rendered as a filled ellipse nudged by a single offset.
  ///   - frame: the current boil frame (`0 ..< frameCount`).
  ///   - amplitude: peak per-vertex offset in canvas points.
  static func path(
    points: [CGPoint],
    isDot: Bool,
    frame: Int,
    amplitude: CGFloat = defaultAmplitude
  ) -> Path {
    var path = Path()
    guard let first = points.first else { return path }

    if isDot {
      let o = offset(vertex: 0, frame: frame, amplitude: amplitude)
      let center = CGPoint(x: first.x + o.dx, y: first.y + o.dy)
      let r = DRAWING_LINE_WIDTH / 2
      path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
      return path
    }

    for (index, point) in points.enumerated() {
      let o = offset(vertex: index, frame: frame, amplitude: amplitude)
      let p = CGPoint(x: point.x + o.dx, y: point.y + o.dy)
      if index == 0 {
        path.move(to: p)
      } else {
        path.addLine(to: p)
      }
    }
    return path
  }

  // MARK: - Offsets

  /// Deterministic per-(vertex, frame) offset. The hash keeps endpoints of
  /// adjacent strokes from boiling in lockstep, and keeps each frame's state
  /// stable so the cycle loops cleanly.
  private static func offset(vertex: Int, frame: Int, amplitude: CGFloat) -> CGVector {
    let seed = UInt64(bitPattern: Int64(vertex)) &* 0x9E3779B97F4A7C15
      ^ UInt64(bitPattern: Int64(frame &+ 1)) &* 0xC2B2AE3D27D4EB4F
    let angle = unitRandom(seed) * 2 * .pi
    // Vary magnitude per vertex too so the line doesn't look like a rigid
    // shape sliding around — some vertices barely move, others swing wide.
    let magnitude = (0.35 + 0.65 * unitRandom(seed &* 0x100000001B3)) * Double(amplitude)
    return CGVector(dx: cos(angle) * magnitude, dy: sin(angle) * magnitude)
  }

  /// SplitMix64-style finalizer → uniform value in `0 ..< 1`.
  private static func unitRandom(_ input: UInt64) -> Double {
    var z = input &+ 0x9E3779B97F4A7C15
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    z = z ^ (z >> 31)
    return Double(z >> 11) * (1.0 / 9_007_199_254_740_992.0)  // 2^53
  }
}
