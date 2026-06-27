//
//  CameraZoomSlider.swift
//  Joodle
//

import SwiftUI

/// A screen-edge camera zoom ruler, modelled on the native iOS Camera fine-zoom
/// control. The value label stays pinned at the vertical center while the tick
/// ruler scrolls beneath it; ticks toward the two ends progressively scale down
/// and blur, magnifying the focused tick at center. Major zoom levels (the
/// `keyFactors`) fire a haptic as they cross center.
///
/// Purely presentational: it renders the current `zoomFactor` and reports new
/// values through `onChange`. The only mutable state is the in-flight drag.
struct CameraZoomSlider: View {
  var zoomFactor: CGFloat
  var range: ClosedRange<CGFloat>
  var keyFactors: [CGFloat]
  /// Which screen edge the slider hugs — drives the corner morph and which side
  /// the value label sits on.
  var edge: HorizontalEdge
  var onChange: (CGFloat) -> Void

  private let containerWidth: CGFloat = 48
  private let containerHeight: CGFloat = 275
  /// Inset of the ruler's outer (edge-side) end from the container edge.
  private let outerInset: CGFloat = 10
  /// Width of the value label's pill. Kept just wide enough for "0.5x" so it
  /// hugs the screen edge without floating over the ruler.
  private let labelWidth: CGFloat = 40
  /// Convex radius of the two inner corners (away from the screen edge).
  private let convexRadius: CGFloat = 28
  /// Concave radius of the two corners that touch the screen edge — these flare
  /// outward so the panel smoothly morphs into the edge.
  private let concaveRadius: CGFloat = 16
  /// Points of travel per natural-log unit of zoom — sets how far apart the
  /// octaves (0.5→1→2) sit. Log spacing makes them evenly spaced.
  private let pointsPerLogUnit: CGFloat = 104
  /// Minor-tick interval in log space — eight ticks per octave.
  private let minorStepLog: CGFloat = 0.08664339 // ln(2) / 8

  /// Live zoom while dragging, in log space. `nil` when not dragging, so the
  /// ruler follows the externally driven `zoomFactor`.
  @State private var dragLog: CGFloat?
  /// Log-zoom captured at the start of a drag, so movement is relative.
  @State private var dragAnchorLog: CGFloat?
  /// Grid index of the tick currently at center — a change means a tick just
  /// crossed center, which is when a haptic fires (every tick, not just majors).
  @State private var lastTickIndex: Int = .min

  private var currentLog: CGFloat { dragLog ?? logZoom(zoomFactor) }
  private var currentZoom: CGFloat { clampZoom(exp(currentLog)) }

