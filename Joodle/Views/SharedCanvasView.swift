//
//  SharedCanvasView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

/// Configuration for the canvas action buttons
struct CanvasButtonsConfig {
  let onClear: () -> Void
  let onUndo: (() -> Void)?
  let onRedo: (() -> Void)?
  let canClear: Bool
  let canUndo: Bool
  let canRedo: Bool
  let showClearConfirmation: Binding<Bool>?

  init(
    onClear: @escaping () -> Void,
    onUndo: (() -> Void)? = nil,
    onRedo: (() -> Void)? = nil,
    canClear: Bool = true,
    canUndo: Bool = false,
    canRedo: Bool = false,
    showClearConfirmation: Binding<Bool>? = nil
  ) {
    self.onClear = onClear
    self.onUndo = onUndo
    self.onRedo = onRedo
    self.canClear = canClear
    self.canUndo = canUndo
    self.canRedo = canRedo
    self.showClearConfirmation = showClearConfirmation
  }
}

/// A reusable canvas view that handles drawing logic, rendering, and gestures.
/// It is designed to be stateless regarding the data persistence, delegating that to the parent view.
struct SharedCanvasView<TrailingHeader: View>: View {
  @Binding var paths: [Path]
  @Binding var pathMetadata: [PathMetadata]
  @Binding var currentPath: Path
  @Binding var currentPathIsDot: Bool
  @Binding var isDrawing: Bool

  var placeholderData: Data? = nil
  var buttonsConfig: CanvasButtonsConfig? = nil

  /// Track the maximum distance from start point during a gesture to detect dots vs strokes
  @State private var maxDistanceFromStart: CGFloat = 0
  @State private var gestureStartPoint: CGPoint = .zero

  /// Callback when a stroke is finished (finger lifted or moved out of bounds)
  var onCommitStroke: () -> Void

  /// Optional trailing content for the header row (e.g. Save button)
  var TrailingHeaderView: () -> TrailingHeader

  @State private var placeholderPaths: [(path: Path, isDot: Bool)] = []
  @State private var placeholderID = UUID()

  init(
    paths: Binding<[Path]>,
    pathMetadata: Binding<[PathMetadata]>,
    currentPath: Binding<Path>,
    currentPathIsDot: Binding<Bool>,
    isDrawing: Binding<Bool>,
    placeholderData: Data? = nil,
    buttonsConfig: CanvasButtonsConfig? = nil,
    onCommitStroke: @escaping () -> Void,
    @ViewBuilder trailingHeader: @escaping () -> TrailingHeader
  ) {
    self._paths = paths
    self._pathMetadata = pathMetadata
    self._currentPath = currentPath
    self._currentPathIsDot = currentPathIsDot
    self._isDrawing = isDrawing
    self.placeholderData = placeholderData
    self.buttonsConfig = buttonsConfig
    self.onCommitStroke = onCommitStroke
    self.TrailingHeaderView = trailingHeader
  }

