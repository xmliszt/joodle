//
//  DrawingCanvasView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

// MARK: - Joodle Access State

enum JoodleAccessState {
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

  /// Optional mock store for tutorial mode - when provided, uses mock data instead of real database
  var mockStore: MockDataStore?

  /// Optional mock entry for tutorial mode - used when mockStore is provided
  var mockEntry: MockDayEntry?

  @State private var currentPath = Path()
  @State private var paths: [Path] = []
  @State private var pathMetadata: [PathMetadata] = []
  @State private var currentPathIsDot = false
  @State private var showClearConfirmation = false
  @State private var isDrawing = false
  @State private var showPaywall = false
  @State private var accessState: JoodleAccessState = .canCreate

  // Undo/Redo state management
  @State private var undoStack: [([Path], [PathMetadata])] = []
  @State private var redoStack: [([Path], [PathMetadata])] = []

  /// Whether we're in mock/tutorial mode
  private var isMockMode: Bool {
    mockStore != nil
  }

  /// Whether editing is allowed based on subscription status
  private var canEditOrCreate: Bool {
    // Always allow in mock mode
    if isMockMode { return true }

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
      }
      .padding(20)
      .background(.backgroundColor)
      .overlay {
        // Show lock overlay when access is denied (not in mock mode)
        if !isMockMode && !canEditOrCreate {
          accessDeniedOverlay
        }
      }
    }
    .onAppear {
      if !isMockMode {
        checkAccessState()
      }
      loadExistingDrawing()
    }
    .onChange(of: isShowing) { oldValue, newValue in
      if !isMockMode {
        checkAccessState()
      }
      loadExistingDrawing()
    }
    .onChange(of: subscriptionManager.isSubscribed) { _, _ in
      // Re-check access when subscription changes (not in mock mode)
      if !isMockMode {
        checkAccessState()
      }
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
  private var accessDeniedOverlay: some View {
    VStack(spacing: 16) {
      Image(systemName: "lock.fill")
        .font(.system(size: 40))
        .foregroundColor(.appTextPrimary)

      switch accessState {
      case .limitReached:
        Text("You've reached your free Joodle limit")
          .font(.headline)
          .foregroundColor(.appTextPrimary)
          .multilineTextAlignment(.center)

        Text("Upgrade to Joodle Pro for unlimited Joodles")
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
        .foregroundColor(.appAccentContrast)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.appAccent)
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
    // Perform async verification with online check
    Task {
      // Check if this is an existing Joodle (editing) or new Joodle (creating)
      let hasExistingDrawing = entry?.drawingData != nil

      if hasExistingDrawing, let entry = entry {
        // Editing existing - verify access with online check
        let canEdit = await subscriptionManager.canEditJoodleWithVerification(entry: entry, in: modelContext)

        await MainActor.run {
          if canEdit {
            accessState = .canEdit
          } else {
            // Calculate index for error message
            let targetDateString = entry.dateString
            let descriptor = FetchDescriptor<DayEntry>(
              predicate: #Predicate<DayEntry> {
                $0.drawingData != nil && $0.dateString < targetDateString
              }
            )
            let index = (try? modelContext.fetchCount(descriptor)) ?? 0
            accessState = .editingLocked(
              reason:
                "Free account can only edit the first \(SubscriptionManager.freeJoodlesAllowed) Joodles. This Joodle is #\(index + 1)."
            )
          }
        }
      } else {
        // Creating new - verify access with online check
        let canCreate = await subscriptionManager.checkAccessWithVerification(in: modelContext)

        await MainActor.run {
          if canCreate {
            accessState = .canCreate
          } else {
            accessState = .limitReached
          }
        }
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

    // Save immediately to store (skip in mock mode - we'll save on dismiss)
    if !isMockMode {
      saveDrawingToStore()
    }

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

    // Save to store (skip in mock mode)
    if !isMockMode {
      saveDrawingToStore()
    }

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

    // Save to store (skip in mock mode)
    if !isMockMode {
      saveDrawingToStore()
    }
  }

  private func loadExistingDrawing() {
    // Check mock mode first
    if isMockMode {
      loadMockDrawing()
      return
    }

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

    loadPathsFromData(data)
  }

  private func loadMockDrawing() {
    guard let mockEntry = mockEntry, let data = mockEntry.drawingData else {
      // Initialize with empty state for new drawings
      undoStack.removeAll()
      redoStack.removeAll()
      paths.removeAll()
      pathMetadata.removeAll()
      currentPath = Path()
      isDrawing = false
      currentPathIsDot = false
      redoStack.removeAll()
      return
    }

    loadPathsFromData(data)
  }

  private func loadPathsFromData(_ data: Data) {
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
    if isMockMode {
      saveMockDrawing()
    } else {
      saveDrawingToStore()
    }
    onDismiss()
  }

  private func saveMockDrawing() {
    guard let mockStore = mockStore else { return }

    // Convert paths to data
    if paths.isEmpty {
      // Clear drawing from mock entry
      if let selectedDate = mockStore.selectedDateItem?.date {
        if var existingEntry = mockStore.getEntry(for: selectedDate) {
          existingEntry.drawingData = nil
          mockStore.updateEntry(existingEntry)
        }
      }
      return
    }

    let pathsData = paths.enumerated().map { (index, path) in
      let isDot = index < pathMetadata.count ? pathMetadata[index].isDot : false
      return PathData(points: path.extractPoints(), isDot: isDot)
    }

    do {
      let data = try JSONEncoder().encode(pathsData)

      if let selectedDate = mockStore.selectedDateItem?.date {
        if var existingEntry = mockStore.getEntry(for: selectedDate) {
          existingEntry.drawingData = data
          mockStore.updateEntry(existingEntry)
        } else {
          let newEntry = MockDayEntry(date: selectedDate, body: "", drawingData: data)
          mockStore.addEntry(newEntry)
        }
      }
    } catch {
      print("Failed to save mock drawing: \(error)")
    }
  }

  private func saveDrawingToStore() {
    // If no paths and no existing entry, don't create an empty entry
    if paths.isEmpty && entry == nil {
      return
    }

    // If we have an existing entry but paths is empty, clear the drawing data
    // If entry becomes empty (no text either), delete it entirely
    if paths.isEmpty {
      if let existingEntry = entry {
        existingEntry.drawingData = nil
        existingEntry.drawingThumbnail20 = nil
        existingEntry.drawingThumbnail200 = nil

        // If entry is now empty (no text either), delete it
        if existingEntry.body.isEmpty {
          existingEntry.deleteAllForSameDate(in: modelContext)
        } else {
          try? modelContext.save()
        }

        // Refresh daily reminder - drawing was cleared, so we may need to reschedule notification
        if CalendarDate.from(date).isToday {
          ReminderManager.shared.refreshDailyReminderIfNeeded()
        }
      }
      return
    }

    // We have paths to save - use findOrCreate to get the single entry for this date
    let entryToSave: DayEntry = entry ?? DayEntry.findOrCreate(for: date, in: modelContext)

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

    try? modelContext.save()

    // If this is today's entry, refresh the daily reminder
    // (cancels pending notification since user already drew today)
    if CalendarDate.from(date).isToday {
      ReminderManager.shared.refreshDailyReminderIfNeeded()
    }
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

    // Also clear from store (skip in mock mode)
    if !isMockMode {
      if let existingEntry = entry {
        existingEntry.drawingData = nil
        existingEntry.drawingThumbnail20 = nil
        existingEntry.drawingThumbnail200 = nil

        // If entry is now empty (no text either), delete it entirely
        if existingEntry.body.isEmpty {
          existingEntry.deleteAllForSameDate(in: modelContext)
        } else {
          try? modelContext.save()
        }

        // Refresh daily reminder - drawing was cleared, so we may need to reschedule notification
        if CalendarDate.from(date).isToday {
          ReminderManager.shared.refreshDailyReminderIfNeeded()
        }
      }
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

#Preview("Mock Mode - Tutorial") {
  struct MockPreview: View {
    @StateObject private var mockStore = MockDataStore()

    var body: some View {
      DrawingCanvasView(
        date: Date(),
        entry: nil,
        onDismiss: {},
        isShowing: true,
        mockStore: mockStore,
        mockEntry: nil
      )
    }
  }
  return MockPreview()
}
