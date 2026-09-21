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

  /// Direction the grid / entry split runs in.
  var splitAxis: Axis = .vertical
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
    let spec = LayoutSpec()
    switch context.layoutClass {
    case .compact, .phone, .regular, .wide:
      // Every class currently resolves to the shipped phone layout. Per-class
      // tokens land once the Layout Lab has tuned them against each shape.
      return spec
    }
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
    let inset = island?.origin.y ?? canvasContainerInsetWithoutIsland
    let cornerRadii = context.cornerRadii.inset(by: inset)
    return CanvasContainerMetrics(
      horizontalInset: inset,
      topOffset: island?.origin.y ?? context.safeArea.top,
      topContentInset: island?.height ?? 0,
      collapsedSize: island?.size ?? .zero,
      cornerRadii: cornerRadii,
      contentCornerRadius: max(cornerRadii.maxRadius - canvasContainerContentPadding, 0),
      expandedWidth: max(context.size.width - inset * 2, 0)
    )
  }
}

extension EnvironmentValues {
  @Entry var layoutSpec: LayoutSpec = LayoutSpec.resolve(.placeholder)
}
