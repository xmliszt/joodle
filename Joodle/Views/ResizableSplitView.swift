//
//  ResizableSplitView.swift
//  Joodle
//
//  Created by Li Yuxuan on 16/8/25.
//

import SwiftUI

/// Two panels with a draggable handle between them. The split runs along
/// `LayoutSpec.splitAxis`: stacked (grid above the entry panel) on phones,
/// side by side (grid leading, entry panel trailing) on wide shapes. The
/// `top` / `bottom` labels name the panels' roles, not their placement.
struct ResizableSplitView<Top: View, Bottom: View>: View {
  @State private var splitPosition: CGFloat = 1.0
  @State private var isSnapping: Bool = false
  @State private var hasShownBottomView: Bool = false
  @State private var isDraggable: Bool = true
  /// Temporary drag offset tracked by the gesture system; resets to 0 when drag ends.
  /// Using @GestureState avoids the feedback loop where updating @State during drag
  /// causes the handle to re-layout and jitter under the user's finger.
  @GestureState private var dragOffset: CGFloat = 0

  @Environment(\.layoutContext) private var layoutContext
  @Environment(\.layoutSpec) private var layoutSpec

  let topView: Top
  let bottomView: Bottom
  let hasBottomView: Bool
  let onBottomDismissed: (() -> Void)?
  /// Called with the grid panel's size whenever a split animation settles or
  /// the container resizes.
  let onPrimarySizeChange: ((CGSize) -> Void)?
  let tutorialMode: Bool
  let allowHandleDrag: Bool

  init(
    @ViewBuilder top: () -> Top,
    @ViewBuilder bottom: () -> Bottom,
    hasBottomView: Bool,
    onBottomDismissed: (() -> Void)? = nil,
    onPrimarySizeChange: ((CGSize) -> Void)? = nil,
    tutorialMode: Bool = false,
    allowHandleDrag: Bool? = nil
  ) {
    self.topView = top()
    self.bottomView = bottom()
    self.hasBottomView = hasBottomView
    self.onBottomDismissed = onBottomDismissed
    self.onPrimarySizeChange = onPrimarySizeChange
    self.tutorialMode = tutorialMode
    // If allowHandleDrag is not specified, default to !tutorialMode (disabled in tutorial mode)
    self.allowHandleDrag = allowHandleDrag ?? !tutorialMode
  }

  /// Thickness of the drag detection zone across the split axis.
  private let handleThickness: CGFloat = 20
  /// The furthest the grid panel can shrink
  @State private var MIN_SPLIT_POSITION: CGFloat = 0.0
  /// The furthest the grid panel can grow
  @State private var MAX_SPLIT_POSITION: CGFloat = 1.0
  /// Compensate corner radius so it is just a bit smaller than device actual radius
  private let CORNER_RADIUS_COMPENSATION: CGFloat = 5

  private var axis: Axis { layoutSpec.splitAxis }

  /// Panel corners stay a little smaller than the device corners they echo, so
  /// they read as concentric, and on a screen with asymmetric corners (iPhone
  /// Duo cover) each side follows its own. `ScreenHardware` floors flat
  /// displays, so these stay positive.
  private func panelRadius(_ screenRadius: CGFloat) -> CGFloat {
    max(screenRadius - CORNER_RADIUS_COMPENSATION, 0)
  }