  var body: some View {
    VStack(spacing: 16) {
      // Action Buttons Row
      if let config = buttonsConfig {
        HStack() {
          // Clear button
          Button(action: {
            if let showConfirmation = config.showClearConfirmation {
              showConfirmation.wrappedValue = true
            } else {
              config.onClear()
            }
          }) {
            Image(systemName: "trash")
          }
          .circularGlassButton(tintColor: .red)
          .disabled(!config.canClear)
          .opacity(config.canClear ? 1.0 : 0.5)

          Spacer()

          // Undo/Redo buttons
          HStack(spacing: 8) {
            // Undo button
            if let onUndo = config.onUndo {
              Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
              }
              .circularGlassButton(tintColor: .appTextSecondary)
              .disabled(!config.canUndo)
              .opacity(config.canUndo ? 1.0 : 0.3)
            }

            // Redo button
            if let onRedo = config.onRedo {
              Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
              }
              .circularGlassButton(tintColor: .appTextSecondary)
              .disabled(!config.canRedo)
              .opacity(config.canRedo ? 1.0 : 0.3)
            }
          }

          // Trailing content (e.g. Save button)
          if !(TrailingHeaderView() is EmptyView) {
            Spacer()
            TrailingHeaderView()
          }

        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
      }

      ZStack {
        // Canvas background
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .fill(.backgroundColor)
          .stroke(.borderColor, lineWidth: 1.0)
          .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)

        // Drawing area
        Canvas { context, size in
          // Draw placeholder if empty
          if paths.isEmpty && currentPath.isEmpty && !placeholderPaths.isEmpty {
            for (path, isDot) in placeholderPaths {
              if isDot {
                context.fill(path, with: .color(.gray.opacity(0.2)))
              } else {
                context.stroke(
                  path,
                  with: .color(.gray.opacity(0.2)),
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
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
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
                  // Track start point and reset max distance
                  gestureStartPoint = point
                  maxDistanceFromStart = 0
                } else {
                  // Continue current stroke
                  currentPath.addLine(to: point)
                  // Update max distance from start point
                  let dx = point.x - gestureStartPoint.x
                  let dy = point.y - gestureStartPoint.y
                  let distance = sqrt(dx * dx + dy * dy)
                  maxDistanceFromStart = max(maxDistanceFromStart, distance)
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
              // Use max distance traveled to determine if this was a tap (dot) or stroke
              // This correctly handles cases where user draws a path returning to start
              let tapThreshold: CGFloat = 3.0
              let isTap = maxDistanceFromStart < tapThreshold

              // Check if this was a single tap (minimal movement throughout gesture)
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
              maxDistanceFromStart = 0
            }
        )
      }
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

// Extension to support initialization without trailing header
extension SharedCanvasView where TrailingHeader == EmptyView {
  init(
    paths: Binding<[Path]>,
    pathMetadata: Binding<[PathMetadata]>,
    currentPath: Binding<Path>,
    currentPathIsDot: Binding<Bool>,
    isDrawing: Binding<Bool>,
    placeholderData: Data? = nil,
    buttonsConfig: CanvasButtonsConfig? = nil,
    onCommitStroke: @escaping () -> Void
  ) {
    self.init(
      paths: paths,
      pathMetadata: pathMetadata,
      currentPath: currentPath,
      currentPathIsDot: currentPathIsDot,
      isDrawing: isDrawing,
      placeholderData: placeholderData,
      buttonsConfig: buttonsConfig,
      onCommitStroke: onCommitStroke,
      trailingHeader: { EmptyView() }
    )
  }
}

// MARK: - Previews

#Preview("Empty Canvas - No Buttons") {
  StatefulPreviewWrapperForSharedCanvas(
    paths: [Path](),
    pathMetadata: [PathMetadata](),
    currentPath: Path(),
    currentPathIsDot: false,
    isDrawing: false
  ) { paths, pathMetadata, currentPath, currentPathIsDot, isDrawing in
    SharedCanvasView(
      paths: paths,
      pathMetadata: pathMetadata,
      currentPath: currentPath,
      currentPathIsDot: currentPathIsDot,
      isDrawing: isDrawing,
      onCommitStroke: {}
    )
    .padding()
    .background(Color(uiColor: .systemBackground))
  }
}

#Preview("With Content - Clear Button Only") {
  let samplePaths = createSamplePaths()

  StatefulPreviewWrapperForSharedCanvas(
    paths: samplePaths.0,
    pathMetadata: samplePaths.1,
    currentPath: Path(),
    currentPathIsDot: false,
    isDrawing: false
  ) { paths, pathMetadata, currentPath, currentPathIsDot, isDrawing in
    SharedCanvasView(
      paths: paths,
      pathMetadata: pathMetadata,
      currentPath: currentPath,
      currentPathIsDot: currentPathIsDot,
      isDrawing: isDrawing,
      buttonsConfig: CanvasButtonsConfig(
        onClear: {
          paths.wrappedValue.removeAll()
          pathMetadata.wrappedValue.removeAll()
        },
        canClear: !paths.wrappedValue.isEmpty
      ),
      onCommitStroke: {}
    )
    .padding()
    .background(Color(uiColor: .systemBackground))
  }
}

#Preview("With Undo/Redo Buttons") {
  let samplePaths = createSamplePaths()

  StatefulPreviewWrapperWithUndo(
    paths: samplePaths.0,
    pathMetadata: samplePaths.1
  ) { paths, pathMetadata, currentPath, currentPathIsDot, isDrawing, undoStack, redoStack in
    SharedCanvasView(
      paths: paths,
      pathMetadata: pathMetadata,
      currentPath: currentPath,
      currentPathIsDot: currentPathIsDot,
      isDrawing: isDrawing,
      buttonsConfig: CanvasButtonsConfig(
        onClear: {
          paths.wrappedValue.removeAll()
          pathMetadata.wrappedValue.removeAll()
        },
        onUndo: {
          guard !undoStack.wrappedValue.isEmpty else { return }
          redoStack.wrappedValue.append((paths.wrappedValue, pathMetadata.wrappedValue))
          let (previousPaths, previousMetadata) = undoStack.wrappedValue.removeLast()
          paths.wrappedValue = previousPaths
          pathMetadata.wrappedValue = previousMetadata
        },
        onRedo: {
          guard !redoStack.wrappedValue.isEmpty else { return }
          undoStack.wrappedValue.append((paths.wrappedValue, pathMetadata.wrappedValue))
          let (redoPaths, redoMetadata) = redoStack.wrappedValue.removeLast()
          paths.wrappedValue = redoPaths
          pathMetadata.wrappedValue = redoMetadata
        },
        canClear: !paths.wrappedValue.isEmpty,
        canUndo: !undoStack.wrappedValue.isEmpty,
        canRedo: !redoStack.wrappedValue.isEmpty
      ),
      onCommitStroke: {}
    )
    .padding()
    .background(Color(uiColor: .systemBackground))
  }
}

#Preview("With Undo/Redo Buttons and Save Button") {
  let samplePaths = createSamplePaths()

