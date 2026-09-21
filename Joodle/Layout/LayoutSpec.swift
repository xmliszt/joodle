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

  static func resolve(_ context: LayoutContext) -> LayoutSpec {
    var spec = LayoutSpec()
    switch context.layoutClass {
    case .compact, .phone:
      // The shipped phone layout.
      break
    case .regular:
      // Stacked like a phone, but the grid stops spreading and the canvas
      // container floats at phone width instead of spanning the scene.
      spec.gridMaxWidth = 520
      spec.canvasContainerMaxWidth = 400
    case .wide:
      // Grid leading, entry panel trailing.
      spec.splitAxis = .horizontal
      spec.splitExpandedPosition = 0.35
      spec.splitDismissPosition = 0.75
      spec.gridMaxWidth = 520
      spec.canvasContainerMaxWidth = 400
    }
    return spec
  }
}

// MARK: - Floating canvas container

/// Geometry of the floating canvas container, shared by the container view and
/// the canvas it hosts so both agree on insets and concentric rounding.
struct CanvasContainerMetrics: Equatable {
  /// Symmetric inset from the scene's side edges.
  var horizontalInset: CGFloat
  /// Y where the container's top edge sits.
  var topOffset: CGFloat
  /// Height reserved at the top so content never draws under the cutout.
  var topContentInset: CGFloat
  /// Size while collapsed: the island capsule, or zero without one.
  var collapsedSize: CGSize
  /// Container corners, concentric with the screen's.
  var cornerRadii: RectangleCornerRadii
  /// Corner radius of the content clipped inside the container's padding.
  var contentCornerRadius: CGFloat
  /// Container width while expanded.
  var expandedWidth: CGFloat
}

extension LayoutSpec {
  func canvasContainer(in context: LayoutContext) -> CanvasContainerMetrics {
    let island = context.cutout.dynamicIslandFrame
    let edgeInset = island?.origin.y ?? canvasContainerInsetWithoutIsland
    let spanningWidth = max(context.size.width - edgeInset * 2, 0)
    // Capped: the container floats centered, narrower than the scene, with its
    // own rounding since it no longer hugs the screen corners.
    let isCapped = canvasContainerMaxWidth > 0 && canvasContainerMaxWidth < spanningWidth
    let expandedWidth = isCapped ? canvasContainerMaxWidth : spanningWidth
    let cornerRadii = isCapped
      ? RectangleCornerRadii(uniform: canvasContainerFloatingCornerRadius)
      : context.cornerRadii.inset(by: edgeInset)
    return CanvasContainerMetrics(
      horizontalInset: isCapped ? (context.size.width - expandedWidth) / 2 : edgeInset,
      topOffset: island?.origin.y ?? context.safeArea.top,
      topContentInset: island?.height ?? 0,
      collapsedSize: island?.size ?? .zero,
      cornerRadii: cornerRadii,
      contentCornerRadius: max(cornerRadii.maxRadius - canvasContainerContentPadding, 0),
      expandedWidth: expandedWidth
    )
  }
}

extension EnvironmentValues {
  @Entry var layoutSpec: LayoutSpec = LayoutSpec.resolve(.placeholder)
}
