//
//  AperturePrototypeView.swift
//  Joodle
//
//  Prototype of iPhone-1 style aperture animation. Blades TILE — they share
//  edges with their neighbors and never overlap, so there is no cyclic
//  z-order problem. The cast-shadow illusion is faked: each blade has a
//  blurred dark stroke painted along ONLY its leading side edge, masked to
//  the blade's interior. The shadow appears at every seam as a soft dark
//  band fading inward from the edge — reads as the neighboring blade
//  casting a shadow, even though no real overlap exists.
//
//  Tap to toggle open/close.
//

import SwiftUI

struct AperturePrototypeView: View {
  @State private var isOpen: Bool = false
  private let bladeCount: Int = 12

  var body: some View {
    ZStack {
      // Background that shows through when aperture is open
      LinearGradient(
        colors: [.orange, .pink, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ApertureBlades(progress: isOpen ? 0 : 1, bladeCount: bladeCount)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.easeInOut(duration: 2)) {
        isOpen.toggle()
      }
    }
    .ignoresSafeArea()
  }
}

// MARK: - Reusable aperture view

/// Tiled aperture blades with the faked cast-shadow built in. `progress` is
/// 0 (fully open) → 1 (fully closed).
struct ApertureBlades: View {
  var progress: Double
  var bladeCount: Int
  var fill: Color = Color(white: 0.18)
  var shadowOpacity: Double = 0.9
  var shadowLineWidth: Double = 6
  var shadowBlur: Double = 3

  var body: some View {
    GeometryReader { geo in
      ZStack {
        ForEach(0..<bladeCount, id: \.self) { i in
          ZStack {
            CurvedBlade(progress: progress, bladeIndex: i, bladeCount: bladeCount)
              .fill(fill)

            BladeLeadingEdge(progress: progress, bladeIndex: i, bladeCount: bladeCount)
              .stroke(Color.black.opacity(shadowOpacity), lineWidth: shadowLineWidth)
              .blur(radius: shadowBlur)
              .mask {
                CurvedBlade(progress: progress, bladeIndex: i, bladeCount: bladeCount)
                  .fill(Color.white)
              }
          }
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
  }
}

// MARK: - Shared blade geometry

/// Geometry parameters for one blade at the given progress. Both shapes
/// below derive their paths from the same anchors so the leading-edge
/// shadow tracks the blade's actual side curve through the animation.
struct BladeGeometry {
  let center: CGPoint
  let outerA: CGPoint
  let innerA: CGPoint
  let outerB: CGPoint
  let innerB: CGPoint
  let thetaA: Double
  let thetaB: Double
  let twist: Double
  let apertureR: Double
  let outerR: Double
  let curvature: Double

  init(rect: CGRect, progress: Double, bladeIndex: Int, bladeCount: Int) {
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let diagonal = sqrt(rect.width * rect.width + rect.height * rect.height)
    let oR = diagonal * 0.85
    let openApertureR = diagonal * 0.78
    let aR = openApertureR * (1.0 - progress)
    let maxTwist: Double = .pi / 2
    let tw = maxTwist * progress
    let step = 2 * .pi / Double(bladeCount)
    let tA = Double(bladeIndex) * step - .pi / 2
    let tB = tA + step
    func pt(_ r: Double, _ a: Double) -> CGPoint {
      CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
    }
    center = c
    outerR = oR
    apertureR = aR
    twist = tw
    curvature = 0.34
    thetaA = tA
    thetaB = tB
    outerA = pt(oR, tA)
    outerB = pt(oR, tB)
    innerA = pt(aR, tA + tw)
    innerB = pt(aR, tB + tw)
  }

  /// Append a cubic-Bezier "side edge" between two points lying at known
  /// angles and radii around the aperture center.
  ///
  /// Both control points are offset perpendicular to the chord in the same
  /// `+θ` direction (the outer endpoint's tangent), scaled by `curvature *
  /// outerR`. Using one shared direction (rather than each endpoint's own
  /// tangent) keeps the curve a single-direction bow — no S-curve — and
  /// distributes the bend along the whole edge so the blade reads as a
  /// crescent sliver instead of bending only at one tip.
  ///
  /// Tile invariance is preserved because the offset direction and
  /// magnitude depend only on the outer endpoint (which both neighboring
  /// blades share with identical angle/radius).
  func appendSideCurve(
    path: inout Path,
    from: CGPoint, fromAngle: Double, fromRadius: Double,
    to: CGPoint, toAngle: Double, toRadius: Double
  ) {
    let fromIsOuter = fromRadius >= toRadius
    let outerAngle = fromIsOuter ? fromAngle : toAngle
    let outerRadius = fromIsOuter ? fromRadius : toRadius
    let tOuter = CGPoint(x: -sin(outerAngle), y: cos(outerAngle))
    let offset = curvature * outerRadius
    let dx = to.x - from.x
    let dy = to.y - from.y
    let mid1 = CGPoint(x: from.x + dx / 3, y: from.y + dy / 3)
    let mid2 = CGPoint(x: from.x + 2 * dx / 3, y: from.y + 2 * dy / 3)
    let c1 = CGPoint(x: mid1.x + tOuter.x * offset, y: mid1.y + tOuter.y * offset)
    let c2 = CGPoint(x: mid2.x + tOuter.x * offset, y: mid2.y + tOuter.y * offset)
    path.addCurve(to: to, control1: c1, control2: c2)
  }
}

// MARK: - Shapes

/// Full curved aperture blade. Closed path bounded by two arcs (outer and
/// inner aperture) and two cubic-Bezier side edges.
struct CurvedBlade: Shape {
  var progress: Double
  var bladeIndex: Int
  var bladeCount: Int

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let g = BladeGeometry(rect: rect, progress: progress,
                          bladeIndex: bladeIndex, bladeCount: bladeCount)
    var path = Path()
    path.move(to: g.outerA)
    g.appendSideCurve(
      path: &path,
      from: g.outerA, fromAngle: g.thetaA, fromRadius: g.outerR,
      to: g.innerA, toAngle: g.thetaA + g.twist, toRadius: g.apertureR
    )
    path.addArc(
      center: g.center, radius: g.apertureR,
      startAngle: .radians(g.thetaA + g.twist),
      endAngle: .radians(g.thetaB + g.twist),
      clockwise: false
    )
    g.appendSideCurve(
      path: &path,
      from: g.innerB, fromAngle: g.thetaB + g.twist, fromRadius: g.apertureR,
      to: g.outerB, toAngle: g.thetaB, toRadius: g.outerR
    )
    path.addArc(
      center: g.center, radius: g.outerR,
      startAngle: .radians(g.thetaB),
      endAngle: .radians(g.thetaA),
      clockwise: true
    )
    path.closeSubpath()
    return path
  }
}

/// Open path tracing ONLY the leading side edge of the blade (side A:
/// outerA → innerA). Used for the cast-shadow stroke — strokes an open
/// path so the shadow appears only along one edge, not the full outline.
struct BladeLeadingEdge: Shape {
  var progress: Double
  var bladeIndex: Int
  var bladeCount: Int

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let g = BladeGeometry(rect: rect, progress: progress,
                          bladeIndex: bladeIndex, bladeCount: bladeCount)
    var path = Path()
    path.move(to: g.outerA)
    g.appendSideCurve(
      path: &path,
      from: g.outerA, fromAngle: g.thetaA, fromRadius: g.outerR,
      to: g.innerA, toAngle: g.thetaA + g.twist, toRadius: g.apertureR
    )
    return path
  }
}

#Preview {
  AperturePrototypeView()
}
