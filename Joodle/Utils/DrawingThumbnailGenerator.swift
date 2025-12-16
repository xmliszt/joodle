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

class DrawingThumbnailGenerator {
  static let shared = DrawingThumbnailGenerator()

  private init() {}

  /// Generate both thumbnails (20px and 200px) from drawing data
  /// - Parameter drawingData: The raw drawing path data
  /// - Returns: Tuple of (20px thumbnail, 200px thumbnail) data
  func generateThumbnails(from drawingData: Data) async -> (Data?, Data?) {
    // Run on detached task to avoid blocking main thread
    return await Task.detached(priority: .userInitiated) {
      // Decode the drawing data
      guard let pathsData = self.decodeDrawingData(drawingData) else {
        return (nil, nil)
      }

      // Generate 20px thumbnail with thicker strokes for visibility
      let thumbnail20 = self.generateThumbnailCG(from: pathsData, size: 20, useThickerStrokes: true)
      // Generate 200px thumbnail with normal strokes
      let thumbnail200 = self.generateThumbnailCG(from: pathsData, size: 200, useThickerStrokes: false)

      return (thumbnail20, thumbnail200)
    }.value
  }

  /// Generate a single thumbnail at specified size
  /// - Parameters:
  ///   - drawingData: The raw drawing path data
  ///   - size: The desired thumbnail size (square)
  /// - Returns: PNG data of the thumbnail
  func generateThumbnail(from drawingData: Data, size: CGFloat) async -> Data? {
    // Use thicker strokes for small thumbnails (<=20px)
    let useThickerStrokes = size <= 20

    return await Task.detached(priority: .userInitiated) {
      guard let pathsData = self.decodeDrawingData(drawingData) else {
        return nil
      }
      return self.generateThumbnailCG(from: pathsData, size: size, useThickerStrokes: useThickerStrokes)
    }.value
  }

  /// Generate thumbnail from decoded path data using Core Graphics
  private func generateThumbnailCG(from pathsData: [PathData], size: CGFloat, useThickerStrokes: Bool) -> Data? {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))

    let image = renderer.image { context in
      let cgContext = context.cgContext
      let scale = size / CANVAS_SIZE
      let strokeMultiplier: CGFloat = useThickerStrokes ? SMALL_THUMBNAIL_STROKE_MULTIPLIER : 1.0

      // Set colors
      let uiColor = UIColor(Color.appAccent)
      cgContext.setStrokeColor(uiColor.cgColor)
      cgContext.setFillColor(uiColor.cgColor)

      for pathData in pathsData {
        if pathData.isDot {
          // Fill dots with appropriate size
          guard let center = pathData.points.first else { continue }
          let dotRadius = (DRAWING_LINE_WIDTH / 2) * scale * strokeMultiplier
          let scaledCenter = CGPoint(x: center.x * scale, y: center.y * scale)

          let rect = CGRect(
            x: scaledCenter.x - dotRadius,
            y: scaledCenter.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
          )
          cgContext.fillEllipse(in: rect)
        } else {
          // Create and scale the line path
          let path = CGMutablePath()

          for (index, point) in pathData.points.enumerated() {
            let scaledPoint = CGPoint(x: point.x * scale, y: point.y * scale)
            if index == 0 {
              path.move(to: scaledPoint)
            } else {
              path.addLine(to: scaledPoint)
            }
          }

          cgContext.addPath(path)
          cgContext.setLineWidth(max(DRAWING_LINE_WIDTH * scale * strokeMultiplier, 1.0))
          cgContext.setLineCap(.round)
          cgContext.setLineJoin(.round)
          cgContext.strokePath()
        }
      }
    }

    // Compress to PNG
    return image.pngData()
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
