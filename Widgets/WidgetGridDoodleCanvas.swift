//
//  WidgetGridDoodleCanvas.swift
//  Widgets
//
//  Created by Joodle
//

import SwiftUI

/// A Canvas-based view that renders a doodle from drawing data for widget grid cells.
/// Shared by MonthGridWidget and WeekGridWidget.
struct WidgetGridDoodleCanvas: View {
  let drawingData: Data
  let themeColor: Color

  var body: some View {
    Canvas { context, size in
      let paths = decodePaths(from: drawingData)
      let scale = min(size.width / DOODLE_CANVAS_SIZE, size.height / DOODLE_CANVAS_SIZE)
      let offsetX = (size.width - DOODLE_CANVAS_SIZE * scale) / 2
      let offsetY = (size.height - DOODLE_CANVAS_SIZE * scale) / 2
      let lineWidth: CGFloat = 5.0 * scale

      for pathData in paths {
        var scaledPath = Path()

        if pathData.isDot, let center = pathData.points.first {
          let scaledCenter = CGPoint(
            x: center.x * scale + offsetX,
            y: center.y * scale + offsetY
          )
          let radius = lineWidth / 2
          scaledPath.addEllipse(in: CGRect(
            x: scaledCenter.x - radius,
            y: scaledCenter.y - radius,
            width: radius * 2,
            height: radius * 2
          ))
          context.fill(scaledPath, with: .color(themeColor))
        } else if pathData.points.count > 1 {
          let first = pathData.points[0]
          scaledPath.move(to: CGPoint(
            x: first.x * scale + offsetX,
            y: first.y * scale + offsetY
          ))

          for point in pathData.points.dropFirst() {
            scaledPath.addLine(to: CGPoint(
              x: point.x * scale + offsetX,
              y: point.y * scale + offsetY
            ))
          }

          context.stroke(scaledPath, with: .color(themeColor), style: StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            lineJoin: .round
          ))
        }
      }
    }
  }

  private func decodePaths(from data: Data) -> [GridCellPathData] {
    (try? JSONDecoder().decode([GridCellPathData].self, from: data)) ?? []
  }
}

private struct GridCellPathData: Codable {
  let points: [CGPoint]
  let isDot: Bool
}
