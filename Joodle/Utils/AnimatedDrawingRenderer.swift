//
//  AnimatedDrawingRenderer.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI
import UIKit

/// Renders individual frames of an animated drawing for export
@MainActor
class AnimatedDrawingRenderer {

  /// Render a single drawing frame at a specific progress value
  /// - Parameters:
  ///   - pathsWithMetadata: The decoded paths with metadata
  ///   - progress: Animation progress from 0.0 to 1.0
  ///   - size: Output image size in pixels
  ///   - foregroundColor: Color for the strokes
  ///   - config: Animation configuration
  /// - Returns: Rendered frame as UIImage
  func renderDrawingFrame(
    pathsWithMetadata: [PathWithMetadata],
    progress: CGFloat,
    size: CGSize,
    foregroundColor: UIColor,
    config: DrawingAnimationConfig
  ) -> UIImage? {
    guard !pathsWithMetadata.isEmpty else { return nil }

    let timingInfo = config.calculateStrokeTiming(for: pathsWithMetadata)
    let totalDuration = timingInfo.totalDuration
    let cumulativeEndTimes = timingInfo.cumulativeEndTimes
    let durations = timingInfo.durations

    // Calculate current elapsed time based on progress
    let currentElapsedTime = progress * CGFloat(totalDuration)

    // Scale from CANVAS_SIZE (300x300) to output size
    let canvasScale = size.width / CANVAS_SIZE

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = false

    let renderer = UIGraphicsImageRenderer(size: size, format: format)

    return renderer.image { context in
      let cgContext = context.cgContext

      // Scale context
      cgContext.scaleBy(x: canvasScale, y: canvasScale)

      // Set drawing properties
      cgContext.setStrokeColor(foregroundColor.cgColor)
      cgContext.setFillColor(foregroundColor.cgColor)
      cgContext.setLineCap(.round)
      cgContext.setLineJoin(.round)
      cgContext.setLineWidth(DRAWING_LINE_WIDTH)

      for (index, pathWithMetadata) in pathsWithMetadata.enumerated() {
        // Determine start time for this stroke
        let strokeStartTime: CGFloat = index == 0 ? 0 : CGFloat(cumulativeEndTimes[index - 1])
        let strokeEndTime = CGFloat(cumulativeEndTimes[index])

        // Skip paths that haven't started yet
        guard currentElapsedTime > strokeStartTime else { continue }

        // Calculate trim for the current path being drawn
        let pathProgress: CGFloat
        if currentElapsedTime < strokeEndTime {
          // This stroke is currently being drawn
          let strokeDuration = CGFloat(durations[index])
          let timeIntoStroke = currentElapsedTime - strokeStartTime
          pathProgress = min(1.0, max(0.0, timeIntoStroke / strokeDuration))
        } else {
          // Stroke is complete
          pathProgress = 1.0
        }

        // Render based on metadata
        if pathWithMetadata.metadata.isDot {
          // For dots, fade in based on progress (appear when > 50%)
          if pathProgress > 0.5 {
            // Extract dot center from the path's bounding rect
            let bounds = pathWithMetadata.path.boundingRect
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let dotRadius = DRAWING_LINE_WIDTH / 2

            let rect = CGRect(
              x: center.x - dotRadius,
              y: center.y - dotRadius,
              width: dotRadius * 2,
              height: dotRadius * 2
            )
            cgContext.fillEllipse(in: rect)
          }
        } else {
          // For strokes, use trim effect
          let trimmedPath = pathWithMetadata.path.trimmedPath(from: 0, to: pathProgress)
          cgContext.addPath(trimmedPath.cgPath)
          cgContext.strokePath()
        }
      }
    }
  }

  /// Render a complete card frame using SwiftUI views to match MinimalView/ExcerptView exactly
  /// - Parameters:
  ///   - drawingImage: Pre-rendered drawing image for this frame
  ///   - entry: The day entry
  ///   - date: The date for the entry
  ///   - style: The share card style
  ///   - colorScheme: Color scheme for rendering
  ///   - showWatermark: Whether to show watermark
  /// - Returns: Rendered card frame as UIImage
  func renderCardFrame(
    drawingImage: UIImage,
    entry: DayEntry,
    date: Date,
    style: ShareCardStyle,
    colorScheme: ColorScheme,
    showWatermark: Bool
  ) -> UIImage? {
    let cardSize = style.cardSize
    let cardBackground = colorScheme == .dark ? Color.black : Color.white

    // Create the appropriate card view based on style
    let cardView: AnyView

    if style.includesExcerpt {
      cardView = AnyView(
        AnimatedExcerptCardView(
          entry: entry,
          date: date,
          drawingImage: drawingImage,
          cardSize: cardSize,
          showWatermark: showWatermark,
          animateDrawing: false,
          looping: false
        )
        .environment(\.colorScheme, colorScheme)
      )
    } else {
      cardView = AnyView(
        AnimatedMinimalCardView(
          entry: entry,
          drawingImage: drawingImage,
          cardSize: cardSize,
          showWatermark: showWatermark,
          animateDrawing: false,
          looping: false
        )
        .environment(\.colorScheme, colorScheme)
      )
    }

    // Render SwiftUI view to image
    let wrappedView = cardView
      .frame(width: cardSize.width, height: cardSize.height)
      .background(cardBackground)

    return renderSwiftUIView(wrappedView, size: cardSize)
  }

