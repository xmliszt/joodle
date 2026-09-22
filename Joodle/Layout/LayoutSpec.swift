//
//  LayoutSpec.swift
//  Joodle
//
//  Layout tokens for one screen shape. `resolve` is the only place a
//  `LayoutClass` turns into numbers; views read the result from the
//  environment and never branch on device or class themselves.
//

import SwiftUI

struct LayoutSpec: Equatable {
  /// Floating header over the year grid, including the space the grid scrolls under.
  var headerHeight: CGFloat = 100

  /// Side padding of the year grid inside its container.
  var gridHorizontalPadding: CGFloat = 40
  /// Dots per row in the minimized (year) view. The 7-day view is always a
  /// calendar week. Stored as a number so the Layout Lab can drive it.
  var yearModeColumns: CGFloat = 16

  /// Dots per row for a view mode.
  func columns(for viewMode: ViewMode) -> Int {
    switch viewMode {
    case .now: return ViewMode.now.dotsPerRow
    case .year: return max(Int(yearModeColumns.rounded()), 1)
    }
  }
  /// Cap on the grid's width on wide containers; 0 means none. Leftover width
  /// becomes side margin, so seven weekday dots never spread across an iPad.
  var gridMaxWidth: CGFloat = 0

  /// The grid's side padding in a container of `width`, honoring the cap.
  func gridHorizontalPadding(forContainerWidth width: CGFloat) -> CGFloat {
    guard gridMaxWidth > 0 else { return gridHorizontalPadding }
    return max(gridHorizontalPadding, (width - gridMaxWidth) / 2)
  }

  /// Direction the grid / entry split runs in.
  var splitAxis: Axis = .vertical
  /// `splitAxis` as a number (0 stacked, 1 side by side), so the Layout Lab
  /// can drive it through the same token table as every other value.
  var splitAxisValue: CGFloat {
    get { splitAxis == .vertical ? 0 : 1 }
    set { splitAxis = newValue >= 0.5 ? .horizontal : .vertical }
  }
  /// Fraction of the split given to the grid when the entry panel first shows;
  /// also the middle snap point.
  var splitDefaultPosition: CGFloat = 0.5
  /// Grid fraction at the tallest entry-panel snap.
  var splitExpandedPosition: CGFloat = 0.15
  /// Dragging past this fraction dismisses the entry panel.
  var splitDismissPosition: CGFloat = 0.6

  /// Positions the drag handle settles on; 1.0 is grid fullscreen.
  var splitSnapPositions: [CGFloat] { [splitExpandedPosition, splitDefaultPosition, 1.0] }

  /// How much smaller the split panels' corners are than the screen corners
  /// they echo, so they read as concentric.
  var splitPanelCornerCompensation: CGFloat = 5

  /// Corner radii of the split panels, per corner of the safe region.
  func splitPanelCornerRadii(in context: LayoutContext) -> RectangleCornerRadii {
    context.safeRegionCornerRadii.inset(by: splitPanelCornerCompensation)
  }

  /// Whether the header's buttons leave the header for a vertical rail in the
  /// trailing safe-area inset: the Duo cover's sensor bar has room below the
  /// status items, and the grid gets the header's full width.
  var headerButtonsInTrailingRail = false
  /// Where the rail starts: clear of the status items' pill, which ends about
  /// 112pt down the Duo cover's sensor bar.
  var trailingRailTopInset: CGFloat = 165

  /// Side inset of the floating canvas container on screens without an island
  /// (island devices derive it from the cutout frame instead).
  var canvasContainerInsetWithoutIsland: CGFloat = 10
  /// Padding between the container edge and the canvas inside it.
  var canvasContainerContentPadding: CGFloat = 8
  /// Cap on the floating canvas container's width; 0 means span the scene.
  /// On wide shapes the container floats centered at this width instead.
  var canvasContainerMaxWidth: CGFloat = 0
  /// Corner radius of the container when it floats narrower than the scene,
  /// where concentricity with the screen corners no longer applies.
  var canvasContainerFloatingCornerRadius: CGFloat = 44
  /// Largest side the canvas is *displayed* at; 0 keeps it at `CANVAS_SIZE`.
  /// Strokes always live in the 342pt space and scale up for display, so a
  /// bigger canvas never changes stored data.
  var canvasDisplayMaxSide: CGFloat = 0
  /// Smallest gap kept between the displayed canvas and the container edge.
  var canvasMinSideInset: CGFloat = 16
  /// On a side-by-side split the container docks inside the entry column,
  /// this far from the column's edges.
  var canvasDockInset: CGFloat = 12
  /// Floor for the container's corner radius where the corners it echoes are
  /// too tight to stay concentric (iPads echo an 18pt screen, the Duo cover's
  /// hinge side 8pt).
  var canvasDockMinCornerRadius: CGFloat = 16

