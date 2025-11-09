//
//  ShareCardRenderer.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import UIKit

@MainActor
class ShareCardRenderer {
  static let shared = ShareCardRenderer()

  private init() {}

  /// Pre-renders a drawing at high resolution for embedding in share cards
  /// - Parameters:
  ///   - entry: The day entry containing the drawing data
  ///   - size: The target size for the rendered drawing
  /// - Returns: A high-resolution UIImage of the drawing
  private func renderDrawingAtHighResolution(entry: DayEntry, size: CGSize) -> UIImage? {
    guard let drawingData = entry.drawingData, !drawingData.isEmpty else {
      return nil
    }

    // Fixed scales for consistent crisp quality
    // renderScale: how much to scale the logical view size
    // formatScale: the backing scale for UIGraphicsImageRenderer (affects Canvas rasterization)
    let renderScale: CGFloat = 3
    let formatScale: CGFloat = 1
    let renderSize = CGSize(width: size.width * renderScale, height: size.height * renderScale)

    print("🎨 Rendering doodle: \(size.width)x\(size.height) -> \(renderSize.width)x\(renderSize.height) @ \(formatScale)x = \(renderSize.width * formatScale) actual pixels")

    // Create a high-res drawing view
    let drawingView = DrawingDisplayView(
      entry: entry,
      displaySize: size.width * renderScale,
      dotStyle: .present,
      accent: true,
      highlighted: false,
      scale: 1.0,
      useThumbnail: false
    )
    .frame(width: renderSize.width, height: renderSize.height)

    // Render to high-res image
    let controller = UIHostingController(rootView: drawingView)
    controller.view.bounds = CGRect(origin: .zero, size: renderSize)
    controller.view.backgroundColor = .clear

    // Add to a temporary window to ensure the view is in a window hierarchy
    // This allows the view to render at least once before capture
    let window = UIWindow(frame: CGRect(origin: .zero, size: renderSize))
    window.rootViewController = controller
    window.isHidden = false

    // Force layout
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = formatScale
    format.opaque = false

    let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
    let image = renderer.image { context in
      controller.view.drawHierarchy(in: CGRect(origin: .zero, size: renderSize), afterScreenUpdates: true)
    }

    // Clean up window
    window.isHidden = true
    window.rootViewController = nil

    print("🎨 Generated doodle image: \(image.size), scale: \(image.scale)")
    return image
  }

  /// Renders a SwiftUI view as a UIImage
  /// - Parameters:
  ///   - view: The SwiftUI view to render
  ///   - size: The size of the output image
  /// - Returns: A UIImage representation of the view
  func render<Content: View>(view: Content, size: CGSize) -> UIImage? {
    let controller = UIHostingController(rootView: view)
    controller.view.bounds = CGRect(origin: .zero, size: size)
    controller.view.backgroundColor = .clear

    // Force layout pass
    let targetSize = controller.sizeThatFits(in: size)
    controller.view.bounds = CGRect(origin: .zero, size: targetSize)
    controller.view.layoutIfNeeded()

    // Explicitly set scale to 1.0 to output exact pixel dimensions
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0

    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
      controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
    }
  }

  /// Renders a card style with entry data as a UIImage
  /// - Parameters:
  ///   - style: The card style to render
  ///   - entry: The day entry containing the content
  ///   - date: The date for the entry
  ///   - colorScheme: The color scheme to use for rendering
  /// - Returns: A UIImage representation of the card
  func renderCard(
    style: ShareCardStyle,
    entry: DayEntry?,
    date: Date,
    colorScheme: ColorScheme
  ) -> UIImage? {
    // Pre-render drawing at high resolution if present
    var highResDrawing: UIImage?
    if let entry = entry, entry.drawingData != nil {
      let scale = style.cardSize.width / 1080.0
      let drawingSize = CGSize(width: 600 * scale, height: 600 * scale)
      highResDrawing = renderDrawingAtHighResolution(entry: entry, size: drawingSize)
      print("🎨 High-res drawing generated: \(highResDrawing != nil)")
    }

    let cardView = createCardView(
      style: style,
      entry: entry,
      date: date,
      highResDrawing: highResDrawing
    )
    .environment(\.colorScheme, colorScheme)
    .frame(width: style.cardSize.width, height: style.cardSize.height)
    .fixedSize()

    return render(view: cardView, size: style.cardSize)
  }

  /// Creates the appropriate card view based on style
  @ViewBuilder
  private func createCardView(
    style: ShareCardStyle,
    entry: DayEntry?,
    date: Date,
    highResDrawing: UIImage?
  ) -> some View {
    switch style {
    case .square:
      MinimalCardStyleView(entry: entry, date: date, highResDrawing: nil)
    }
  }
}
