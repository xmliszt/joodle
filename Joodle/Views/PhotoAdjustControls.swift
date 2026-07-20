//
//  PhotoAdjustControls.swift
//  Joodle
//
//  Controls for positioning the captured tracing-reference photo:
//
//  • `PhotoTranslationPad` — a native-Camera-style 2-axis scrub pad. A grid of
//    dots magnifies and glows radially around the touch point (the glow decays
//    with distance), so dragging the finger reads as directly nudging the photo
//    left/right/up/down. A haptic fires on touch-down.
//
//  • `PhotoRotationRuler` — a creased arc ruler that hugs the bottom of the
//    drawing canvas. Its curve is concentric with the canvas's rounded corners
//    (radius = canvasCornerRadius + gap) so the two radii transition smoothly.
//    Sliding scrubs a continuous, unclamped rotation, ticking (haptic + sound)
//    as each crease crosses the fixed center indicator.
//
//  Both are purely presentational — they render the current value and report new
//  ones through callbacks. Double-tapping resets (recenter / level).
//

import SwiftUI

// MARK: - Translation pad

struct PhotoTranslationPad: View {
  /// Current translation of the photo, in canvas points.
  var offset: CGSize
  /// Canvas-point translation that corresponds to full deflection to the pad
  /// edge. Larger = the same drag nudges the photo further.
  var translationRange: CGFloat
  var onOffsetChange: (CGSize) -> Void

  private let padSide: CGFloat = 208
  private let containerPadding: CGFloat = 14
  /// Spacing of the dot lattice.
  private let dotSpacing: CGFloat = 20
  private let baseDotRadius: CGFloat = 1.5
  /// Extra radius a dot gains right under the cursor.
  private let magnifyRadius: CGFloat = 4.5
  /// Reach of the soft white glow halo around the cursor.
  private let glowRadius: CGFloat = 52
  /// Gaussian falloff (points) of the per-dot magnify/brighten influence.
  private let influenceSigma: CGFloat = 34
  /// Dead-band around each center line where the cursor snaps to 0.
  private let centerSnap: CGFloat = 6

  /// True while a finger is down, so the glow brightens and touch-down fires a
  /// single haptic.
  @State private var isTouching = false
  /// Axis sign (-1/0/1) so a light tick fires once as the cursor snaps onto a
  /// center line rather than every frame.
  @State private var lastAxisSign = (x: 0, y: 0)