  /// Render a SwiftUI view to UIImage
  private func renderSwiftUIView<V: View>(_ view: V, size: CGSize) -> UIImage? {
    let controller = UIHostingController(rootView: view)
    controller.view.bounds = CGRect(origin: .zero, size: size)
    controller.view.backgroundColor = .clear

    // Disable safe area insets to prevent Y-offset
    controller.safeAreaRegions = []

    // Add to a temporary window to ensure the view is in a window hierarchy
    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
    window.rootViewController = controller
    window.isHidden = false

    // Force layout
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = true

    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let image = renderer.image { context in
      controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
    }

    // Clean up window
    window.isHidden = true
    window.rootViewController = nil

    return image
  }

  /// Generate all card frames for the animation
  /// - Parameters:
  ///   - entry: The day entry
  ///   - date: The date for the entry
  ///   - style: The share card style
  ///   - colorScheme: Color scheme for rendering
  ///   - showWatermark: Whether to show watermark
  ///   - progressCallback: Optional callback for progress updates
  /// - Returns: Array of composed card frames
  func generateCardFrames(
    entry: DayEntry,
    date: Date,
    style: ShareCardStyle,
    colorScheme: ColorScheme,
    showWatermark: Bool,
    progressCallback: ((Double) -> Void)? = nil
  ) async -> [UIImage] {
    guard let drawingData = entry.drawingData, !drawingData.isEmpty else {
      return []
    }

    // Get paths from cache
    let pathsWithMetadata = DrawingPathCache.shared.getPathsWithMetadata(for: drawingData)
    guard !pathsWithMetadata.isEmpty else { return [] }

    let config = style.animationConfig

    // Calculate actual animation duration based on stroke lengths
    let timingInfo = config.calculateStrokeTiming(for: pathsWithMetadata)
    let actualDuration = timingInfo.totalDuration

    // Calculate frame count based on actual duration
    let frameCount = max(1, Int(ceil(actualDuration * Double(config.frameRate))))

    // Get stroke color resolved for the provided color scheme
    let strokeColor = resolvedUIColor(for: .appAccent, colorScheme: colorScheme)

    // Calculate drawing size based on style
    let scale: CGFloat = 1.0 // We're rendering at actual card size
    let drawingSize: CGFloat

    if style.includesExcerpt {
      // Match ExcerptView: 600 * scale
      drawingSize = 600 * scale
    } else {
      // Match MinimalView: 800 * scale
      drawingSize = 800 * scale
    }

    var frames: [UIImage] = []
    frames.reserveCapacity(frameCount)

    for i in 0..<frameCount {
      // Calculate linear progress
      let linearProgress = CGFloat(i) / CGFloat(max(1, frameCount - 1))

      // Apply easeOut curve
      let easedProgress = DrawingAnimationConfig.applyEaseOut(linearProgress)

      // Render drawing frame at appropriate size
      guard let drawingFrame = renderDrawingFrame(
        pathsWithMetadata: pathsWithMetadata,
        progress: easedProgress,
        size: CGSize(width: drawingSize, height: drawingSize),
        foregroundColor: strokeColor,
        config: config
      ) else { continue }

      // Render complete card frame using SwiftUI
      guard let cardFrame = renderCardFrame(
        drawingImage: drawingFrame,
        entry: entry,
        date: date,
        style: style,
        colorScheme: colorScheme,
        showWatermark: showWatermark
      ) else { continue }

      frames.append(cardFrame)

      progressCallback?(Double(i + 1) / Double(frameCount))

      // Yield to prevent blocking UI
      if i % 3 == 0 {
        await Task.yield()
      }
    }

    return frames
  }

  // Resolve a SwiftUI Color into a UIColor for a specific color scheme (light/dark)
  private func resolvedUIColor(for color: Color, colorScheme: ColorScheme) -> UIColor {
    let uiColor = UIColor(color)
    let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
    return uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
  }
}