  /// Side of the displayed canvas square inside a container of `containerWidth`.
  func canvasDisplaySide(containerWidth: CGFloat) -> CGFloat {
    guard canvasDisplayMaxSide > CANVAS_SIZE else { return CANVAS_SIZE }
    return min(canvasDisplayMaxSide, max(containerWidth - canvasMinSideInset * 2, CANVAS_SIZE))
  }

  /// Bottom inset of the edge-hugging camera and photo controls.
  var edgeControlBottomInset: CGFloat = 80
  /// Bottom inset of the camera shutter.
  var shutterBottomInset: CGFloat = 32
  /// Bottom inset of the move-doodle instruction bar.
  var moveBarBottomInset: CGFloat = 40
  /// Floor for the corner-docked button's inset from both edges. Well above
  /// any display radius, because touches that start near the home indicator
  /// are held back by the system and feel laggy.
  var cornerButtonMinInset: CGFloat = 80

  /// Spring every layout-class change rides: a fold, an unfold, a rotation
  /// into a different class. Same-class resizes (a multitasking drag) snap.
  var transitionResponse: CGFloat = 0.36
  var transitionDampingFraction: CGFloat = 0.8

  var transitionAnimation: Animation {
    .spring(response: transitionResponse, dampingFraction: transitionDampingFraction)
  }

  static func resolve(_ context: LayoutContext) -> LayoutSpec {
    var spec = LayoutSpec()
    // A trailing sensor bar wide enough to hold a button column takes the
    // header's buttons, whatever the class.
    spec.headerButtonsInTrailingRail = context.safeArea.trailing >= 60
    switch context.layoutClass {
    case .compact, .phone:
      // The shipped phone layout.
      break
    case .regular:
      // Stacked like a phone, but the grid stops spreading and the canvas
      // container floats instead of spanning the scene, with a larger canvas.
      spec.gridMaxWidth = 520
      spec.yearModeColumns = 24
      spec.canvasContainerMaxWidth = 480
      spec.canvasDisplayMaxSide = 448
      spec.canvasContainerInsetWithoutIsland = 24
    case .wide:
      // Grid leading, entry panel trailing.
      spec.splitAxis = .horizontal
      spec.splitExpandedPosition = 0.35
      spec.splitDismissPosition = 0.75
      spec.gridMaxWidth = 520
      spec.yearModeColumns = 24
      spec.canvasContainerMaxWidth = 480
      spec.canvasDisplayMaxSide = 448
      // With the status bar hidden behind the open canvas these screens have
      // no top inset, so the seat needs its own breathing room.
      spec.canvasContainerInsetWithoutIsland = 24
    }
    return spec
  }
}

// MARK: - Floating canvas container

/// Geometry of the floating canvas container, shared by the container view and
/// the canvas it hosts so both agree on insets and concentric rounding.
struct CanvasContainerMetrics: Equatable {
  /// Inset from the safe region's side edges while expanded.
  var horizontalInset: CGFloat
  /// Y where the container's top edge sits while expanded.
  var topOffset: CGFloat
  /// Height reserved at the top so content never draws under the cutout.
  var topContentInset: CGFloat
  /// Where the collapsed container hides, in scene coordinates: the island
  /// capsule, the Duo cover's camera hole, or nil when there is nothing to hide
  /// behind and it collapses to a point.
  var collapsedFrame: CGRect?
  /// Container corners, concentric with the screen's.
  var cornerRadii: RectangleCornerRadii
  /// Corner radius of the content clipped inside the container's padding.
  var contentCornerRadius: CGFloat
  /// Container width while expanded.
  var expandedWidth: CGFloat
  /// Horizontal center of the expanded container, in scene coordinates: the
  /// middle of the safe region, so a side sensor bar pushes it over.
  var expandedCenterX: CGFloat

