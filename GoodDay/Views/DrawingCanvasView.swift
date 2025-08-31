//
//  DrawingCanvasView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

struct DrawingCanvasView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var entries: [DayEntry]

  let date: Date
  let onDismiss: () -> Void

  private var entry: DayEntry? {
    return entries.first { Calendar.current.isDate($0.createdAt, inSameDayAs: date) }
  }

  @State private var currentPath = Path()
  @State private var paths: [Path] = []
  @State private var pathMetadata: [PathMetadata] = []
  @State private var currentPathIsDot = false
  @State private var showClearConfirmation = false
  @State private var isDrawing = false

  // Undo/Redo state management
  @State private var undoStack: [([Path], [PathMetadata])] = []
  @State private var redoStack: [([Path], [PathMetadata])] = []

  var body: some View {
    VStack(spacing: 16) {
      // Header with clear, undo/redo, and save buttons
      HStack {
        // Clear button
        Button(action: { showClearConfirmation = true }) {
          Image(systemName: "trash")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.red)
            .frame(width: 36, height: 36)
            .background(.controlBackgroundColor)
            .clipShape(Circle())
        }
        .disabled(paths.isEmpty && currentPath.isEmpty)
        .opacity(paths.isEmpty && currentPath.isEmpty ? 0.5 : 1.0)

        Spacer()

        // Undo/Redo buttons
        HStack(spacing: 8) {
          // Undo button
          Button(action: undoLastStroke) {
            Image(systemName: "arrow.uturn.backward")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.textColor)
              .frame(width: 32, height: 32)
              .background(.controlBackgroundColor)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .disabled(undoStack.isEmpty)
          .opacity(undoStack.isEmpty ? 0.3 : 1.0)

          // Redo button
          Button(action: redoLastStroke) {
            Image(systemName: "arrow.uturn.forward")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.textColor)
              .frame(width: 32, height: 32)
              .background(.controlBackgroundColor)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .disabled(redoStack.isEmpty)
          .opacity(redoStack.isEmpty ? 0.3 : 1.0)
        }

        Spacer()

        // Save button
        Button(action: saveDrawing) {
          Image(systemName: "checkmark")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.textColor)
            .frame(width: 36, height: 36)
            .background(.controlBackgroundColor)
            .clipShape(Circle())
        }
      }

      // Drawing canvas
      VStack(spacing: 12) {
        ZStack {
          // Canvas background
          RoundedRectangle(cornerRadius: 12)
            .fill(.backgroundColor)
            .stroke(.borderColor, lineWidth: 1.0)
            .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)

          // Drawing area
          Canvas { context, size in
            // Draw all completed paths
            for (index, path) in paths.enumerated() {
              // Use stored metadata to determine rendering
              let isDot = index < pathMetadata.count ? pathMetadata[index].isDot : false

              if isDot {
                // Fill ellipse paths (dots)
                context.fill(path, with: .color(.accent))
              } else {
                // Stroke line paths
                context.stroke(
                  path,
                  with: .color(.accent),
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
                context.fill(currentPath, with: .color(.accent))
              } else {
                // Stroke line paths
                context.stroke(
                  currentPath,
                  with: .color(.accent),
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
                    commitCurrentStroke()
                  }
                }
              }
              .onEnded { value in
                if isDrawing && !currentPath.isEmpty {
                  let point = value.location
                  let startLocation = value.startLocation
                  let distance = sqrt(
                    pow(point.x - startLocation.x, 2) + pow(point.y - startLocation.y, 2))

                  // Check if this was a single tap within bounds
                  if distance < 3.0 && point.x >= 0 && point.x <= CANVAS_SIZE && point.y >= 0
                    && point.y <= CANVAS_SIZE
                  {
                    // Create a small circle for the dot
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

                  // Commit the final stroke
                  commitCurrentStroke()
                }

                // Reset drawing state
                isDrawing = false
                currentPathIsDot = false
              }
          )
        }

        // Instructions
        Text("Draw with your finger")
          .font(.caption)
          .foregroundColor(.secondaryTextColor)
      }
    }
    .padding(20)
    .background(.backgroundColor)
    .onAppear {
      loadExistingDrawing()
    }
    .confirmationDialog("Clear Drawing", isPresented: $showClearConfirmation) {
      Button("Clear", role: .destructive, action: clearDrawing)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Clear all drawing?")
    }
  }

  // MARK: - Private Methods

  private func commitCurrentStroke() {
    guard !currentPath.isEmpty else { return }

    // Save current state to undo stack before making changes
    saveStateToUndoStack()

    // Add the current path and its metadata to completed paths
    paths.append(currentPath)
    pathMetadata.append(PathMetadata(isDot: currentPathIsDot))
    currentPath = Path()

    // Clear redo stack when new action is performed
    redoStack.removeAll()

    // Save immediately to store
    saveDrawingToStore()

    // Reset drawing state
    isDrawing = false
    currentPathIsDot = false
  }

  private func saveStateToUndoStack() {
    // Save current paths and metadata state to undo stack
    undoStack.append((paths, pathMetadata))

    // Limit undo stack size to prevent memory issues
    if undoStack.count > 50 {
      undoStack.removeFirst()
    }
  }

  private func undoLastStroke() {
    guard !undoStack.isEmpty else { return }

    // Save current state to redo stack
    redoStack.append((paths, pathMetadata))

    // Restore previous state from undo stack
    let (previousPaths, previousMetadata) = undoStack.removeLast()
    paths = previousPaths
    pathMetadata = previousMetadata

    // Clear current path if user is in middle of drawing
    currentPath = Path()
    isDrawing = false
    currentPathIsDot = false

    // Save to store
    saveDrawingToStore()

    // Limit redo stack size
    if redoStack.count > 50 {
      redoStack.removeFirst()
    }
  }

  private func redoLastStroke() {
    guard !redoStack.isEmpty else { return }

    // Save current state to undo stack
    saveStateToUndoStack()

    // Restore state from redo stack
    let (redoPaths, redoMetadata) = redoStack.removeLast()
    paths = redoPaths
    pathMetadata = redoMetadata

    // Clear current path if user is in middle of drawing
    currentPath = Path()
    isDrawing = false
    currentPathIsDot = false

    // Save to store
    saveDrawingToStore()
  }

  private func loadExistingDrawing() {
    guard let data = entry?.drawingData else {
      // Initialize with empty state for new drawings
      undoStack.removeAll()
      redoStack.removeAll()
      return
    }

    do {
      let decodedPaths = try JSONDecoder().decode([PathData].self, from: data)
      paths = decodedPaths.map { pathData in
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
        return path
      }

      // Load metadata as well
      pathMetadata = decodedPaths.map { PathMetadata(isDot: $0.isDot) }

      // Initialize undo/redo stacks for existing drawings
      undoStack.removeAll()
      redoStack.removeAll()

    } catch {
      print("Failed to load drawing data: \(error)")
    }
  }

  private func saveDrawing() {
    saveDrawingToStore()
    onDismiss()
  }

  private func saveDrawingToStore() {
    if let existingEntry = entry {
      // Update existing entry
      if paths.isEmpty {
        // No paths means no drawing data
        existingEntry.drawingData = nil
      } else {
        // Convert paths to serializable data
        let pathsData = paths.enumerated().map { (index, path) in
          let isDot = index < pathMetadata.count ? pathMetadata[index].isDot : false
          return PathData(points: extractPointsFromPath(path), isDot: isDot)
        }

        do {
          let data = try JSONEncoder().encode(pathsData)
          existingEntry.drawingData = data
        } catch {
          print("Failed to save drawing data: \(error)")
          existingEntry.drawingData = nil
        }
      }
    } else {
      // Create new entry
      if !paths.isEmpty {
        // Has drawing content
        let pathsData = paths.enumerated().map { (index, path) in
          let isDot = index < pathMetadata.count ? pathMetadata[index].isDot : false
          return PathData(points: extractPointsFromPath(path), isDot: isDot)
        }

        do {
          let data = try JSONEncoder().encode(pathsData)
          let newEntry = DayEntry(body: "", createdAt: date, drawingData: data)
          modelContext.insert(newEntry)
        } catch {
          print("Failed to save drawing data: \(error)")
        }
      }
    }

    // Save the context to persist changes
    try? modelContext.save()
  }

  private func clearDrawing() {
    // Save current state to undo stack before clearing
    if !paths.isEmpty {
      saveStateToUndoStack()
    }

    paths.removeAll()
    pathMetadata.removeAll()
    currentPath = Path()
    isDrawing = false
    currentPathIsDot = false

    // Clear redo stack when new action is performed
    redoStack.removeAll()

    // Also clear from store
    if let existingEntry = entry {
      existingEntry.drawingData = nil
      try? modelContext.save()
    }
  }

  private func extractPointsFromPath(_ path: Path) -> [CGPoint] {
    // For dots, store the center point
    let boundingRect = path.boundingRect
    if boundingRect.width <= DRAWING_LINE_WIDTH && boundingRect.height <= DRAWING_LINE_WIDTH {
      let center = CGPoint(
        x: boundingRect.midX,
        y: boundingRect.midY
      )
      return [center]
    }

    // For regular paths, extract all points
    var points: [CGPoint] = []

    path.forEach { element in
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

#Preview {
  DrawingCanvasView(
    date: Date(),
    onDismiss: {}
  )
}