  private static var darkAccent: Color {
    Color(UIColor(.appAccent).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
  }

  /// Maximum cursor travel from center along either axis.
  private var padTravel: CGFloat { padSide / 2 - 10 }

  private var cursor: CGPoint {
    let half = padSide / 2
    let nx = min(max(offset.width / max(translationRange, 0.0001), -1), 1)
    let ny = min(max(offset.height / max(translationRange, 0.0001), -1), 1)
    return CGPoint(x: half + nx * padTravel, y: half + ny * padTravel)
  }

  var body: some View {
    Canvas(opaque: false) { context, size in
      let c = cursor

      // Soft radial glow halo around the cursor — brighter while touching, fading
      // to clear at its edge.
      let glowRect = CGRect(x: c.x - glowRadius, y: c.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
      context.fill(
        Circle().path(in: glowRect),
        with: .radialGradient(
          Gradient(colors: [Color.white.opacity(isTouching ? 0.55 : 0.34), .clear]),
          center: c,
          startRadius: 0,
          endRadius: glowRadius
        )
      )

      // Dot lattice — each dot magnifies and brightens toward the cursor.
      let cols = max(1, Int(size.width / dotSpacing))
      let rows = max(1, Int(size.height / dotSpacing))
      let startX = (size.width - CGFloat(cols - 1) * dotSpacing) / 2
      let startY = (size.height - CGFloat(rows - 1) * dotSpacing) / 2
      for i in 0..<cols {
        for j in 0..<rows {
          let p = CGPoint(x: startX + CGFloat(i) * dotSpacing, y: startY + CGFloat(j) * dotSpacing)
          let d = hypot(p.x - c.x, p.y - c.y)
          let influence = exp(-pow(d / influenceSigma, 2))
          let r = baseDotRadius + magnifyRadius * influence
          let op = 0.22 + 0.78 * influence
          let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
          context.fill(Circle().path(in: rect), with: .color(.white.opacity(op)))
        }
      }

      // Bright accent core at the cursor.
      let coreR = baseDotRadius + magnifyRadius + 2
      let coreRect = CGRect(x: c.x - coreR, y: c.y - coreR, width: coreR * 2, height: coreR * 2)
      context.fill(Circle().path(in: coreRect), with: .color(.white))
      context.stroke(Circle().path(in: coreRect), with: .color(Self.darkAccent.opacity(0.9)), lineWidth: 1.5)
    }
    .frame(width: padSide, height: padSide)
    .contentShape(Rectangle())
    .gesture(padDrag)
    .simultaneousGesture(TapGesture(count: 2).onEnded {
      Haptic.play(with: .light)
      lastAxisSign = (0, 0)
      onOffsetChange(.zero)
    })
    .padding(containerPadding)
    .background(
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .fill(Color.black)
        .overlay(
          RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    )
  }

  private var padDrag: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        if !isTouching {
          isTouching = true
          Haptic.play(with: .medium)
        }
        var dx = min(max(value.location.x - padSide / 2, -padTravel), padTravel)
        var dy = min(max(value.location.y - padSide / 2, -padTravel), padTravel)
        if abs(dx) < centerSnap { dx = 0 }
        if abs(dy) < centerSnap { dy = 0 }

        let sx = dx == 0 ? 0 : (dx > 0 ? 1 : -1)
        let sy = dy == 0 ? 0 : (dy > 0 ? 1 : -1)
        if sx != lastAxisSign.x || sy != lastAxisSign.y {
          if sx == 0 || sy == 0 { Haptic.play(with: .light) }
          lastAxisSign = (sx, sy)
        }

        onOffsetChange(CGSize(
          width: dx / padTravel * translationRange,
          height: dy / padTravel * translationRange
        ))
      }
      .onEnded { _ in isTouching = false }
  }
}

// MARK: - Rotation ruler

struct PhotoRotationRuler: View {
  /// Current photo rotation (unbounded — scrubbing continues indefinitely).
  var rotation: Angle
  /// Corner radius of the drawing canvas, so the ruler's end curves are
  /// concentric with — and smoothly continue — the canvas's rounded corners.
  var canvasCornerRadius: CGFloat
  /// Width of the ruler; matches the canvas so it sits flush beneath it.
  var width: CGFloat
  var onRotationChange: (Angle) -> Void

  private let height: CGFloat = 64
  /// Gap from the canvas bottom (ruler top, y = 0) to the straight baseline.
  private let gap: CGFloat = 9
  /// Horizontal points per degree of rotation — sets crease spacing.
  private let pointsPerDegree: CGFloat = 5
  /// Crease every this many degrees.
  private let tickStepDegrees: Double = 2
  /// Longer crease + accent every this many degrees.
  private let majorStepDegrees: Double = 10
  private let minorTickLength: CGFloat = 9
  private let majorTickLength: CGFloat = 15

  /// Rotation (deg) captured at drag start, so movement is relative.
  @State private var dragAnchorDegrees: Double?
  /// Last crease index crossed, so a tick fires once per crease.
  @State private var lastTickIndex: Int = .min

