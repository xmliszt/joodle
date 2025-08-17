//
//  ResizableSplitView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 16/8/25.
//

import SwiftUI

struct ResizableSplitView<Top: View, Bottom: View>: View {
    @State private var isDragging = false
    @State private var isLandscape: Bool = false
    @State private var viewSize: CGSize?
    @State private var splitPosition: CGFloat = 1.0
    @State private var isSnapping: Bool = false
    @State private var hasShownBottomView: Bool = false
    
    
    let topView: Top
    let bottomView: Bottom
    let hasBottomView: Bool
    let onBottomDismissed: (() -> Void)?
    let onTopViewHeightChange: ((CGFloat) -> Void)?
    
    init(
        @ViewBuilder top: () -> Top,
        @ViewBuilder bottom: () -> Bottom,
        hasBottomView: Bool,
        onBottomDismissed: (() -> Void)? = nil,
        onTopViewHeightChange: ((CGFloat) -> Void)? = nil
    ) {
        self.topView = top()
        self.bottomView = bottom()
        self.hasBottomView = hasBottomView
        self.onBottomDismissed = onBottomDismissed
        self.onTopViewHeightChange = onTopViewHeightChange
    }
    
    /// The corner radius for clipping both top and bottom view
    private let CORNER_RADIUS: CGFloat = 50
    /// The height of the drag detection zone for the drag handle
    private let DRAG_HANDLE_HEIGHT: CGFloat = 20
    /// The highest position that user can drag
    private let MIN_SPLIT_POSITION: CGFloat = 0.0
    /// The lowest position that user can drag
    private let MAX_SPLIT_POSITION: CGFloat = 1.0
    /// Any value beyond this will be considered dismissed
    private let DISMISS_POSITION: CGFloat = 0.8
    /// Snap position includes 1.0, which means topView will be occupying the fullscreen
    private let SNAP_POSITIONS: [CGFloat] = [0.25, 0.5, 0.75, 1.0]
    
    var body: some View {
        GeometryReader { _geometry in
            let topHeight = _geometry.size.height * splitPosition
            let bottomHeight = _geometry.size.height * (1 - splitPosition)
            
            ZStack {
                // Background color
                Color.accentColor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack(spacing: 0) {
                    // Top View - YearGridView
                    topView
                        .frame(width: _geometry.size.width, height: topHeight, alignment: .top)
                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: CORNER_RADIUS, bottomTrailingRadius: CORNER_RADIUS))
                        .animation(isSnapping || !hasShownBottomView ? .bouncy : nil, value: splitPosition)
                    
                    // Resize Handle
                    Rectangle()
                        .fill(.clear)
                    // Still make the rectangle interactive while keeping background clear
                        .contentShape(Rectangle())
                        .frame(height: DRAG_HANDLE_HEIGHT)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.5))
                                .frame(width: 60, height: 4)
                        )
                        // Drag gesture handling for resize handle area
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    withAnimation {
                                        let newHeight = topHeight + value.translation.height
                                        splitPosition = clamp(value: newHeight  / _geometry.size.height, min: MIN_SPLIT_POSITION, max: MAX_SPLIT_POSITION)
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    // Find the closest position to snap
                                    let result: (minDiff: CGFloat, closestValue: CGFloat?) = SNAP_POSITIONS.reduce(
                                        (minDiff: .infinity, closestValue: nil)
                                    ) { acc, value in
                                        let diff = abs(value - splitPosition)
                                        if diff < acc.minDiff {
                                            return (minDiff: diff, closestValue: value)
                                        }
                                        return acc
                                    }
                                    // If we managed to find a closest position to snap, we snap
                                    guard let closestPosition = result.closestValue else { return }
                                    isSnapping = true
                                    withAnimation {
                                        if splitPosition >= DISMISS_POSITION {
                                            splitPosition = 1.0
                                        } else {
                                            splitPosition = closestPosition
                                        }
                                    } completion: {
                                        let newHeight = _geometry.size.height * splitPosition
                                        self.onTopViewHeightChange?(newHeight)
                                        DispatchQueue.main.async {
                                            isSnapping = false
                                            if (splitPosition == 1.0) {
                                                self.onBottomDismissed?()
                                            }
                                        }
                                    }
                                }
                        )
                        .animation(isSnapping || !hasShownBottomView ? .bouncy : nil, value: splitPosition)
                    
                    // Bottom container - clips bottomView from top
                    bottomView
                        .frame(width: _geometry.size.width, height: bottomHeight, alignment: .top)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: CORNER_RADIUS, topTrailingRadius: CORNER_RADIUS))
                        // Drag gesture handling for bottom container as well
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    withAnimation {
                                        let newHeight = topHeight + value.translation.height
                                        splitPosition = clamp(value: newHeight  / _geometry.size.height, min: MIN_SPLIT_POSITION, max: MAX_SPLIT_POSITION)
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    // Find the closest position to snap
                                    let result: (minDiff: CGFloat, closestValue: CGFloat?) = SNAP_POSITIONS.reduce(
                                        (minDiff: .infinity, closestValue: nil)
                                    ) { acc, value in
                                        let diff = abs(value - splitPosition)
                                        if diff < acc.minDiff {
                                            return (minDiff: diff, closestValue: value)
                                        }
                                        return acc
                                    }
                                    // If we managed to find a closest position to snap, we snap
                                    guard let closestPosition = result.closestValue else { return }
                                    isSnapping = true
                                    withAnimation {
                                        if splitPosition >= DISMISS_POSITION {
                                            splitPosition = 1.0
                                        } else {
                                            splitPosition = closestPosition
                                        }
                                    } completion: {
                                        let newHeight = _geometry.size.height * splitPosition
                                        self.onTopViewHeightChange?(newHeight)
                                        DispatchQueue.main.async {
                                            isSnapping = false
                                            if (splitPosition == 1.0) {
                                                self.onBottomDismissed?()
                                            }
                                        }
                                    }
                                }
                        )
                        .animation(isSnapping || !hasShownBottomView ? .bouncy : nil, value: splitPosition)
                }
            }
            .onAppear {
                updateIsLandscape(size: _geometry.size)
                // When appeared, update splitPosition:
                // If we don't have bottomView, then show full topView
                // Otherwise, default at halfway position
                withAnimation {
                    splitPosition = hasBottomView ? 0.5 : 1.0
                } completion: {
                    hasShownBottomView = hasBottomView
                    let newHeight = _geometry.size.height * splitPosition
                    self.onTopViewHeightChange?(newHeight)
                }
            }
            .onChange(of: _geometry.size) { _, newValue in
                updateIsLandscape(size: newValue)
                let newHeight = newValue.height * splitPosition
                self.onTopViewHeightChange?(newHeight)
            }
            .onChange(of: hasBottomView) { _, newValue in
                withAnimation {
                    splitPosition = newValue ? 0.5 : 1.0
                } completion: {
                    hasShownBottomView = newValue
                    let newHeight = _geometry.size.height * splitPosition
                    self.onTopViewHeightChange?(newHeight)
                }
            }
        }
    }
    
    /// Update if device is landscape by checking width > height for given size
    private func updateIsLandscape(size: CGSize) {
        viewSize = size
        let _isLandscape = size.width > size.height
        guard _isLandscape != isLandscape else { return }
        isLandscape = _isLandscape
    }
}

#Preview {
    ResizableSplitView(
        top: { Color.white },
        bottom: { Color.white },
        hasBottomView: true
    ).ignoresSafeArea(.container, edges: .bottom)
}
