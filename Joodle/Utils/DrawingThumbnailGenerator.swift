//
//  DrawingThumbnailGenerator.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import UIKit

class DrawingThumbnailGenerator {
  static let shared = DrawingThumbnailGenerator()

  private init() {}

  /// Generate both thumbnails (20px and 200px) from drawing data
  /// - Parameter drawingData: The raw drawing path data
  /// - Returns: Tuple of (20px thumbnail, 200px thumbnail) data
  func generateThumbnails(from drawingData: Data) async -> (Data?, Data?) {
    // Capture the accent color on the calling thread to avoid thread-safety issues
    // when accessing UserPreferences.shared from background threads
    let accentColor = await MainActor.run { UIColor(Color.appAccent) }

    // Run on detached task to avoid blocking main thread
    return await Task.detached(priority: .userInitiated) {
      // Decode the drawing data
      guard let pathsData = self.decodeDrawingData(drawingData) else {
        return (nil, nil)
      }

      let thumbnail20 = self.generateThumbnailCG(from: pathsData, size: 20, color: accentColor)
      let thumbnail200 = self.generateThumbnailCG(from: pathsData, size: 200, color: accentColor)

      return (thumbnail20, thumbnail200)
    }.value
  }

  /// Generate a single thumbnail at specified size
  /// - Parameters:
  ///   - drawingData: The raw drawing path data
  ///   - size: The desired thumbnail size (square)
  /// - Returns: PNG data of the thumbnail
  func generateThumbnail(from drawingData: Data, size: CGFloat) async -> Data? {
    // Capture the accent color on the calling thread to avoid thread-safety issues
    // when accessing UserPreferences.shared from background threads
    let accentColor = await MainActor.run { UIColor(Color.appAccent) }

    return await Task.detached(priority: .userInitiated) {
      guard let pathsData = self.decodeDrawingData(drawingData) else {
        return nil
      }
      return self.generateThumbnailCG(from: pathsData, size: size, color: accentColor)
    }.value
  }

  /// Generate thumbnail from decoded path data using Core Graphics
  private func generateThumbnailCG(from pathsData: [PathData], size: CGFloat, color: UIColor) -> Data? {
    // Pin bitmap scale at 3× so thumbnails are device-independent. By default
    // UIGraphicsImageRenderer uses the current screen's scale, which on Mac
    // (iPad-app-on-Mac) is often 1.0 — producing a literal 20×20 PNG that
    // looks pixelated when CloudKit syncs it back to a Retina iPhone.
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 3.0
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: size, height: size),
      format: format
    )

    let image = renderer.image { context in
      let cgContext = context.cgContext
      let scale = size / CANVAS_SIZE

      // Set colors using the pre-captured color (thread-safe)
      cgContext.setStrokeColor(color.cgColor)
      cgContext.setFillColor(color.cgColor)

      for pathData in pathsData {
        if pathData.isDot {
          // Fill dots with appropriate size
          guard let center = pathData.points.first else { continue }
          let dotRadius = (DRAWING_LINE_WIDTH / 2) * scale
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
          cgContext.setLineWidth(DRAWING_LINE_WIDTH * scale)
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
