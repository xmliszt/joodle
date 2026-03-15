//
//  ResizableSplitView.swift
//  Joodle
//
//  Created by Li Yuxuan on 16/8/25.
//

import SwiftUI

struct ResizableSplitView<Top: View, Bottom: View>: View {
  @State private var isLandscape: Bool = false
  @State private var viewSize: CGSize?
  @State private var splitPosition: CGFloat = 1.0
  @State private var isSnapping: Bool = false
  @State private var hasShownBottomView: Bool = false
  @State private var isDraggable: Bool = true
  /// Temporary drag offset tracked by the gesture system; resets to 0 when drag ends.
  /// Using @GestureState avoids the feedback loop where updating @State during drag
  /// causes the handle to re-layout and jitter under the user's finger.
  @GestureState private var dragOffset: CGFloat = 0

  let topView: Top
  let bottomView: Bottom
  let hasBottomView: Bool
  let onBottomDismissed: (() -> Void)?
  let onTopViewHeightChange: ((CGFloat) -> Void)?
  let tutorialMode: Bool
  let allowHandleDrag: Bool

  init(
    @ViewBuilder top: () -> Top,
    @ViewBuilder bottom: () -> Bottom,
    hasBottomView: Bool,
    onBottomDismissed: (() -> Void)? = nil,
    onTopViewHeightChange: ((CGFloat) -> Void)? = nil,
    tutorialMode: Bool = false,
    allowHandleDrag: Bool? = nil
  ) {
    self.topView = top()
    self.bottomView = bottom()
    self.hasBottomView = hasBottomView
    self.onBottomDismissed = onBottomDismissed
    self.onTopViewHeightChange = onTopViewHeightChange
    self.tutorialMode = tutorialMode
    // If allowHandleDrag is not specified, default to !tutorialMode (disabled in tutorial mode)
    self.allowHandleDrag = allowHandleDrag ?? !tutorialMode
  }

  /// The height of the drag detection zone for the drag handle
  private let DRAG_HANDLE_HEIGHT: CGFloat = 20
  /// The highest position that user can drag
  @State private var MIN_SPLIT_POSITION: CGFloat = 0.0
  /// The lowest position that user can drag
  @State private var MAX_SPLIT_POSITION: CGFloat = 1.0
  /// Any value beyond this will be considered dismissed
  private let DISMISS_POSITION: CGFloat = 0.6
  /// Snap position includes 1.0, which means topView will be occupying the fullscreen
  @State private var SNAP_POSITIONS: [CGFloat] = [0.15, 0.5, 1.0]
  /// Compensate corner radius so it is just a bit smaller than device actual radius
  private let CORNER_RADIUS_COMPENSATION: CGFloat = 5