  /// The slider sits on an always-black background, so the theme accent is pinned
  /// to its dark-mode variant regardless of the system appearance.
  private static var darkAccent: Color {
    Color(UIColor(.appAccent).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
  }

  var body: some View {
    ZStack {
      container
      ruler
        .clipShape(tabShape)
      valueLabel
    }
    .frame(width: containerWidth, height: containerHeight)
    .contentShape(tabShape)
    .gesture(dragGesture)
    .onAppear { lastTickIndex = tickIndex(for: currentLog) }
  }

  // MARK: - Container

  private var tabShape: EdgeMorphTab {
    EdgeMorphTab(edge: edge, convexRadius: convexRadius, concaveRadius: concaveRadius)
  }

  private var container: some View {
    // Pure, opaque black — no glass or translucency — flush against the screen
    // edge with concave corners morphing into it.
    tabShape.fill(Color.black)
  }

  // MARK: - Value label

  private var valueLabel: some View {
    Text(Self.format(currentZoom))
      .font(.appFont(size: 13, weight: .bold))
      .monospacedDigit()
      .foregroundStyle(Self.darkAccent)
      .frame(width: labelWidth, height: 24)
      // Opaque black pill (same as the container) masks the ticks directly
      // beneath the value, so the label reads cleanly over the ruler.
      .background(Color.black, in: RoundedRectangle(cornerRadius: 12, style: .circular))
      .position(x: labelCenterX, y: containerHeight / 2)
  }

  /// Center of the value label — pinned hard against the screen edge (a couple
  /// points of breathing room) while still overlapping the ruler, so the value
  /// hugs the edge and masks the focused tick beneath it.
  private var labelCenterX: CGFloat {
    let edgeGap: CGFloat = 2
    switch edge {
    case .trailing: return containerWidth - edgeGap - labelWidth / 2
    case .leading: return edgeGap + labelWidth / 2
    }
  }

  // MARK: - Ruler

  /// The whole ruler is drawn in a single `Canvas` rather than ~30 individual
  /// views. This is the key to a smooth drag: there are no per-tick layers,
  /// `scaleEffect`s, or (the former bottleneck) per-tick blur passes — just one
  /// draw call per frame. The magnify is baked into each tick's drawn size and
  /// the end-softness into its alpha, so both are free.
  private var ruler: some View {
    Canvas(opaque: false, rendersAsynchronously: false) { context, size in
      let centerY = size.height / 2
      let cur = currentLog
      let tickList = ticks
      // The tick nearest center is the focused one, drawn in the accent color.
      let focused = tickList.min { abs($0.log - cur) < abs($1.log - cur) }?.log ?? cur
      let accent = Self.darkAccent

      for tick in tickList {
        let y = centerY - (tick.log - cur) * pointsPerLogUnit
        guard y >= -16, y <= size.height + 16 else { continue }
        let n = min(abs(y - centerY) / (size.height / 2), 1)
        // Gaussian "lens" centered on the focused tick. Length grows modestly,
        // while thickness grows much more — so the focused tick reads as a
        // distinctly fatter, magnified highlight rather than just a longer one.
        let lens = exp(-pow(n / 0.32, 2))
        let lengthScale = 1 + 0.28 * lens - 0.45 * pow(n, 1.4)
        let thicknessScale = 1 + 0.95 * lens - 0.30 * pow(n, 1.4)
        let baseLength: CGFloat
        let restOpacity: CGFloat
        switch tick.tier {
        case .major:  baseLength = 22; restOpacity = 0.9
        case .medium: baseLength = 17; restOpacity = 0.7
        case .minor:  baseLength = 12; restOpacity = 0.5
        }
        let length = baseLength * lengthScale
        let thickness = 2.5 * max(thicknessScale, 0.35)
        let originX: CGFloat = edge == .trailing ? size.width - outerInset - length : outerInset
        let rect = CGRect(x: originX, y: y - thickness / 2, width: length, height: thickness)

        let isFocused = abs(tick.log - focused) < 0.0001
        let base = isFocused ? accent : Color.white.opacity(restOpacity)
        context.fill(Capsule().path(in: rect), with: .color(base.opacity(distanceFade(n))))
      }
    }
  }

  /// Opacity that eases progressively from full at the focused center to zero
  /// at the ruler ends, so ticks far from the highlight fade out smoothly.
  private func distanceFade(_ n: CGFloat) -> CGFloat {
    max(0, 1 - pow(n, 1.7))
  }

  /// Three tick lengths, mirroring the native Camera ruler: the optical lenses
  /// (`keyFactors`) are longest, whole-number digital-zoom stops are medium, and
  /// the in-between grid lines are shortest.
  private enum TickTier {
    case major   // optical lens factor (0.5/1/2) — longest
    case medium  // whole-number digital-zoom stop (3/4/…) — in between
    case minor   // in-between grid line — shortest
  }

  /// A single ruler tick, identified by its log position (unique on the ruler).
  private struct RulerTick: Identifiable {
    let log: CGFloat
    let tier: TickTier
    var id: CGFloat { log }
  }

  /// A single uniform grid of ticks in log space — guaranteeing even spacing.
  /// Each grid line is tiered by what it lands nearest: a `keyFactor` (major), a
  /// whole-number zoom (medium), or neither (minor). Tiering a subset of the grid
  /// (rather than adding extra ticks at the exact key/integer positions) keeps the
  /// minor rhythm even — the 0.5/1/2 octaves land exactly on the grid, and an
  /// off-grid stop like 3 snaps to its nearest line instead of crowding it.
  private var ticks: [RulerTick] {
    let lo = logZoom(range.lowerBound)
    let hi = logZoom(range.upperBound)
    guard hi > lo else { return [] }
    let keyLogs = keyFactors.map { logZoom($0) }
    let integerLogs = stride(from: ceil(range.lowerBound), through: range.upperBound, by: 1)
      .map { logZoom($0) }
    let steps = max(1, Int(((hi - lo) / minorStepLog).rounded()))

    return (0...steps).map { i in
      let value = lo + CGFloat(i) * minorStepLog
      func isNear(_ target: CGFloat) -> Bool { abs(target - value) <= minorStepLog * 0.5 }
      let tier: TickTier =
        keyLogs.contains(where: isNear) ? .major
        : integerLogs.contains(where: isNear) ? .medium
        : .minor
      return RulerTick(log: value, tier: tier)
    }
  }

  // MARK: - Drag

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let anchor = dragAnchorLog ?? logZoom(zoomFactor)
        if dragAnchorLog == nil { dragAnchorLog = anchor }
        // Drag up (negative height) zooms in.
        let newLog = clampLog(anchor - value.translation.height / pointsPerLogUnit)
        dragLog = newLog
        fireHapticOnTickCrossed(newLog)
        onChange(clampZoom(exp(newLog)))
      }
      .onEnded { _ in
        dragAnchorLog = nil
        dragLog = nil
      }
  }

  /// Grid index of the tick nearest `logValue` (0 at the range minimum).
  private func tickIndex(for logValue: CGFloat) -> Int {
    Int(((logValue - logZoom(range.lowerBound)) / minorStepLog).rounded())
  }

  /// Fires one tick (haptic + click) each time the centered tick changes —
  /// every tick, with a slightly stronger tap and lower tock on the major
  /// (key-factor) lines.
  private func fireHapticOnTickCrossed(_ logValue: CGFloat) {
    let index = tickIndex(for: logValue)
    guard index != lastTickIndex else { return }
    lastTickIndex = index
    let tickLog = logZoom(range.lowerBound) + CGFloat(index) * minorStepLog
    let isMajor = keyFactors.contains { abs(logZoom($0) - tickLog) <= minorStepLog * 0.5 }
    Haptic.playTick(major: isMajor)
  }

  // MARK: - Log-scale mapping

  private func logZoom(_ zoom: CGFloat) -> CGFloat { log(clampZoom(zoom)) }

  private func clampLog(_ value: CGFloat) -> CGFloat {
    min(max(value, log(range.lowerBound)), log(range.upperBound))
  }

  private func clampZoom(_ value: CGFloat) -> CGFloat {
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

/// The interactive zoom-slider used to demonstrate the handedness setting (in
/// onboarding and Settings > Interactions). Both edge sliders are always present:
/// the active one sits at its edge while the inactive one is parked just off the
/// opposite side. Flipping `edge` (inside `withAnimation`) slides them via offset —
/// the old side off its edge, the new side in from the other — which animates
/// reliably even inside a `List`/`Form` row, where a `.transition` would just fade.
/// Drags are local-only — no camera is involved, it just shows the feel.
struct HandednessSliderPreview: View {
  var edge: HorizontalEdge

  @State private var zoom: CGFloat = 1.0

  var body: some View {
    GeometryReader { geo in
      ZStack {
        slider(side: .leading)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .offset(x: edge == .leading ? 0 : -geo.size.width)
        slider(side: .trailing)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
          .offset(x: edge == .trailing ? 0 : geo.size.width)
      }
    }
    .clipped()
  }

  private func slider(side: HorizontalEdge) -> some View {
    CameraZoomSlider(
      zoomFactor: zoom,
      range: 0.5...10,
      keyFactors: [0.5, 1, 2],
      edge: side,
      onChange: { zoom = $0 }
    )
  }
}

/// A panel that hugs one screen edge: the two inner corners are convex-rounded,
/// while the two corners touching the edge are *concave* fillets that flare the
/// panel out so it morphs smoothly into the edge (it is full-height against the
/// edge and inset by `concaveRadius` along the flat inner span).
private struct EdgeMorphTab: Shape {
  var edge: HorizontalEdge
  var convexRadius: CGFloat
  var concaveRadius: CGFloat

  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    let c = min(convexRadius, h / 2 - 1, w - 1)
    let k = min(concaveRadius, h / 2 - 1, w - 1)

    // Built for a trailing (right) edge; the screen edge is at x == w.
    var path = Path()
    path.move(to: CGPoint(x: c, y: k))
    path.addLine(to: CGPoint(x: w - k, y: k))                                   // flat top
    path.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w, y: k))    // concave flare → edge
    path.addLine(to: CGPoint(x: w, y: h))                                       // flush along the edge
    path.addQuadCurve(to: CGPoint(x: w - k, y: h - k), control: CGPoint(x: w, y: h - k)) // concave flare
    path.addLine(to: CGPoint(x: c, y: h - k))                                   // flat bottom
    path.addQuadCurve(to: CGPoint(x: 0, y: h - k - c), control: CGPoint(x: 0, y: h - k)) // convex
    path.addLine(to: CGPoint(x: 0, y: k + c))                                   // inner edge
    path.addQuadCurve(to: CGPoint(x: c, y: k), control: CGPoint(x: 0, y: k))    // convex
    path.closeSubpath()

    if edge == .leading {
      // Mirror horizontally so the edge sits at x == 0.
      return path.applying(CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -w, y: 0))
    }
    return path
  }
}

#Preview {
  struct PreviewHost: View {
    @State private var zoom: CGFloat = 1.0
    var body: some View {
      ZStack {
        LinearGradient(
          colors: [.gray, .black],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        HStack {
          CameraZoomSlider(
            zoomFactor: zoom,
            range: 0.5...10,
            keyFactors: [0.5, 1, 2],
            edge: .leading,
            onChange: { zoom = $0 }
          )
          Spacer()
          CameraZoomSlider(
            zoomFactor: zoom,
            range: 0.5...10,
            keyFactors: [0.5, 1, 2],
            edge: .trailing,
            onChange: { zoom = $0 }
          )
        }
      }
      .ignoresSafeArea()
    }
  }
  return PreviewHost()
}