  StatefulPreviewWrapperWithUndo(
    paths: samplePaths.0,
    pathMetadata: samplePaths.1
  ) { paths, pathMetadata, currentPath, currentPathIsDot, isDrawing, undoStack, redoStack in
    SharedCanvasView(
      paths: paths,
      pathMetadata: pathMetadata,
      currentPath: currentPath,
      currentPathIsDot: currentPathIsDot,
      isDrawing: isDrawing,
      buttonsConfig: CanvasButtonsConfig(
        onClear: {
          paths.wrappedValue.removeAll()
          pathMetadata.wrappedValue.removeAll()
        },
        onUndo: {
          guard !undoStack.wrappedValue.isEmpty else { return }
          redoStack.wrappedValue.append((paths.wrappedValue, pathMetadata.wrappedValue))
          let (previousPaths, previousMetadata) = undoStack.wrappedValue.removeLast()
          paths.wrappedValue = previousPaths
          pathMetadata.wrappedValue = previousMetadata
        },
        onRedo: {
          guard !redoStack.wrappedValue.isEmpty else { return }
          undoStack.wrappedValue.append((paths.wrappedValue, pathMetadata.wrappedValue))
          let (redoPaths, redoMetadata) = redoStack.wrappedValue.removeLast()
          paths.wrappedValue = redoPaths
          pathMetadata.wrappedValue = redoMetadata
        },
        canClear: !paths.wrappedValue.isEmpty,
        canUndo: !undoStack.wrappedValue.isEmpty,
        canRedo: !redoStack.wrappedValue.isEmpty
      ),
      onCommitStroke: {}
    ) {
      // Save button
      Button(action: {}) {
        Image(systemName: "checkmark")
      }
      .circularGlassButton()
    }
    .padding()
    .background(Color(uiColor: .systemBackground))
  }
}

#Preview("With Placeholder") {
  let placeholder = createPlaceholderData()

  StatefulPreviewWrapperForSharedCanvas(
    paths: [Path](),
    pathMetadata: [PathMetadata](),
    currentPath: Path(),
    currentPathIsDot: false,
    isDrawing: false
  ) { paths, pathMetadata, currentPath, currentPathIsDot, isDrawing in
    SharedCanvasView(
      paths: paths,
      pathMetadata: pathMetadata,
      currentPath: currentPath,
      currentPathIsDot: currentPathIsDot,
      isDrawing: isDrawing,
      placeholderData: placeholder,
      buttonsConfig: CanvasButtonsConfig(
        onClear: {
          paths.wrappedValue.removeAll()
          pathMetadata.wrappedValue.removeAll()
        },
        canClear: !paths.wrappedValue.isEmpty
      ),
      onCommitStroke: {}
    )
    .padding()
    .background(Color(uiColor: .systemBackground))
  }
}

// MARK: - Preview Helpers