  var body: some View {
    GeometryReader { _geometry in
      // Combine the committed split position with the live drag offset
      let effectiveSplit = clamp(
        value: splitPosition + (dragOffset / _geometry.size.height),
        min: MIN_SPLIT_POSITION,
        max: MAX_SPLIT_POSITION
      )
      let topHeight = _geometry.size.height * effectiveSplit
      let bottomHeight = _geometry.size.height * (1 - effectiveSplit)

      ZStack {
        // Background color - animate opacity based on splitPosition for smooth transition
        // Map splitPosition 1.0->0.5 to opacity 0.0->1.0
        Color.appAccent
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .opacity(effectiveSplit >= 1.0 ? 0.0 : min(1.0, (1.0 - effectiveSplit) * 2))

        VStack(spacing: 0) {
          // Top View - YearGridView
          topView
            .frame(width: _geometry.size.width, height: topHeight, alignment: .top)
            .clipShape(
              UnevenRoundedRectangle(
                bottomLeadingRadius: UIDevice.screenCornerRadius - CORNER_RADIUS_COMPENSATION,
                bottomTrailingRadius: UIDevice.screenCornerRadius - CORNER_RADIUS_COMPENSATION,
                style: .continuous)
            )

          // Resize Handle
          Rectangle()
            .fill(.clear)
          // Still make the rectangle interactive while keeping background clear
            .contentShape(Rectangle())
            .frame(height: DRAG_HANDLE_HEIGHT)
            .overlay(
              RoundedRectangle(cornerRadius: 2)
                .fill(.appSurface.opacity(0.7))
                .frame(width: 60, height: 4)
                .tutorialHighlightAnchor(.centerHandle)
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
                  state = value.translation.height
                  transaction.animation = nil
                }
                .onEnded { value in
                  let movement = value.translation.height / _geometry.size.height
                  let finalPos = clamp(
                    value: splitPosition + movement,
                    min: MIN_SPLIT_POSITION,
                    max: MAX_SPLIT_POSITION
                  )
                  snapToPosition(finalPos, totalHeight: _geometry.size.height)
                }
            )

          // Bottom container - clips bottomView from top
          bottomView
            .frame(width: _geometry.size.width, height: bottomHeight, alignment: .top)
            .clipShape(
              UnevenRoundedRectangle(
                topLeadingRadius: UIDevice.screenCornerRadius - CORNER_RADIUS_COMPENSATION,
                topTrailingRadius: UIDevice.screenCornerRadius - CORNER_RADIUS_COMPENSATION,
                style: .continuous)
            )
          // Drag gesture handling for bottom container as well
            .gesture(
              (!isDraggable || !allowHandleDrag)
              ? nil
              : DragGesture(minimumDistance: 0, coordinateSpace: .named("splitContainer"))
                .updating($dragOffset) { value, state, transaction in
                  state = value.translation.height
                  transaction.animation = nil
                }
                .onEnded { value in
                  let movement = value.translation.height / _geometry.size.height
                  let finalPos = clamp(
                    value: splitPosition + movement,
                    min: MIN_SPLIT_POSITION,
                    max: MAX_SPLIT_POSITION
                  )
                  snapToPosition(finalPos, totalHeight: _geometry.size.height)
                }
            )
        }
      }
      .coordinateSpace(name: "splitContainer")
      .transaction { transaction in
        transaction.animation = dragOffset != 0 ? nil : transaction.animation
      }
      .onAppear {
        // When appeared, update splitPosition:
        // If we don't have bottomView, then show full topView
        // Otherwise, default at halfway position
        withAnimation(.springFkingSatifying) {
          splitPosition = hasBottomView ? 0.5 : 1.0
        } completion: {
          hasShownBottomView = hasBottomView
          let newHeight = _geometry.size.height * splitPosition
          self.onTopViewHeightChange?(newHeight)
        }
      }
      .onChange(of: _geometry.size) { _, newValue in
        guard dragOffset == 0 else { return }
        let newHeight = newValue.height * splitPosition
        self.onTopViewHeightChange?(newHeight)
      }
      .onChange(of: hasBottomView) { _, newValue in
        guard dragOffset == 0 else { return }
        withAnimation(.springFkingSatifying) {
          splitPosition = newValue ? 0.5 : 1.0
        } completion: {
          hasShownBottomView = newValue
          let newHeight = _geometry.size.height * splitPosition
          self.onTopViewHeightChange?(newHeight)
        }
      }
    }
  }

  /// Commits the dragged position and snaps to the nearest snap point with animation
  private func snapToPosition(_ position: CGFloat, totalHeight: CGFloat) {
    // Immediately commit the dragged position so there's no visual jump
    // when @GestureState resets dragOffset to 0
    splitPosition = position

    // Find the closest snap position
    let result: (minDiff: CGFloat, closestValue: CGFloat?) = SNAP_POSITIONS.reduce(
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
      if position >= DISMISS_POSITION {
        splitPosition = 1.0
      } else {
        splitPosition = closestPosition
      }
    } completion: {
      let newHeight = totalHeight * splitPosition
      self.onTopViewHeightChange?(newHeight)
      DispatchQueue.main.async {
        isSnapping = false
        if splitPosition == 1.0 {
          self.onBottomDismissed?()
        }
      }
    }
  }
}

#Preview {
  ResizableSplitView(
    top: { Color.white },
    bottom: { Color.white },
    hasBottomView: true
  ).ignoresSafeArea(.container)
}
