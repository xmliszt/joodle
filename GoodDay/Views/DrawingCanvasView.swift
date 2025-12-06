//
//  DrawingCanvasView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

// MARK: - Drawing Canvas View with Thumbnail Generation

struct DrawingCanvasView: View {
  @Environment(\.modelContext) private var modelContext

  let date: Date
  let entry: DayEntry?
  let onDismiss: () -> Void
  /// We need this external state as DrawingCanvasView is rendered when an entry is selected
  /// But that doesn't make it visible yet as controlled by DynamicIslandExpandedView
  let isShowing: Bool

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
        }
        .circularGlassButton(tintColor: .red)
        .disabled(paths.isEmpty && currentPath.isEmpty)
        .opacity(paths.isEmpty && currentPath.isEmpty ? 0.5 : 1.0)

        Spacer()

        // Undo/Redo buttons
        HStack(spacing: 8) {
          // Undo button
          Button(action: undoLastStroke) {
            Image(systemName: "arrow.uturn.backward")
          }
          .circularGlassButton()
          .disabled(undoStack.isEmpty)
          .opacity(undoStack.isEmpty ? 0.3 : 1.0)

          // Redo button
          Button(action: redoLastStroke) {
            Image(systemName: "arrow.uturn.forward")
          }
          .circularGlassButton()
          .disabled(redoStack.isEmpty)
          .opacity(redoStack.isEmpty ? 0.3 : 1.0)
        }

        Spacer()

        // Save button
        Button(action: saveDrawing) {
          Image(systemName: "checkmark")
        }
        .circularGlassButton()
      }

      // Drawing canvas
      VStack(spacing: 12) {
        SharedCanvasView(
          paths: $paths,
          pathMetadata: $pathMetadata,
          currentPath: $currentPath,
          currentPathIsDot: $currentPathIsDot,
          isDrawing: $isDrawing,
          onCommitStroke: commitCurrentStroke
        )
      }
    }
    .padding(20)
    .background(.backgroundColor)
    .onAppear {
      loadExistingDrawing()
    }
    .onChange(
      of: isShowing,
      { oldValue, newValue in
        loadExistingDrawing()
      }
    )
    .confirmationDialog("Clear Drawing", isPresented: $showClearConfirmation) {
      Button("Clear", role: .destructive, action: clearDrawing).circularGlassButton()
      Button("Cancel", role: .cancel, action: {})
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
      // Clear drawing
      paths.removeAll()
      pathMetadata.removeAll()
      currentPath = Path()
      isDrawing = false
      currentPathIsDot = false

      // Clear redo stack when new action is performed
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
    // Derive entry to save, if not exists, create a new entry.
    let entryToSave: DayEntry = {
      if let entry { return entry }
      // Create new entry
      let newEntry = DayEntry(body: "", createdAt: date, drawingData: nil)
      modelContext.insert(newEntry)
      return newEntry
    }()

    // Update existing entry
    if paths.isEmpty {
      // No paths means no drawing data
      entryToSave.drawingData = nil
      entryToSave.drawingThumbnail20 = nil
      entryToSave.drawingThumbnail200 = nil
      entryToSave.drawingThumbnail1080 = nil
    } else {
      // Convert paths to serializable data
      let pathsData = paths.enumerated().map { (index, path) in
        let isDot = index < pathMetadata.count ? pathMetadata[index].isDot : false
        return PathData(points: path.extractPoints(), isDot: isDot)
      }

      do {
        let data = try JSONEncoder().encode(pathsData)
        entryToSave.drawingData = data

        // Generate thumbnails asynchronously
        Task {
          let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(from: data)

          await MainActor.run {
            entryToSave.drawingThumbnail20 = thumbnails.0
            entryToSave.drawingThumbnail200 = thumbnails.1
            entryToSave.drawingThumbnail1080 = thumbnails.2

            // Save again with thumbnails
            try? modelContext.save()
          }
        }
      } catch {
        print("Failed to save drawing data: \(error)")
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
      existingEntry.drawingThumbnail20 = nil
      existingEntry.drawingThumbnail200 = nil
      existingEntry.drawingThumbnail1080 = nil
      try? modelContext.save()
    }
  }

}

#Preview {
  DrawingCanvasView(
    date: Date(),
    entry: DayEntry(body: "HELLO", createdAt: Date(), drawingData: nil),
    onDismiss: {},
    isShowing: true
  )
}