private func createSamplePaths() -> ([Path], [PathMetadata]) {
  var paths: [Path] = []
  var metadata: [PathMetadata] = []

  // Create a simple line path
  var path1 = Path()
  path1.move(to: CGPoint(x: 50, y: 50))
  path1.addLine(to: CGPoint(x: 150, y: 100))
  path1.addLine(to: CGPoint(x: 100, y: 150))
  paths.append(path1)
  metadata.append(PathMetadata(isDot: false))

  // Create a dot path
  var path2 = Path()
  let dotRadius = DRAWING_LINE_WIDTH / 2
  path2.addEllipse(
    in: CGRect(
      x: 200 - dotRadius,
      y: 80 - dotRadius,
      width: dotRadius * 2,
      height: dotRadius * 2
    ))
  paths.append(path2)
  metadata.append(PathMetadata(isDot: true))

  // Create another line path
  var path3 = Path()
  path3.move(to: CGPoint(x: 180, y: 180))
  path3.addLine(to: CGPoint(x: 220, y: 200))
  paths.append(path3)
  metadata.append(PathMetadata(isDot: false))

  return (paths, metadata)
}

private func createPlaceholderData() -> Data? {
  let samplePaths: [PathData] = [
    PathData(
      points: [
        CGPoint(x: 100, y: 100),
        CGPoint(x: 200, y: 150),
        CGPoint(x: 150, y: 200)
      ],
      isDot: false
    ),
    PathData(
      points: [CGPoint(x: 250, y: 120)],
      isDot: true
    )
  ]
  return try? JSONEncoder().encode(samplePaths)
}

// MARK: - Preview Wrapper Utilities
private struct StatefulPreviewWrapperForSharedCanvas<Content: View>: View {
  @State private var paths: [Path]
  @State private var pathMetadata: [PathMetadata]
  @State private var currentPath: Path
  @State private var currentPathIsDot: Bool
  @State private var isDrawing: Bool

  let content: (
    Binding<[Path]>,
    Binding<[PathMetadata]>,
    Binding<Path>,
    Binding<Bool>,
    Binding<Bool>
  ) -> Content

  init(
    paths: [Path],
    pathMetadata: [PathMetadata],
    currentPath: Path,
    currentPathIsDot: Bool,
    isDrawing: Bool,
    @ViewBuilder content: @escaping (
      Binding<[Path]>,
      Binding<[PathMetadata]>,
      Binding<Path>,
      Binding<Bool>,
      Binding<Bool>
    ) -> Content
  ) {
    _paths = State(wrappedValue: paths)
    _pathMetadata = State(wrappedValue: pathMetadata)
    _currentPath = State(wrappedValue: currentPath)
    _currentPathIsDot = State(wrappedValue: currentPathIsDot)
    _isDrawing = State(wrappedValue: isDrawing)
    self.content = content
  }

  var body: some View {
    content($paths, $pathMetadata, $currentPath, $currentPathIsDot, $isDrawing)
  }
}

private struct StatefulPreviewWrapperWithUndo<Content: View>: View {
  @State private var paths: [Path]
  @State private var pathMetadata: [PathMetadata]
  @State private var currentPath: Path = Path()
  @State private var currentPathIsDot: Bool = false
  @State private var isDrawing: Bool = false
  @State private var undoStack: [([Path], [PathMetadata])] = []
  @State private var redoStack: [([Path], [PathMetadata])] = []

  let content: (
    Binding<[Path]>,
    Binding<[PathMetadata]>,
    Binding<Path>,
    Binding<Bool>,
    Binding<Bool>,
    Binding<[([Path], [PathMetadata])]>,
    Binding<[([Path], [PathMetadata])]>
  ) -> Content

  init(
    paths: [Path],
    pathMetadata: [PathMetadata],
    @ViewBuilder content: @escaping (
      Binding<[Path]>,
      Binding<[PathMetadata]>,
      Binding<Path>,
      Binding<Bool>,
      Binding<Bool>,
      Binding<[([Path], [PathMetadata])]>,
      Binding<[([Path], [PathMetadata])]>
    ) -> Content
  ) {
    _paths = State(wrappedValue: paths)
    _pathMetadata = State(wrappedValue: pathMetadata)
    // Initialize with one item in undo stack for demo
    _undoStack = State(wrappedValue: [(paths, pathMetadata)])
    self.content = content
  }

  var body: some View {
    content($paths, $pathMetadata, $currentPath, $currentPathIsDot, $isDrawing, $undoStack, $redoStack)
  }
}
