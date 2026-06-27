//
//  CameraZoomSlider.swift
//  Joodle
//

import SwiftUI

/// A vertical, log-scaled camera zoom slider with snap-to-key-factor ticks.
///
/// Purely presentational: it renders the current `zoomFactor` and reports new
/// values through `onChange`. It holds no camera or session state — the only
/// mutable state is the in-flight drag.
struct CameraZoomSlider: View {
  var zoomFactor: CGFloat
  var range: ClosedRange<CGFloat>
  var keyFactors: [CGFloat]
  var onChange: (CGFloat) -> Void

  /// Track height. Kept compact so the slider tucks against the canvas edge.
  private let trackHeight: CGFloat = 210
  private let trackWidth: CGFloat = 36
  private let thumbSize: CGFloat = 26

  /// While dragging, a key factor within this fraction of the track snaps.
  private let snapThreshold: CGFloat = 0.045

  /// Live drag position as a 0...1 fraction of the track (0 = bottom/min,
  /// 1 = top/max). `nil` when not dragging, so the view follows `zoomFactor`.
  @GestureState private var dragFraction: CGFloat?

  /// The zoom the pill/thumb should reflect: the in-flight drag value while
  /// dragging, otherwise the externally driven `zoomFactor`.
  private var effectiveZoom: CGFloat {
    if let dragFraction {
      return zoom(forFraction: dragFraction)
    }
    return zoomFactor
  }

  var body: some View {
    VStack(spacing: 8) {
      valuePill
      track
    }
  }

  // MARK: - Value pill

  private var valuePill: some View {
    Text(Self.format(effectiveZoom))
      .font(.appFont(size: 13, weight: .semibold))
      .monospacedDigit()
      .foregroundStyle(.appAccent)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .glassPill()
      .animation(.easeOut(duration: 0.12), value: effectiveZoom)
  }

  // MARK: - Track

  private var track: some View {
    ZStack {
      Capsule()
        .fill(.appSurface.opacity(0.001)) // keeps the whole column hit-testable
        .frame(width: trackWidth, height: trackHeight)
        .glassPill()

      keyTicks

      thumb
        .position(
          x: trackWidth / 2,
          y: thumbCenterY(forFraction: fraction(forZoom: effectiveZoom))
        )
    }
    .frame(width: trackWidth, height: trackHeight)
    .contentShape(Capsule())
    .gesture(dragGesture)
  }

  private var keyTicks: some View {
    ForEach(keyFactors, id: \.self) { factor in
      let isActive = abs(effectiveZoom - factor) < 0.01
      Text(Self.format(factor))
        .font(.appFont(size: 10, weight: isActive ? .bold : .medium))
        .foregroundStyle(isActive ? Color.appAccent : .appTextSecondary)
        .frame(width: trackWidth)
        .position(
          x: trackWidth / 2,
          y: thumbCenterY(forFraction: fraction(forZoom: factor))
        )
        .contentShape(Rectangle())
        .onTapGesture { onChange(clamp(factor)) }
        .animation(.easeOut(duration: 0.12), value: isActive)
    }
  }

  private var thumb: some View {
    Circle()
      .fill(.appAccent)
      .frame(width: thumbSize, height: thumbSize)
      .overlay {
        Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2)
      }
      .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
  }

  // MARK: - Drag

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 0)
      .updating($dragFraction) { value, state, _ in
        state = snapped(fraction: fractionFromY(value.location.y))
      }
      .onChanged { value in
        onChange(zoom(forFraction: snapped(fraction: fractionFromY(value.location.y))))
      }
  }

  /// Snaps to the nearest key factor when the gesture lands close to it.
  private func snapped(fraction rawFraction: CGFloat) -> CGFloat {
    let nearest = keyFactors
      .map { (factor: $0, distance: abs(fraction(forZoom: $0) - rawFraction)) }
      .min { $0.distance < $1.distance }
    if let nearest, nearest.distance < snapThreshold {
      return fraction(forZoom: nearest.factor)
    }
    return rawFraction
  }

  // MARK: - Geometry helpers

  /// y of the track top/bottom that the thumb center can reach, inset so the
  /// thumb never overflows the capsule.
  private func thumbCenterY(forFraction t: CGFloat) -> CGFloat {
    let inset = thumbSize / 2
    let usable = trackHeight - thumbSize
    // Fraction 1 (max) is at the top, 0 (min) at the bottom.
    return inset + (1 - t.clamped()) * usable
  }

  private func fractionFromY(_ y: CGFloat) -> CGFloat {
    let inset = thumbSize / 2
    let usable = trackHeight - thumbSize
    guard usable > 0 else { return 0 }
    return (1 - (y - inset) / usable).clamped()
  }

  // MARK: - Log-scale mapping

  /// Position fraction (0...1) for a zoom value on a log scale, so 0.5/1/2/3
  /// read as evenly spaced along the track.
  private func fraction(forZoom zoom: CGFloat) -> CGFloat {
    let lo = log(range.lowerBound)
    let hi = log(range.upperBound)
    guard hi > lo else { return 0 }
    return ((log(clamp(zoom)) - lo) / (hi - lo)).clamped()
  }

  private func zoom(forFraction t: CGFloat) -> CGFloat {
    let lo = log(range.lowerBound)
    let hi = log(range.upperBound)
    return clamp(exp(lo + t.clamped() * (hi - lo)))
  }

  private func clamp(_ value: CGFloat) -> CGFloat {
    min(max(value, range.lowerBound), range.upperBound)
  }

  // MARK: - Formatting

  /// "1x", "0.5x", "2x", "1.4x" — drops a trailing .0, else one decimal.
  private static func format(_ zoom: CGFloat) -> String {
    let rounded = (zoom * 10).rounded() / 10
    if rounded == rounded.rounded() {
      return "\(Int(rounded))x"
    }
    return String(format: "%.1fx", rounded)
  }
}

private extension CGFloat {
  func clamped() -> CGFloat { min(max(self, 0), 1) }
}

// MARK: - Glass styling

private extension View {
  /// Liquid Glass pill matching the app's `circularGlassButton` vocabulary,
  /// with an `.appSurface` fallback on pre-iOS 26.
  @ViewBuilder
  func glassPill() -> some View {
    if #available(iOS 26, *) {
      self.glassEffect(.regular.interactive(), in: Capsule())
    } else {
      self
        .background(.appSurface, in: Capsule())
    }
  }
}

#Preview {
  struct PreviewHost: View {
    @State private var zoom: CGFloat = 1.0
    var body: some View {
      ZStack {
        Color.black
        CameraZoomSlider(
          zoomFactor: zoom,
          range: 0.5...8,
          keyFactors: [0.5, 1, 2, 3],
          onChange: { zoom = $0 }
        )
      }
      .ignoresSafeArea()
    }
  }
  return PreviewHost()
}
