//
//  SharedCanvasView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

/// A reusable canvas view that handles drawing logic, rendering, and gestures.
/// It is designed to be stateless regarding the data persistence, delegating that to the parent view.
struct SharedCanvasView: View {
  @Binding var paths: [Path]
  @Binding var pathMetadata: [PathMetadata]
  @Binding var currentPath: Path
  @Binding var currentPathIsDot: Bool
  @Binding var isDrawing: Bool

  var placeholderData: Data? = nil

  /// Callback when a stroke is finished (finger lifted or moved out of bounds)
  var onCommitStroke: () -> Void

  @State private var placeholderPaths: [(path: Path, isDot: Bool)] = []
  @State private var placeholderID = UUID()

  var body: some View {
    ZStack {
      // Canvas background
      RoundedRectangle(cornerRadius: 12)
        .fill(.backgroundColor)
        .stroke(.borderColor, lineWidth: 1.0)
        .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)

      // Drawing area
      Canvas { context, size in
        // Draw placeholder if empty
        if paths.isEmpty && currentPath.isEmpty && !placeholderPaths.isEmpty {
          for (path, isDot) in placeholderPaths {
            if isDot {
              context.fill(path, with: .color(.gray.opacity(0.5)))
            } else {
              context.stroke(
                path,
                with: .color(.gray.opacity(0.5)),
                style: StrokeStyle(
                  lineWidth: DRAWING_LINE_WIDTH,
                  lineCap: .round,
                  lineJoin: .round
                )
              )
            }
          }
        }

        // Draw all completed paths
        for (index, path) in paths.enumerated() {
          // Use stored metadata to determine rendering
          let isDot = index < pathMetadata.count ? pathMetadata[index].isDot : false

          if isDot {
            // Fill ellipse paths (dots)
            context.fill(path, with: .color(.appPrimary))
          } else {
            // Stroke line paths
            context.stroke(
              path,
              with: .color(.appPrimary),
              style: StrokeStyle(
                lineWidth: DRAWING_LINE_WIDTH,
                lineCap: .round,
                lineJoin: .round
              )
            )
          }
        }

        // Draw current path being drawn
        if !currentPath.isEmpty {
          if currentPathIsDot {
            // Fill ellipse paths (dots)
            context.fill(currentPath, with: .color(.appPrimary))
          } else {
            // Stroke line paths
            context.stroke(
              currentPath,
              with: .color(.appPrimary),
              style: StrokeStyle(
                lineWidth: DRAWING_LINE_WIDTH,
                lineCap: .round,
                lineJoin: .round
              )
            )
          }
        }
      }
      .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .id(placeholderID)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let point = value.location
            let isInBounds =
            point.x >= 0 && point.x <= CANVAS_SIZE && point.y >= 0 && point.y <= CANVAS_SIZE

            if isInBounds {
              // Point is within bounds
              if !isDrawing {
                // Starting a new stroke
                isDrawing = true
                currentPathIsDot = false
                currentPath.move(to: point)
              } else {
                // Continue current stroke
                currentPath.addLine(to: point)
              }
            } else {
              // Point is out of bounds
              if isDrawing && !currentPath.isEmpty {
                // Commit the current stroke when going out of bounds
                onCommitStroke()
              }
            }
          }
          .onEnded { value in
            let isTap = value.velocity == .zero

            // Check if this was a single tap
            if isTap {
              // Create a small circle for the dot
              let point = value.location
              currentPath = Path()
              currentPathIsDot = true
              let dotRadius = DRAWING_LINE_WIDTH / 2
              currentPath.addEllipse(
                in: CGRect(
                  x: point.x - dotRadius,
                  y: point.y - dotRadius,
                  width: dotRadius * 2,
                  height: dotRadius * 2
                ))
            }

            // Commit the stroke
            if isDrawing && !currentPath.isEmpty {
              onCommitStroke()
            }

            // Reset drawing state
            isDrawing = false
            currentPathIsDot = false
          }
      )
    }
    .onAppear {
      decodePlaceholder()
    }
    .onChange(of: placeholderData) { _, _ in
      decodePlaceholder()
    }
  }

  private func decodePlaceholder() {
    guard let data = placeholderData else {
      placeholderPaths = []
      placeholderID = UUID()
      return
    }

    do {
      let decodedPaths = try JSONDecoder().decode([PathData].self, from: data)
      placeholderPaths = decodedPaths.map { pathData in
        var path = Path()
        if pathData.isDot && pathData.points.count >= 1 {
          // Recreate dot as ellipse
          let center = pathData.points[0]
          let dotRadius = DRAWING_LINE_WIDTH / 2
          path.addEllipse(
            in: CGRect(
              x: center.x - dotRadius,
              y: center.y - dotRadius,
              width: dotRadius * 2,
              height: dotRadius * 2
            ))
        } else {
          // Recreate line path
          for (index, point) in pathData.points.enumerated() {
            if index == 0 {
              path.move(to: point)
            } else {
              path.addLine(to: point)
            }
          }
        }
        return (path, pathData.isDot)
      }
      placeholderID = UUID()
    } catch {
      print("Failed to decode placeholder data: \(error)")
      placeholderPaths = []
      placeholderID = UUID()
    }
  }
}
