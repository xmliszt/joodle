//
//  PhotoTransformPad.swift
//  Joodle
//
//  A camera-style control panel for positioning the captured tracing-reference
//  photo. It pairs a 2-axis scrub pad — drag the puck to translate the photo
//  left/right/up/down — with a circular rotation arc hugging its bottom edge.
//  Modelled on the native Camera's filter/adjustment panels: an opaque black
//  tab with a hairline outline, accent puck/handle, and detent haptics.
//
//  Purely presentational: it renders the current `offset`/`rotation` and reports
//  new values through `onOffsetChange` / `onRotationChange`. Double-tapping the
//  pad recenters the photo; double-tapping the arc levels the rotation.
//

import SwiftUI

struct PhotoTransformPad: View {
  /// Current translation of the photo, in canvas points.
  var offset: CGSize
  /// Current rotation of the photo.
  var rotation: Angle
  /// Canvas-point translation that corresponds to full puck deflection to the
  /// pad edge. Larger = the same drag nudges the photo further.
  var translationRange: CGFloat
  /// Rotation reached at either end of the arc.
  var rotationLimit: Angle
  var onOffsetChange: (CGSize) -> Void
  var onRotationChange: (Angle) -> Void

  private let padSide: CGFloat = 140
  private let arcHeight: CGFloat = 52
  private let containerPadding: CGFloat = 14
  private let puckRadius: CGFloat = 11
  private let handleRadius: CGFloat = 7
  /// Horizontal inset of the arc's ends from the pad edge.
  private let arcInset: CGFloat = 14
  /// How far the arc's middle dips below its ends (the smile's depth).
  private let arcSagitta: CGFloat = 16
  /// Points of dead-band around each center line where the puck snaps to 0.
  private let centerSnap: CGFloat = 6
  /// Rotation detent spacing, in degrees, for haptic ticks.
  private let rotationDetentDegrees: Double = 15

  /// Sign of the puck on each axis (-1/0/1), so a light tick fires once as it
  /// snaps back onto a center line rather than every frame.
  @State private var lastAxisSign = (x: 0, y: 0)
  /// Last rotation detent index, so a tick fires once per detent crossed.
  @State private var lastRotationDetent: Int = .min

