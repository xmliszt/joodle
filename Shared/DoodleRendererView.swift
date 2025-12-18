//
//  DoodleRendererView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

// MARK: - Shared Constants

/// Canvas size used for drawing (300x300)
let DOODLE_CANVAS_SIZE: CGFloat = 300

/// Default line width for drawing strokes
let DOODLE_LINE_WIDTH: CGFloat = 5.0

// MARK: - Shared Path Data Model

/// Shared path data model for decoding drawing data
/// Used by both main app and widget extension
struct DoodlePathData: Codable {
  let points: [CGPoint]
  let isDot: Bool

  init(points: [CGPoint], isDot: Bool = false) {
    self.points = points
    self.isDot = isDot
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    points = try container.decode([CGPoint].self, forKey: .points)
    isDot = try container.decodeIfPresent(Bool.self, forKey: .isDot) ?? false
  }

  private enum CodingKeys: String, CodingKey {
    case points
    case isDot
  }
}

// MARK: - Dot Style

/// Style for representing the temporal state of a dot
enum DoodleDotStyle {
  case past
  case present
  case future

  var opacity: Double {
    switch self {
    case .past, .present:
      return 1.0
    case .future:
      return 0.15
    }
  }
}

// MARK: - Doodle Renderer View

/// A shared view for rendering doodles consistently across the app and widgets.
///
/// This view renders drawing data from `Data` containing encoded path information,
/// or falls back to displaying a simple circle dot if no drawing data is available.
///
/// Usage:
/// ```swift
/// DoodleRendererView(
///   size: 26,
///   hasEntry: true,
///   dotStyle: .past,
///   drawingData: someData,
///   strokeColor: .blue
/// )
/// ```
struct DoodleRendererView: View {
  /// The size of the doodle container (width and height)
  let size: CGFloat

  /// Whether this dot has an associated entry
  let hasEntry: Bool

  /// The temporal style of the dot (past, present, or future)
  let dotStyle: DoodleDotStyle

  /// Optional raw drawing data to render
  let drawingData: Data?

  /// Optional thumbnail image data to use as fallback when drawingData is nil
  let thumbnail: Data?

  /// The color to use for strokes and fills
  let strokeColor: Color

  /// Multiplier for stroke width (useful for small sizes)
  let strokeMultiplier: CGFloat

  /// The scale factor for rendering (size * renderScale / CANVAS_SIZE)
  /// Default is 2.0 to render at 2x for better quality
  let renderScale: CGFloat

  init(
    size: CGFloat,
    hasEntry: Bool,
    dotStyle: DoodleDotStyle,
    drawingData: Data? = nil,
    thumbnail: Data? = nil,
    strokeColor: Color,
    strokeMultiplier: CGFloat = 3.0,
    renderScale: CGFloat = 2.0
  ) {
    self.size = size
    self.hasEntry = hasEntry
    self.dotStyle = dotStyle
    self.drawingData = drawingData
    self.thumbnail = thumbnail
    self.strokeColor = strokeColor
    self.strokeMultiplier = strokeMultiplier
    self.renderScale = renderScale
  }

  private var dotColor: Color {
    let baseColor: Color = hasEntry ? strokeColor : .primary
    return baseColor.opacity(dotStyle.opacity)
  }

  var body: some View {
    ZStack {
      if let data = drawingData,
         let paths = decodePaths(from: data),
         !paths.isEmpty {
        // Render drawing directly with the provided stroke color
        DoodleCanvasView(
          paths: paths,
          size: size,
          strokeColor: strokeColor,
          strokeMultiplier: strokeMultiplier,
          renderScale: renderScale
        )
        .opacity(dotStyle.opacity)
      } else if let thumbnailData = thumbnail,
                let uiImage = UIImage(data: thumbnailData)?.withRenderingMode(.alwaysTemplate) {
        // Fallback to thumbnail image if available
        // Use template rendering mode so the image adapts to the stroke color
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: size * 2, height: size * 2)
          .foregroundColor(strokeColor)
          .opacity(dotStyle.opacity)
      } else {
        // Fallback to simple circle dot
        Circle()
          .fill(dotColor)
          .frame(width: size / 1.5, height: size / 1.5)
      }
    }
    .frame(width: size, height: size)
  }

  private func decodePaths(from data: Data) -> [DoodlePathData]? {
    do {
      return try JSONDecoder().decode([DoodlePathData].self, from: data)
    } catch {
      return nil
    }
  }
}

// MARK: - Canvas View for Path Rendering

/// Internal canvas view that renders the actual drawing paths
private struct DoodleCanvasView: View {
  let paths: [DoodlePathData]
  let size: CGFloat
  let strokeColor: Color
  let strokeMultiplier: CGFloat
  let renderScale: CGFloat

  var body: some View {
    Canvas { context, canvasSize in
      let scale = size * renderScale / DOODLE_CANVAS_SIZE

      for pathData in paths {
        var scaledPath = Path()

        if pathData.isDot && pathData.points.count >= 1 {
          // Render dot as filled circle
          let center = pathData.points[0]
          let dotRadius = (DOODLE_LINE_WIDTH / 2) * scale * strokeMultiplier
          let scaledCenter = CGPoint(x: center.x * scale, y: center.y * scale)
          scaledPath.addEllipse(in: CGRect(
            x: scaledCenter.x - dotRadius,
            y: scaledCenter.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
          ))
          context.fill(scaledPath, with: .color(strokeColor))
        } else if pathData.points.count > 1 {
          // Render path as stroked line
          for (index, point) in pathData.points.enumerated() {
            let scaledPoint = CGPoint(x: point.x * scale, y: point.y * scale)
            if index == 0 {
              scaledPath.move(to: scaledPoint)
            } else {
              scaledPath.addLine(to: scaledPoint)
            }
          }
          context.stroke(
            scaledPath,
            with: .color(strokeColor),
            style: StrokeStyle(
              lineWidth: max(DOODLE_LINE_WIDTH * scale * strokeMultiplier, 1.0),
              lineCap: .round,
              lineJoin: .round
            )
          )
        }
      }
    }
    .frame(width: size * renderScale, height: size * renderScale)
  }
}

// MARK: - Previews

#if DEBUG
#Preview("DoodleRendererView - With Drawing") {
  DoodleRendererView(
    size: 50,
    hasEntry: true,
    dotStyle: .past,
    drawingData: nil,
    strokeColor: .blue
  )
}

#Preview("DoodleRendererView - Empty") {
  DoodleRendererView(
    size: 50,
    hasEntry: false,
    dotStyle: .past,
    drawingData: nil,
    strokeColor: .blue
  )
}

#Preview("DoodleRendererView - Future") {
  DoodleRendererView(
    size: 50,
    hasEntry: true,
    dotStyle: .future,
    drawingData: nil,
    strokeColor: .orange
  )
}
#endif
