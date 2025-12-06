//
//  PathExtension.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

extension Path {
  /// Extracts points from the path for serialization
  func extractPoints() -> [CGPoint] {
    // For dots (small ellipses), store the center point
    let boundingRect = self.boundingRect

    // Check if it's a dot (small circle created by tap)
    // We use DRAWING_LINE_WIDTH as a heuristic since dots are created with this diameter
    if boundingRect.width <= DRAWING_LINE_WIDTH && boundingRect.height <= DRAWING_LINE_WIDTH {
      let center = CGPoint(
        x: boundingRect.midX,
        y: boundingRect.midY
      )
      return [center]
    }

    // For regular paths, extract all points
    var points: [CGPoint] = []

    self.forEach { element in
      switch element {
      case .move(to: let point):
        points.append(point)
      case .line(to: let point):
        points.append(point)
      case .quadCurve(to: let point, control: _):
        points.append(point)
      case .curve(to: let point, control1: _, control2: _):
        points.append(point)
      case .closeSubpath:
        break
      }
    }

    return points
  }
}