  var body: some View {
    GeometryReader { _geometry in
      let total = axis == .vertical ? _geometry.size.height : _geometry.size.width
      // Combine the committed split position with the live drag offset
      let effectiveSplit = clamp(
        value: splitPosition + (dragOffset / total),
        min: MIN_SPLIT_POSITION,
        max: MAX_SPLIT_POSITION
      )
      let primaryExtent = total * effectiveSplit
      let secondaryExtent = total * (1 - effectiveSplit)
      let primarySize = panelSize(extent: primaryExtent, in: _geometry.size)
      let secondarySize = panelSize(extent: secondaryExtent, in: _geometry.size)
      let layout = axis == .vertical
        ? AnyLayout(VStackLayout(spacing: 0))
        : AnyLayout(HStackLayout(spacing: 0))

      ZStack {
        // Accent shows through the handle gap between the two panels.
        Color.appAccent
          .frame(maxWidth: .infinity, maxHeight: .infinity)

        layout {
          // Grid panel
          topView
            .frame(width: primarySize.width, height: primarySize.height, alignment: .topLeading)
            .clipShape(primaryClipShape(secondaryExtent: secondaryExtent))

          // Resize Handle
          Rectangle()
            .fill(.clear)
          // Still make the rectangle interactive while keeping background clear
            .contentShape(Rectangle())
            .frame(
              width: axis == .horizontal ? handleThickness : nil,
              height: axis == .vertical ? handleThickness : nil)
            .overlay(
              RoundedRectangle(cornerRadius: 2)
                .fill(.appSurface.opacity(0.7))
                .frame(
                  width: axis == .vertical ? 60 : 4,
                  height: axis == .vertical ? 4 : 60)
                .tutorialHighlightAnchor(.centerHandle, cornerRadius: 2)
            )
          // Double-tap to navigate to today's date entry
            .onTapGesture(count: 2) {
              if tutorialMode {
                // In tutorial mode, only notify tutorial system
                NotificationCenter.default.post(
                  name: .tutorialDoubleTapCompleted,
                  object: nil
                )
              } else {
                // In normal mode, navigate to today's date
                let today = Date()
                NotificationCenter.default.post(
                  name: .navigateToDateFromShortcut,
                  object: nil,
                  userInfo: ["date": today]
                )
              }
            }
          // Drag gesture handling for resize handle area
            .simultaneousGesture(
              (!isDraggable || !allowHandleDrag)
              ? nil
              : DragGesture(minimumDistance: 0, coordinateSpace: .named("splitContainer"))
                .updating($dragOffset) { value, state, transaction in
                  state = axis == .vertical ? value.translation.height : value.translation.width
                  transaction.animation = nil
                }
                .onEnded { value in
                  let translation = axis == .vertical ? value.translation.height : value.translation.width
                  let movement = translation / total
                  let finalPos = clamp(
                    value: splitPosition + movement,
                    min: MIN_SPLIT_POSITION,
                    max: MAX_SPLIT_POSITION
                  )
                  snapToPosition(finalPos, containerSize: _geometry.size)
                }
            )

          // Entry panel - clipped along its edge facing the grid
          bottomView
            .frame(width: secondarySize.width, height: secondarySize.height, alignment: .topLeading)
            .clipShape(secondaryClipShape)
        }
      }
      .coordinateSpace(name: "splitContainer")
      .transaction { transaction in
        transaction.animation = dragOffset != 0 ? nil : transaction.animation
      }
      // A change of split axis (fold, rotation) slides both panels to their new
      // places instead of rebuilding them, on the spec's transition spring.
      .animation(layoutSpec.transitionAnimation, value: axis)
      .onAppear {
        // When appeared, update splitPosition:
        // If we don't have bottomView, then show full topView
        // Otherwise, default at halfway position
        withAnimation(.springFkingSatifying) {
          splitPosition = hasBottomView ? layoutSpec.splitDefaultPosition : 1.0
        } completion: {
          hasShownBottomView = hasBottomView
          reportPrimarySize(in: _geometry.size)
        }
      }
      .onChange(of: _geometry.size) { _, newValue in
        guard dragOffset == 0 else { return }
        reportPrimarySize(in: newValue)
      }
      .onChange(of: axis) { _, _ in
        guard dragOffset == 0 else { return }
        reportPrimarySize(in: _geometry.size)
      }
      .onChange(of: hasBottomView) { _, newValue in
        guard dragOffset == 0 else { return }
        withAnimation(.springFkingSatifying) {
          splitPosition = newValue ? layoutSpec.splitDefaultPosition : 1.0
        } completion: {
          hasShownBottomView = newValue
          reportPrimarySize(in: _geometry.size)
        }
      }
    }
  }