  var collapsedSize: CGSize { collapsedFrame?.size ?? .zero }
}

extension LayoutSpec {
  /// Container geometry. `dock` is the entry panel's frame in scene
  /// coordinates; on a side-by-side split the container lives inside it,
  /// concentric with the panel's rounded leading corners, instead of
  /// floating over the scene's center.
  func canvasContainer(in context: LayoutContext, dockedTo dock: CGRect? = nil) -> CanvasContainerMetrics {
    if splitAxis == .horizontal, let dock, dock.width > canvasDockInset * 2 {
      return dockedCanvasContainer(in: context, panel: dock)
    }
    let island = context.cutout.dynamicIslandFrame
    let concealing = context.cutout.concealingFrame
    let edgeInset = island?.origin.y ?? canvasContainerInsetWithoutIsland
    // The container lives in the horizontally safe region: on the Duo cover
    // the trailing sensor bar is a safe-area inset, not usable width.
    let safeWidth = max(context.size.width - context.safeArea.leading - context.safeArea.trailing, 0)
    let safeCenterX = context.safeArea.leading + safeWidth / 2
    let spanningWidth = max(safeWidth - edgeInset * 2, 0)
    // Capped: the container floats centered, narrower than the scene, with its
    // own rounding since it no longer hugs the screen corners.
    let isCapped = canvasContainerMaxWidth > 0 && canvasContainerMaxWidth < spanningWidth
    let expandedWidth = isCapped ? canvasContainerMaxWidth : spanningWidth
    let cornerRadii = isCapped
      ? RectangleCornerRadii(uniform: canvasContainerFloatingCornerRadius)
      : context.safeRegionCornerRadii.inset(by: edgeInset).floored(at: canvasDockMinCornerRadius)
    return CanvasContainerMetrics(
      horizontalInset: isCapped ? (safeWidth - expandedWidth) / 2 : edgeInset,
      // Below the island, else just under the top safe area; never flush with
      // the top edge on a screen whose status bar lives elsewhere.
      topOffset: island?.origin.y ?? max(context.safeArea.top, canvasContainerInsetWithoutIsland),
      topContentInset: island?.height ?? 0,
      collapsedFrame: concealing,
      cornerRadii: cornerRadii,
      contentCornerRadius: max(cornerRadii.maxRadius - canvasContainerContentPadding, 0),
      expandedWidth: expandedWidth,
      expandedCenterX: safeCenterX
    )
  }

  private func dockedCanvasContainer(in context: LayoutContext, panel: CGRect) -> CanvasContainerMetrics {
    let available = panel.width - canvasDockInset * 2
    let expandedWidth = canvasContainerMaxWidth > 0 ? min(canvasContainerMaxWidth, available) : available
    // Concentric with the panel's leading corners: the same radius minus the
    // gap between them, floored where the panel is nearly square.
    let panelRadius = splitPanelCornerRadii(in: context).topLeading
    let cornerRadius = max(panelRadius - canvasDockInset, canvasDockMinCornerRadius)
    let cornerRadii = RectangleCornerRadii(uniform: cornerRadius)
    return CanvasContainerMetrics(
      horizontalInset: (panel.width - expandedWidth) / 2,
      topOffset: panel.minY + canvasDockInset,
      topContentInset: 0,
      collapsedFrame: context.cutout.concealingFrame,
      cornerRadii: cornerRadii,
      contentCornerRadius: max(cornerRadius - canvasContainerContentPadding, 0),
      expandedWidth: expandedWidth,
      expandedCenterX: panel.midX
    )
  }
}

extension EnvironmentValues {
  /// Frame of the entry panel in scene coordinates, published by the split so
  /// the floating canvas can dock inside it on a side-by-side layout. Nil
  /// while the panel is hidden or the split is stacked.
  @Entry var canvasDockFrame: CGRect? = nil
}

extension EnvironmentValues {
  @Entry var layoutSpec: LayoutSpec = LayoutSpec.resolve(.placeholder)
}