  /// The panel floats on an always-black tab, so the accent is pinned to its
  /// dark-mode variant regardless of the system appearance (matches the zoom
  /// slider).
  private static var darkAccent: Color {
    Color(UIColor(.appAccent).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
  }

  var body: some View {
    VStack(spacing: 6) {
      pad
      arc
    }
    .padding(containerPadding)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(Color.black)
        .overlay(
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    )
  }

  // MARK: - Translation pad

  /// Maximum puck travel from center along either axis.
  private var padTravel: CGFloat { padSide / 2 - puckRadius - 6 }

  /// Puck center for the current offset, clamped into the pad.
  private var puckPoint: CGPoint {
    let half = padSide / 2
    let nx = min(max(offset.width / max(translationRange, 0.0001), -1), 1)
    let ny = min(max(offset.height / max(translationRange, 0.0001), -1), 1)
    return CGPoint(x: half + nx * padTravel, y: half + ny * padTravel)
  }

  private var pad: some View {
    Canvas(opaque: false) { context, size in
      let mid = size.width / 2
      let accent = Self.darkAccent

      // Center crosshair — the reference-at-rest guides.
      var cross = Path()
      cross.move(to: CGPoint(x: mid, y: 10)); cross.addLine(to: CGPoint(x: mid, y: size.height - 10))
      cross.move(to: CGPoint(x: 10, y: mid)); cross.addLine(to: CGPoint(x: size.width - 10, y: mid))
      context.stroke(cross, with: .color(.white.opacity(0.12)), lineWidth: 1)

      // Dotted travel bounds so the reachable area reads at a glance.
      let boundsRect = CGRect(
        x: mid - padTravel, y: mid - padTravel,
        width: padTravel * 2, height: padTravel * 2
      )
      context.stroke(
        RoundedRectangle(cornerRadius: 10, style: .continuous).path(in: boundsRect),
        with: .color(.white.opacity(0.14)),
        style: StrokeStyle(lineWidth: 1, dash: [3, 4])
      )

      // The puck.
      let p = puckPoint
      let puckRect = CGRect(x: p.x - puckRadius, y: p.y - puckRadius, width: puckRadius * 2, height: puckRadius * 2)
      context.fill(Circle().path(in: puckRect), with: .color(accent))
      context.stroke(Circle().path(in: puckRect), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
    }
    .frame(width: padSide, height: padSide)
    .contentShape(Rectangle())
    .gesture(padDrag)
    .simultaneousGesture(TapGesture(count: 2).onEnded {
      Haptic.play(with: .light)
      lastAxisSign = (0, 0)
      onOffsetChange(.zero)
    })
  }

  private var padDrag: some Gesture {
    DragGesture(minimumDistance: 2)
      .onChanged { value in
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
  }

  // MARK: - Rotation arc

  private var arcHalfWidth: CGFloat { padSide / 2 - handleRadius - arcInset }
  /// Radius of the circle whose lower cap forms the visible smile-shaped arc.
  private var arcRadius: CGFloat {
    (arcHalfWidth * arcHalfWidth + arcSagitta * arcSagitta) / (2 * arcSagitta)
  }
  /// Circle center Y, placed so the arc's lowest point sits near the bottom edge.
  private var arcCenterY: CGFloat { (arcHeight - arcInset) - arcRadius }

  /// Point on the arc for a normalized position `t` in [-1, 1].
  private func arcPoint(t: CGFloat) -> CGPoint {
    let hx = t * arcHalfWidth
    let y = arcCenterY + sqrt(max(arcRadius * arcRadius - hx * hx, 0))
    return CGPoint(x: padSide / 2 + hx, y: y)
  }

  /// Normalized handle position for the current rotation.
  private var rotationT: CGFloat {
    guard rotationLimit.degrees != 0 else { return 0 }
    return CGFloat(min(max(rotation.degrees / rotationLimit.degrees, -1), 1))
  }

  private var arc: some View {
    Canvas(opaque: false) { context, size in
      let accent = Self.darkAccent

      // The arc track.
      var track = Path()
      let steps = 40
      for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 - 1
        let pt = arcPoint(t: t)
        if i == 0 { track.move(to: pt) } else { track.addLine(to: pt) }
      }
      context.stroke(track, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

      // Detent ticks along the arc.
      let detents = Int((rotationLimit.degrees / rotationDetentDegrees).rounded(.down))
      if detents > 0 {
        for d in -detents...detents {
          let t = CGFloat(Double(d) * rotationDetentDegrees / rotationLimit.degrees)
          let pt = arcPoint(t: t)
          let r: CGFloat = d == 0 ? 2.4 : 1.6
          let dotRect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
          context.fill(Circle().path(in: dotRect), with: .color(.white.opacity(d == 0 ? 0.7 : 0.35)))
        }
      }

      // The handle.
      let h = arcPoint(t: rotationT)
      let hRect = CGRect(x: h.x - handleRadius, y: h.y - handleRadius, width: handleRadius * 2, height: handleRadius * 2)
      context.fill(Circle().path(in: hRect), with: .color(accent))
      context.stroke(Circle().path(in: hRect), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
    }
    .frame(width: padSide, height: arcHeight)
    .contentShape(Rectangle())
    .gesture(arcDrag)
    .simultaneousGesture(TapGesture(count: 2).onEnded {
      Haptic.playTick(major: true)
      lastRotationDetent = 0
      onRotationChange(.zero)
    })
  }

  private var arcDrag: some Gesture {
    DragGesture(minimumDistance: 2)
      .onChanged { value in
        let hx = min(max(value.location.x - padSide / 2, -arcHalfWidth), arcHalfWidth)
        let t = hx / arcHalfWidth
        let degrees = Double(t) * rotationLimit.degrees

        let detent = Int((degrees / rotationDetentDegrees).rounded())
        if detent != lastRotationDetent {
          lastRotationDetent = detent
          Haptic.playTick(major: detent == 0)
        }

        onRotationChange(.degrees(degrees))
      }
  }
}

#Preview {
  struct PreviewHost: View {
    @State private var offset: CGSize = .zero
    @State private var rotation: Angle = .zero
    var body: some View {
      ZStack {
        LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
        PhotoTransformPad(
          offset: offset,
          rotation: rotation,
          translationRange: 342,
          rotationLimit: .degrees(45),
          onOffsetChange: { offset = $0 },
          onRotationChange: { rotation = $0 }
        )
      }
      .ignoresSafeArea()
    }
  }
  return PreviewHost()
}
