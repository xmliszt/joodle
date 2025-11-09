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
  ///   - targetPixelSize: The desired output size in physical pixels
  /// - Returns: A high-resolution UIImage at 1x scale that will be downsized by SwiftUI
  private func renderDrawingAtHighResolution(entry: DayEntry, targetPixelSize: CGSize) -> UIImage? {
    guard let drawingData = entry.drawingData, !drawingData.isEmpty else {
      return nil
    }

    // Render at high physical pixel resolution to preserve vector quality
    // The image will be created at 1x scale with high pixel dimensions
    // SwiftUI will then scale it down to fit the container
    let renderSize = targetPixelSize

    print("🎨 Rendering doodle at high resolution: \(renderSize.width)x\(renderSize.height) pixels @ 1x scale")

    // Create a high-res drawing view
    let drawingView = DrawingDisplayView(
      entry: entry,
      displaySize: renderSize.width,
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
    let window = UIWindow(frame: CGRect(origin: .zero, size: renderSize))
    window.rootViewController = controller
    window.isHidden = false

    // Force layout
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0  // Use 1x scale so image size = pixel size, SwiftUI will downsize
    format.opaque = false

    let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
    let image = renderer.image { context in
      controller.view.drawHierarchy(in: CGRect(origin: .zero, size: renderSize), afterScreenUpdates: true)
    }

    // Clean up window
    window.isHidden = true
    window.rootViewController = nil

    print("🎨 Generated doodle image: \(image.size.width)x\(image.size.height) @ \(image.scale)x - will be scaled down by SwiftUI")
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

    // Use 3x scale for retina quality output
    let format = UIGraphicsImageRendererFormat()
    format.scale = 3.0

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
      // Render at high pixel resolution (1800x1800) @ 1x scale
      // SwiftUI will scale it down to fit the 600*scale container
      let highResPixelSize = CGSize(width: 1800, height: 1800)  // High resolution pixels
      highResDrawing = renderDrawingAtHighResolution(entry: entry, targetPixelSize: highResPixelSize)
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
      MinimalCardStyleView(entry: entry, date: date, highResDrawing: highResDrawing)
    }
  }
}