  private static var darkAccent: Color {
    Color(UIColor(.appAccent).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
  }

  /// Radius of the concentric baseline arc (canvas corner + gap).
  private var arcRadius: CGFloat { canvasCornerRadius + gap }

  /// A point on the ruler baseline for horizontal position `x`, plus the unit
  /// normal pointing outward (down/away from the canvas) — the crease direction.
  /// Straight in the middle; concentric with the canvas corners near the ends.
  private func baseline(atX x: CGFloat) -> (point: CGPoint, normal: CGVector)? {
    let leftStraight = canvasCornerRadius
    let rightStraight = width - canvasCornerRadius
    if x >= leftStraight && x <= rightStraight {
      return (CGPoint(x: x, y: gap), CGVector(dx: 0, dy: 1))
    }
    // On a corner arc: center sits at the canvas corner center (y = -radius).
    let centerX = x < leftStraight ? canvasCornerRadius : (width - canvasCornerRadius)
    let center = CGPoint(x: centerX, y: -canvasCornerRadius)
    let dx = x - center.x
    guard abs(dx) <= arcRadius else { return nil }
    let dy = sqrt(arcRadius * arcRadius - dx * dx) // downward branch
    let point = CGPoint(x: x, y: center.y + dy)
    guard point.y >= 0 else { return nil } // stop where the arc rises into the canvas
    let len = sqrt(dx * dx + dy * dy)
    guard len > 0 else { return nil }
    return (point, CGVector(dx: dx / len, dy: dy / len))
  }

  var body: some View {
    Canvas(opaque: false) { context, size in
      let mid = size.width / 2
      let accent = Self.darkAccent
      let rot = rotation.degrees

      // Value shown at each x: center indicator reads the current rotation, and
      // the ruler scrolls so creases move opposite the drag (ruler-follows-finger).
      let leftValue = rot + Double(-mid / pointsPerDegree)
      let rightValue = rot + Double(mid / pointsPerDegree)
      let firstTick = Int((leftValue / tickStepDegrees).rounded(.down))
      let lastTick = Int((rightValue / tickStepDegrees).rounded(.up))

      if lastTick >= firstTick {
        for t in firstTick...lastTick {
          let value = Double(t) * tickStepDegrees
          let x = mid + CGFloat(value - rot) * pointsPerDegree
          guard let (p, n) = baseline(atX: x) else { continue }

          let isMajor = (t % Int((majorStepDegrees / tickStepDegrees).rounded())) == 0
          let length = isMajor ? majorTickLength : minorTickLength
          // Fade creases toward the ruler ends for the native soft-edge feel.
          let fade = max(0, 1 - pow(abs(x - mid) / mid, 1.6))
          let end = CGPoint(x: p.x + n.dx * length, y: p.y + n.dy * length)
          var crease = Path()
          crease.move(to: p)
          crease.addLine(to: end)
          context.stroke(
            crease,
            with: .color(.white.opacity((isMajor ? 0.55 : 0.3) * fade)),
            style: StrokeStyle(lineWidth: isMajor ? 2 : 1.4, lineCap: .round)
          )
        }
      }

      // Fixed center indicator — the accent crease the current rotation sits under.
      if let (p, n) = baseline(atX: mid) {
        let end = CGPoint(x: p.x + n.dx * (majorTickLength + 4), y: p.y + n.dy * (majorTickLength + 4))
        var pointer = Path()
        pointer.move(to: p)
        pointer.addLine(to: end)
        context.stroke(pointer, with: .color(accent), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
      }
    }
    .frame(width: width, height: height)
    .contentShape(Rectangle())
    .gesture(rulerDrag)
    .simultaneousGesture(TapGesture(count: 2).onEnded {
      Haptic.playTick(major: true)
      lastTickIndex = 0
      onRotationChange(.zero)
    })
  }

  private var rulerDrag: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let anchor = dragAnchorDegrees ?? rotation.degrees
        if dragAnchorDegrees == nil { dragAnchorDegrees = anchor }
        // Ruler follows the finger: dragging right scrolls the creases right, so
        // the value under the fixed center indicator decreases.
        let newDegrees = anchor - Double(value.translation.width) / Double(pointsPerDegree)

        let index = Int((newDegrees / tickStepDegrees).rounded())
        if index != lastTickIndex {
          lastTickIndex = index
          let major = (index % Int((majorStepDegrees / tickStepDegrees).rounded())) == 0
          Haptic.playTick(major: major)
        }

        onRotationChange(.degrees(newDegrees))
      }
      .onEnded { _ in dragAnchorDegrees = nil }
  }
}

// MARK: - Previews

#Preview("Translation pad") {
  struct Host: View {
    @State private var offset: CGSize = .zero
    var body: some View {
      ZStack {
        LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
        PhotoTranslationPad(offset: offset, translationRange: 205, onOffsetChange: { offset = $0 })
      }
      .ignoresSafeArea()
    }
  }
  return Host()
}

#Preview("Rotation ruler") {
  struct Host: View {
    @State private var rotation: Angle = .zero
    var body: some View {
      ZStack {
        Color.black
        VStack(spacing: 0) {
          RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(Color.gray.opacity(0.4))
            .frame(width: 342, height: 200)
          PhotoRotationRuler(
            rotation: rotation,
            canvasCornerRadius: 36,
            width: 342,
            onRotationChange: { rotation = $0 }
          )
        }
      }
      .ignoresSafeArea()
    }
  }
  return Host()
}
