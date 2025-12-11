//
//  DrawingThumbnailGenerator.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import UIKit

/// Multiplier for stroke width in small thumbnails (20px) to ensure visibility when displayed at tiny sizes
private let SMALL_THUMBNAIL_STROKE_MULTIPLIER: CGFloat = 3.0

@MainActor
class DrawingThumbnailGenerator {
  static let shared = DrawingThumbnailGenerator()

  private init() {}

  /// Generate both thumbnails (20px and 200px) from drawing data
  /// - Parameter drawingData: The raw drawing path data
  /// - Returns: Tuple of (20px thumbnail, 200px thumbnail) data
  func generateThumbnails(from drawingData: Data) async -> (Data?, Data?) {
    // Decode the drawing data
    guard let pathsData = decodeDrawingData(drawingData) else {
      return (nil, nil)
    }

    // Generate 20px thumbnail with thicker strokes for visibility
    let thumbnail20 = await generateThumbnail(from: pathsData, size: 20, useThickerStrokes: true)
    // Generate 200px thumbnail with normal strokes
    let thumbnail200 = await generateThumbnail(from: pathsData, size: 200, useThickerStrokes: false)

    return (thumbnail20, thumbnail200)
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

    // Use thicker strokes for small thumbnails (<=20px)
    let useThickerStrokes = size <= 20
    return await generateThumbnail(from: pathsData, size: size, useThickerStrokes: useThickerStrokes)
  }

  /// Generate thumbnail from decoded path data
  private func generateThumbnail(from pathsData: [PathData], size: CGFloat, useThickerStrokes: Bool) async -> Data? {
    // Create the drawing view
    let drawingView = ThumbnailDrawingView(pathsData: pathsData, size: size, useThickerStrokes: useThickerStrokes)

    // Render to image
    let renderer = ImageRenderer(content: drawingView)
    renderer.scale = UIScreen.main.scale

    guard let uiImage = renderer.uiImage else {
      return nil
    }

    // Compress to PNG
    return uiImage.pngData()
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
  let useThickerStrokes: Bool

  var body: some View {
    Canvas { context, canvasSize in
      // Scale factor to fit CANVAS_SIZE into thumbnail size
      let scale = size / CANVAS_SIZE
      let strokeMultiplier: CGFloat = useThickerStrokes ? SMALL_THUMBNAIL_STROKE_MULTIPLIER : 1.0

      for pathData in pathsData {
        if pathData.isDot {
          // Fill dots with appropriate size
          guard let center = pathData.points.first else { continue }
          let dotRadius = (DRAWING_LINE_WIDTH / 2) * scale * strokeMultiplier
          let scaledCenter = CGPoint(x: center.x * scale, y: center.y * scale)
          let dotPath = Path(ellipseIn: CGRect(
            x: scaledCenter.x - dotRadius,
            y: scaledCenter.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
          ))
          context.fill(dotPath, with: .color(.appPrimary))
        } else {
          // Create and scale the line path
          let path = createLinePath(from: pathData)
          let scaledPath = path.applying(CGAffineTransform(scaleX: scale, y: scale))

          // Stroke lines with appropriate width
          let lineWidth = DRAWING_LINE_WIDTH * scale * strokeMultiplier
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

  /// Create a line Path from PathData (not for dots)
  private func createLinePath(from pathData: PathData) -> Path {
    var path = Path()

    for (index, point) in pathData.points.enumerated() {
      if index == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }

    return path
  }
}
