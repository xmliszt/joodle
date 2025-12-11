//
//  DrawingCanvasView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

// MARK: - Doodle Access State

enum DoodleAccessState {
  case canCreate
  case canEdit
  case limitReached
  case editingLocked(reason: String)
}

// MARK: - Drawing Canvas View with Thumbnail Generation

struct DrawingCanvasView: View {
  @Environment(\.modelContext) private var modelContext
  @StateObject private var subscriptionManager = SubscriptionManager.shared

  let date: Date
  let entry: DayEntry?
  let onDismiss: () -> Void
  /// We need this external state as DrawingCanvasView is rendered when an entry is selected
  /// But that doesn't make it visible yet as controlled by DynamicIslandExpandedView
  let isShowing: Bool

  /// All entries for doodle limit calculation
  let allEntries: [DayEntry]

  @State private var currentPath = Path()
  @State private var paths: [Path] = []
  @State private var pathMetadata: [PathMetadata] = []
  @State private var currentPathIsDot = false
  @State private var showClearConfirmation = false
  @State private var isDrawing = false
  @State private var showPaywall = false
  @State private var accessState: DoodleAccessState = .canCreate

  // Undo/Redo state management
  @State private var undoStack: [([Path], [PathMetadata])] = []
  @State private var redoStack: [([Path], [PathMetadata])] = []

  /// Whether editing is allowed based on subscription status
  private var canEditOrCreate: Bool {
    switch accessState {
    case .canCreate, .canEdit:
      return true
    case .limitReached, .editingLocked:
      return false
    }
  }

  var body: some View {
    ZStack {
      VStack(spacing: 16) {
        // Show remaining doodles indicator for free users
        if !subscriptionManager.isSubscribed {
          remainingDoodlesHeader
        }

        SharedCanvasView(
          paths: $paths,
          pathMetadata: $pathMetadata,
          currentPath: $currentPath,
          currentPathIsDot: $currentPathIsDot,
          isDrawing: $isDrawing,
          buttonsConfig: CanvasButtonsConfig(
            onClear: clearDrawing,
            onUndo: undoLastStroke,
            onRedo: redoLastStroke,
            canClear: !paths.isEmpty || !currentPath.isEmpty,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
            showClearConfirmation: $showClearConfirmation
          ),
          onCommitStroke: commitCurrentStroke
        ) {
          // Save button
          Button(action: saveDrawing) {
            Image(systemName: "checkmark")
          }
          .circularGlassButton()
        }
        .disabled(!canEditOrCreate)
        .overlay {
          // Show lock overlay when access is denied
          if !canEditOrCreate {
            accessDeniedOverlay
          }
        }
      }
      .padding(20)
      .background(.backgroundColor)
    }
    .onAppear {
      checkAccessState()
      loadExistingDrawing()
    }
    .onChange(of: isShowing) { oldValue, newValue in
      checkAccessState()
      loadExistingDrawing()
    }
    .onChange(of: subscriptionManager.isSubscribed) { _, _ in
      // Re-check access when subscription changes
      checkAccessState()
    }
    .confirmationDialog("Clear Drawing", isPresented: $showClearConfirmation) {
      Button("Clear", role: .destructive, action: clearDrawing).circularGlassButton()
      Button("Cancel", role: .cancel, action: {})
    } message: {
      Text("Clear all drawing?")
    }
    .sheet(isPresented: $showPaywall) {
      StandalonePaywallView()
    }
  }

  // MARK: - Access Control UI

  private var remainingDoodlesHeader: some View {
    let totalCount = subscriptionManager.totalDoodleCount(from: allEntries)
    let remaining = subscriptionManager.remainingDoodles(currentTotalCount: totalCount)

    return HStack(spacing: 6) {
      Image(systemName: remaining > 0 ? "scribble" : "lock.fill")
        .font(.caption)

      if remaining > 0 {
        Text("\(remaining) doodles left")
          .font(.caption)
      } else {
        Text("Limit reached")
          .font(.caption)
      }

      Spacer()

      Button {
        showPaywall = true
      } label: {
        Text("Upgrade")
          .font(.caption.bold())
          .foregroundStyle(.white)
      }
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
      .controlSize(.mini)
    }
    .foregroundColor(.secondary)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(.appBorder.opacity(0.2))
    .cornerRadius(24)
  }

  private var accessDeniedOverlay: some View {
    VStack(spacing: 16) {
      Image(systemName: "lock.fill")
        .font(.system(size: 40))
        .foregroundColor(.appTextPrimary)

      switch accessState {
      case .limitReached:
        Text("You've reached your free doodle limit")
          .font(.headline)
          .foregroundColor(.appTextPrimary)
          .multilineTextAlignment(.center)

        Text("Upgrade to Joodle Super for unlimited doodles")
          .font(.subheadline)
          .foregroundColor(.appTextPrimary.opacity(0.8))
          .multilineTextAlignment(.center)

      case .editingLocked(let reason):
        Text("Editing Locked")
          .font(.headline)
          .foregroundColor(.appTextPrimary)

        Text(reason)
          .font(.subheadline)
          .foregroundColor(.appTextPrimary.opacity(0.8))
          .multilineTextAlignment(.center)

      default:
        EmptyView()
      }

      Button {
        showPaywall = true
      } label: {
        HStack {
          Image(systemName: "crown.fill")
          Text("Upgrade")
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.accent)
        .cornerRadius(32)
      }
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.ultraThinMaterial.quaternary)
    .clipShape(RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius - UIDevice.dynamicIslandFrame.origin.y - 36, style: .continuous))
  }

  // MARK: - Access Check

  private func checkAccessState() {
    // If subscribed, always allow
    if subscriptionManager.isSubscribed {
      accessState = entry?.drawingData != nil ? .canEdit : .canCreate
      return
    }

    // Check if this is an existing doodle (editing) or new doodle (creating)
    let hasExistingDrawing = entry?.drawingData != nil

    if hasExistingDrawing {
      // Editing existing - check if within first N doodles
      let entriesWithDrawings = allEntries
        .filter { $0.drawingData != nil }
        .sorted { $0.dateString < $1.dateString }

      if let entry = entry,
         let index = entriesWithDrawings.firstIndex(where: { $0.id == entry.id }) {
        if subscriptionManager.canEditDoodle(atIndex: index) {
          accessState = .canEdit
        } else {
          accessState = .editingLocked(reason: "Free account can only edit the first \(SubscriptionManager.freeDoodlesAllowed) doodles. This doodle is #\(index + 1).")
        }
      } else {
        accessState = .canEdit
      }
    } else {
      // Creating new - check limit
      let totalCount = subscriptionManager.totalDoodleCount(from: allEntries)
      if subscriptionManager.canCreateDoodle(currentTotalCount: totalCount) {
        accessState = .canCreate
      } else {
        accessState = .limitReached
      }
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
      try? modelContext.save()
    }
  }

}

#Preview {
  DrawingCanvasView(
    date: Date(),
    entry: DayEntry(body: "HELLO", createdAt: Date(), drawingData: nil),
    onDismiss: {},
    isShowing: true,
    allEntries: []
  )
}