  // MARK: - Geometry

  private func panelSize(extent: CGFloat, in container: CGSize) -> CGSize {
    axis == .vertical
      ? CGSize(width: container.width, height: extent)
      : CGSize(width: extent, height: container.height)
  }

  private func reportPrimarySize(in container: CGSize) {
    let total = axis == .vertical ? container.height : container.width
    onPrimarySizeChange?(panelSize(extent: total * splitPosition, in: container))
  }

  /// Round the grid panel's edge facing the entry panel only while the entry
  /// panel is showing. As the grid reaches full screen (secondaryExtent -> 0)
  /// the radius collapses to 0 so the device's hardware corner mask does the
  /// rounding, instead of self-carving a notch that reveals the accent behind.
  private func primaryClipShape(secondaryExtent: CGFloat) -> UnevenRoundedRectangle {
    let radii = layoutContext.cornerRadii
    switch axis {
    case .vertical:
      return UnevenRoundedRectangle(
        bottomLeadingRadius: min(panelRadius(radii.bottomLeading), secondaryExtent),
        bottomTrailingRadius: min(panelRadius(radii.bottomTrailing), secondaryExtent),
        style: .continuous)
    case .horizontal:
      return UnevenRoundedRectangle(
        bottomTrailingRadius: min(panelRadius(radii.bottomTrailing), secondaryExtent),
        topTrailingRadius: min(panelRadius(radii.topTrailing), secondaryExtent),
        style: .continuous)
    }
  }

  private var secondaryClipShape: UnevenRoundedRectangle {
    let radii = layoutContext.cornerRadii
    switch axis {
    case .vertical:
      // Echoes the device's bottom corners: the panel sits over the lower half.
      return UnevenRoundedRectangle(
        topLeadingRadius: panelRadius(radii.bottomLeading),
        topTrailingRadius: panelRadius(radii.bottomTrailing),
        style: .continuous)
    case .horizontal:
      return UnevenRoundedRectangle(
        topLeadingRadius: panelRadius(radii.topLeading),
        bottomLeadingRadius: panelRadius(radii.bottomLeading),
        style: .continuous)
    }
  }

  /// Commits the dragged position and snaps to the nearest snap point with animation
  private func snapToPosition(_ position: CGFloat, containerSize: CGSize) {
    // Immediately commit the dragged position so there's no visual jump
    // when @GestureState resets dragOffset to 0
    splitPosition = position

    // Find the closest snap position
    let result: (minDiff: CGFloat, closestValue: CGFloat?) = layoutSpec.splitSnapPositions.reduce(
      (minDiff: .infinity, closestValue: nil)
    ) { acc, value in
      let diff = abs(value - position)
      if diff < acc.minDiff {
        return (minDiff: diff, closestValue: value)
      }
      return acc
    }

    guard let closestPosition = result.closestValue else { return }
    isSnapping = true
    withAnimation(.springFkingSatifying) {
      if position >= layoutSpec.splitDismissPosition {
        splitPosition = 1.0
      } else {
        splitPosition = closestPosition
      }
    } completion: {
      reportPrimarySize(in: containerSize)
      DispatchQueue.main.async {
        isSnapping = false
        if splitPosition == 1.0 {
          self.onBottomDismissed?()
        }
      }
    }
  }
}

#Preview("Stacked") {
  ResizableSplitView(
    top: { Color.white },
    bottom: { Color.white },
    hasBottomView: true
  ).ignoresSafeArea(.container)
}

#if DEBUG
#Preview("Side by side · Duo inner") {
  ResizableSplitView(
    top: { Color.white },
    bottom: { Color.white },
    hasBottomView: true
  )
  .ignoresSafeArea(.container)
  .layoutPreset(.duoInnerLandscape)
}
#endif
