//
//  FlowLayout.swift
//  Joodle
//
//  Created by Li Yuxuan on 22/2/26.
//

import SwiftUI

/// A wrapping layout that arranges subviews left-to-right and flows
/// to the next line when the available width is exceeded.
/// Used by `InspirationPromptView` to lay out per-word groups within the canvas.
struct FlowLayout: Layout {
  var horizontalSpacing: CGFloat = 6
  var verticalSpacing: CGFloat = 4
  var alignment: HorizontalAlignment = .leading

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let result = arrange(proposal: proposal, subviews: subviews)
    return result.size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let result = arrange(proposal: proposal, subviews: subviews)
    let containerWidth = bounds.width

    for (index, subview) in subviews.enumerated() {
      let position = result.positions[index]
      let lineIndex = result.lineIndices[index]
      let lineWidth = result.lineWidths[lineIndex]

      // Horizontal offset for centering the line within the container
      let lineOffset: CGFloat
      switch alignment {
      case .center:
        lineOffset = (containerWidth - lineWidth) / 2
      case .trailing:
        lineOffset = containerWidth - lineWidth
      default:
        lineOffset = 0
      }

      subview.place(
        at: CGPoint(x: bounds.minX + position.x + lineOffset, y: bounds.minY + position.y),
        anchor: .topLeading,
        proposal: .unspecified
      )
    }
  }

  private struct ArrangeResult {
    var size: CGSize
    var positions: [CGPoint]
    /// Which line each subview belongs to
    var lineIndices: [Int]
    /// The total content width of each line
    var lineWidths: [CGFloat]
  }

  private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
    let maxWidth = proposal.width ?? .infinity
    var positions: [CGPoint] = []
    var lineIndices: [Int] = []
    var lineWidths: [CGFloat] = []
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var lineHeight: CGFloat = 0
    var totalWidth: CGFloat = 0
    var currentLine = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)

      // Wrap to next line if this subview doesn't fit
      if currentX + size.width > maxWidth, currentX > 0 {
        // Finalize current line width
        lineWidths.append(currentX - horizontalSpacing)
        currentX = 0
        currentY += lineHeight + verticalSpacing
        lineHeight = 0
        currentLine += 1
      }

      positions.append(CGPoint(x: currentX, y: currentY))
      lineIndices.append(currentLine)
      lineHeight = max(lineHeight, size.height)
      currentX += size.width + horizontalSpacing
      totalWidth = max(totalWidth, currentX - horizontalSpacing)
    }

    // Finalize last line
    if currentX > 0 {
      lineWidths.append(currentX - horizontalSpacing)
    }

    let totalHeight = currentY + lineHeight
    return ArrangeResult(
      size: CGSize(width: totalWidth, height: totalHeight),
      positions: positions,
      lineIndices: lineIndices,
      lineWidths: lineWidths
    )
  }
}
