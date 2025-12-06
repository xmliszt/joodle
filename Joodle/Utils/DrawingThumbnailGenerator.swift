//
//  DrawingThumbnailGenerator.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import UIKit

@MainActor
class DrawingThumbnailGenerator {
  static let shared = DrawingThumbnailGenerator()

  private init() {}

  /// Generate thumbnails at multiple sizes from drawing data
  /// - Parameter drawingData: The raw drawing path data
  /// - Returns: Tuple of (20px, 200px, 1080px) thumbnail data
  func generateThumbnails(from drawingData: Data) async -> (Data?, Data?, Data?) {
    // Decode the drawing data
    guard let pathsData = decodeDrawingData(drawingData) else {
      return (nil, nil, nil)
    }

    // Generate thumbnails at different sizes
    let thumbnail20 = await generateThumbnail(from: pathsData, size: 20)
    let thumbnail200 = await generateThumbnail(from: pathsData, size: 200)
    let thumbnail1080 = await generateThumbnail(from: pathsData, size: 1080)

    return (thumbnail20, thumbnail200, thumbnail1080)
  }

  /// Generate a single thumbnail at specified size
  /// - Parameters:
  ///   - drawingData: The raw drawing path data
  ///   - size: The desired thumbnail size (square)
  /// - Returns: PNG data of the thumbnail
  func generateThumbnail(from drawingData: Data, size: CGFloat) async -> Data? {
    guard let pathsData = decodeDrawingData(drawingData) else {
      return nil
    }

    return await generateThumbnail(from: pathsData, size: size)
  }

  /// Generate thumbnail from decoded path data
  private func generateThumbnail(from pathsData: [PathData], size: CGFloat) async -> Data? {
    // Create the drawing view
    let drawingView = ThumbnailDrawingView(pathsData: pathsData, size: size)

    // Render to image
    let renderer = ImageRenderer(content: drawingView)
    renderer.scale = UIScreen.main.scale

    guard let uiImage = renderer.uiImage else {
      return nil
    }

    // Compress to PNG with optimization
    if size <= 20 {
      // Use lower quality for tiny thumbnails
      return uiImage.pngData()
    } else if size <= 200 {
      // Medium quality for medium thumbnails
      return uiImage.pngData()
    } else {
      // High quality for large thumbnails
      return uiImage.pngData()
    }
  }

  /// Decode drawing data from JSON
  private func decodeDrawingData(_ data: Data) -> [PathData]? {
    do {
      let pathsData = try JSONDecoder().decode([PathData].self, from: data)
      return pathsData
    } catch {
      print("Failed to decode drawing data: \(error)")
      return nil
    }
  }
}

// MARK: - Thumbnail Drawing View

private struct ThumbnailDrawingView: View {
  let pathsData: [PathData]
  let size: CGFloat

  var body: some View {
    Canvas { context, canvasSize in
      // Scale factor to fit CANVAS_SIZE into thumbnail size
      let scale = size / CANVAS_SIZE

      for pathData in pathsData {
        let path = createPath(from: pathData)

        // Apply scaling transform
        var scaledPath = path
        scaledPath = scaledPath.applying(CGAffineTransform(scaleX: scale, y: scale))

        if pathData.isDot {
          // Fill dots
          context.fill(scaledPath, with: .color(.appPrimary))
        } else {
          // Stroke lines with scaled width
          let lineWidth = DRAWING_LINE_WIDTH * scale
          context.stroke(
            scaledPath,
            with: .color(.appPrimary),
            style: StrokeStyle(
              lineWidth: max(lineWidth, 1.0),
              lineCap: .round,
              lineJoin: .round
            )
          )
        }
      }
    }
    .frame(width: size, height: size)
    .background(Color.clear)
  }

  /// Create a Path from PathData
  private func createPath(from pathData: PathData) -> Path {
    var path = Path()

    if pathData.isDot && !pathData.points.isEmpty {
      // Create dot as ellipse
      let center = pathData.points[0]
      let dotRadius = DRAWING_LINE_WIDTH / 2
      path.addEllipse(
        in: CGRect(
          x: center.x - dotRadius,
          y: center.y - dotRadius,
          width: dotRadius * 2,
          height: dotRadius * 2
        )
      )
    } else {
      // Create line path
      for (index, point) in pathData.points.enumerated() {
        if index == 0 {
          path.move(to: point)
        } else {
          path.addLine(to: point)
        }
      }
    }

    return path
  }
}
