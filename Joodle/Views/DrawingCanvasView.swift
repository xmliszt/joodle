//
//  DrawingCanvasView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

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
  @Environment(\.scenePhase) private var scenePhase
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

  /// Task for async thumbnail generation on dismiss
  @State private var thumbnailTask: Task<Void, Never>?

  /// Short-lived background task used when persisting drawing data during app backgrounding.
  @State private var backgroundSaveTaskId: UIBackgroundTaskIdentifier = .invalid

  /// Tracks whether the drawing was already persisted during this dismiss cycle.
  /// Prevents `.onDisappear` from double-saving after `onChange(of: isShowing)` or `saveDrawing()` already saved.
  @State private var didSaveOnDismiss = false

  /// Whether `loadExistingDrawing()` has run for the current session.
  /// Guards save operations so a hidden canvas that was never loaded
  /// (e.g. DI device entry-switch) cannot overwrite another entry's doodle data.
  @State private var drawingStateLoaded = false

  // Inspiration prompt state
  @State private var currentPrompt: String? = nil
  @State private var promptID = UUID()
  @State private var isIlluminated = false

  // Camera reference state — shared with ContentView via environment object.
  // Optional (absent in tutorial/mock mode) so the feature is fully disabled there.
  @EnvironmentObject private var cameraContext: CameraReferenceContext

  /// Album picker selection — selected item is consumed asynchronously to load
  /// the image data, then center-cropped and installed as the camera backdrop.
  @State private var albumPickerItem: PhotosPickerItem?

  /// Whether we're in mock/tutorial mode
  private var isMockMode: Bool {
    mockStore != nil
  }

  // MARK: - Concentric Corner Radius

  /// Canvas corner radius computed to be concentric with the floating
  /// `DynamicIslandExpandedView` container border (used on every device).
  /// Container clip = `screenCornerRadius - containerInset`, with an 8pt
  /// inner padding inside the container.
  private var canvasCornerRadius: CGFloat {
    let containerInset: CGFloat = UIDevice.hasDynamicIsland
      ? UIDevice.dynamicIslandFrame.origin.y
      : 10
    let diContainerPadding: CGFloat = 8
    return max(
      UIDevice.screenCornerRadius - containerInset - diContainerPadding,
      0
    )
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

  /// Whether the camera reference button (top-left) should be visible.
  /// Mirrors the bulb button visibility logic — hidden once any stroke exists
  /// and hidden while the camera live mode is active (the top row is empty
  /// except for the flip-camera button at the center).
  private var canShowCameraButton: Bool {
    !isMockMode && paths.isEmpty && currentPath.isEmpty && !isCameraLive
  }

  private var isCameraLive: Bool {
    !isMockMode && cameraContext.mode == .live
  }

  var body: some View {
    ZStack(alignment: .top) {
      VStack(spacing: 12) {
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
            showClearConfirmation: $showClearConfirmation,
            centerContent: isCameraLive
              ? AnyView(cameraFlipButton)
              : (isMockMode ? nil : AnyView(inspirationBulbButton)),
            leadingExtra: {
              if isCameraLive { return AnyView(exitCameraButton) }
              if canShowCameraButton { return AnyView(cameraReferenceButton) }
              return nil
            }(),
            trailingExtra: isCameraLive ? AnyView(albumPickerButton) : nil,
            hideStrokeButtons: isCameraLive
          ),
          canvasCornerRadius: canvasCornerRadius,
          backdropImage: isMockMode ? nil : cameraContext.backdropImage,
          liveCameraSession: isMockMode ? nil : cameraContext.session,
          liveCameraDevice: isMockMode ? nil : cameraContext.currentDevice,
          isCameraLive: isCameraLive,
          liveCameraMirrored: !isMockMode && cameraContext.isFrontFacing,
          shutterController: isMockMode ? nil : cameraContext.shutter,
          isShutterFullyClosed: !isMockMode && cameraContext.isShutterFullyClosed,
          isShutterCycling: !isMockMode && cameraContext.isShutterCycling,
          suppressLivePreview: !isMockMode && cameraContext.suppressPreview,
          captureFlashID: isMockMode ? nil : cameraContext.captureFlashID,
          onCommitStroke: commitCurrentStroke
        ) {
          // Save button
          Button(action: saveDrawing) {
            Image(systemName: "checkmark")
          }
          .circularGlassButton()
        }
        .disabled(!canEditOrCreate)
        .background(Color.clear)
        .overlay {
          // Show lock overlay when access is denied (not in mock mode)
          if !isMockMode && !canEditOrCreate {
            accessDeniedOverlay
          }
        }
        .fixedSize(horizontal: false, vertical: true)
        
        // Inspiration prompt text — centered, below the canvas (hidden in tutorial mode)
        if !isMockMode, let prompt = currentPrompt, !isCameraLive {
          InspirationPromptView(prompt: prompt)
            .id(promptID)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }

      }
      .animation(.springFkingSatifying, value: currentPrompt == nil)
      .animation(.springFkingSatifying, value: promptID)
      // Non-overshooting curve for camera-mode transitions to prevent the DI
      // container momentarily exceeding its final height (which would briefly
      // reveal the white surface behind it).
      .animation(.easeInOut(duration: 0.2), value: isCameraLive)
    }
    .padding(8)
    .padding(.top, 16)
    .padding(.bottom, 10)
    // Keep any transient reveal during the camera-mode layout transition dark
    // instead of letting the underlying white surface show through.
    .background(Color.black)
    .onDisappear {
      // Safety net for cases where SwiftUI tears the view down (e.g. selection
      // cleared while canvas is still showing) without propagating the
      // isShowing binding change, so onChange(of: isShowing) never fires.
      guard !didSaveOnDismiss else { return }
      if isMockMode {
        saveMockDrawing()
      } else {
        saveDrawingToStore()
        // Mirror the teardown that onChange(of: isShowing) would have done,
        // otherwise the camera session / LED can stay alive after the
        // floating container is removed.
        cameraContext.reset()
      }
    }
    .onAppear {
      // Only load drawing data when the canvas is already visible on appear.
      // On Dynamic Island devices, DrawingCanvasView lives in the hierarchy
      // whenever a date is selected (hidden via isShowing=false). Eagerly loading
      // paths here would leave stale data in @State that survives entry deletion
      // and gets re-saved on scenePhase→.background, resurrecting deleted entries.
      // The onChange(of: isShowing) handler covers loading when canvas becomes visible.
      guard isShowing else { return }
      didSaveOnDismiss = false
      if !isMockMode {
        checkAccessState()
      }
      loadExistingDrawing()
    }
    .onChange(of: isShowing) { oldValue, newValue in
      if newValue {
        // Canvas becoming visible — load data and check access
        didSaveOnDismiss = false
        if !isMockMode {
          checkAccessState()
        }
        loadExistingDrawing()
      } else {
        // Canvas being dismissed — persist drawing before state is torn down.
        // This covers DynamicIsland tap-outside and any isShowing-driven dismiss.
        if isMockMode {
          saveMockDrawing()
        } else {
          saveDrawingToStore()
        }
        didSaveOnDismiss = true

        // Clear in-memory drawing state after saving. Without this, stale paths
        // linger while the canvas is hidden — if the entry is then deleted via
        // EntryEditingView and the app backgrounds, the scenePhase handler would
        // see non-empty paths and call saveDrawingToStore(), which re-creates
        // the deleted entry via findOrCreate.
        paths.removeAll()
        pathMetadata.removeAll()
        currentPath = Path()
        isDrawing = false
        currentPathIsDot = false
        undoStack.removeAll()
        redoStack.removeAll()
        drawingStateLoaded = false

        // Tear down camera state so the LED turns off and the transient
        // tracing photo doesn't leak into the next entry.
        if !isMockMode {
          cameraContext.reset()
        }
      }
    }
    .onChange(of: subscriptionManager.hasPremiumAccess) { _, _ in
      // Re-check access when subscription changes (not in mock mode)
      if !isMockMode {
        checkAccessState()
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      // Safety net: persist drawing if the app backgrounds mid-session.
      // Guard by isShowing so a hidden canvas (DI devices) doesn't accidentally
      // re-save stale paths for an entry that was deleted in EntryEditingView.
      if newPhase == .background, !isMockMode, isShowing {
        beginBackgroundSaveTaskIfNeeded()
        saveDrawingToStore(generateThumbnails: false, scheduleWidgetSync: false)
        endBackgroundSaveTaskIfNeeded()
      }
    }
    .confirmationDialog("Clear Drawing", isPresented: $showClearConfirmation) {
      Button("Clear", role: .destructive, action: clearDrawing).circularGlassButton()
      Button("Cancel", role: .cancel, action: {})
    } message: {
      Text("Clear all drawing?")
    }
    .sheet(isPresented: $showPaywall) {
      StandalonePaywallView(source: "entry_limit")
    }
    .alert("Camera Access Needed", isPresented: cameraPermissionAlertBinding) {
      Button("Cancel", role: .cancel) {}
      Button("Open Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
    } message: {
      Text("Joodle needs camera access to capture reference photos for tracing. Enable it in Settings.")
    }
    .onChange(of: scenePhase) { _, newPhase in
      guard !isMockMode, cameraContext.mode == .live else { return }
      switch newPhase {
      case .inactive:
        // iOS snapshots the UI during the `.inactive` transition for the app
        // switcher / home-peek. If the AVCaptureVideoPreviewLayer is captured
        // mid-frame, return-to-foreground takes a long time to reconcile and
        // the screen appears frozen. Unmount the preview here so the snapshot
        // captures a plain black canvas instead — cheap to restore.
        cameraContext.suppressPreview = true
      case .active:
        // Returning from peek / app-switcher: re-mount the live preview.
        cameraContext.suppressPreview = false
      case .background:
        // Real background transition: tear the camera all the way down.
        cameraContext.reset()
      @unknown default:
        break
      }
    }
    .onChange(of: albumPickerItem) { _, newItem in
      guard let newItem else { return }
      Task {
        if let data = try? await newItem.loadTransferable(type: Data.self),
           let raw = UIImage(data: data) {
          let cropped = centerCroppedSquare(raw)
          await MainActor.run {
            cameraContext.backdropImage = cropped
            cameraContext.cancelLive()
          }
        }
        await MainActor.run { albumPickerItem = nil }
      }
    }
    .preferredColorScheme(.dark)
    .postHogScreenView("Drawing Canvas")
  }

  // MARK: - Access Control UI
  private var accessDeniedOverlay: some View {
    VStack(spacing: 16) {
      Image(systemName: "lock.fill")
        .font(.appFont(size: 40))
        .foregroundColor(.appTextPrimary)

      switch accessState {
      case .limitReached:
        Text("You've reached your free Joodle limit")
          .font(.appHeadline())
          .foregroundColor(.appTextPrimary)
          .multilineTextAlignment(.center)

        Text("Upgrade to Joodle Pro for unlimited Joodles")
          .font(.appSubheadline())
          .foregroundColor(.appTextPrimary.opacity(0.8))
          .multilineTextAlignment(.center)

      case .editingLocked(let reason):
        Text("Editing Locked")
          .font(.appHeadline())
          .foregroundColor(.appTextPrimary)

        Text(reason)
          .font(.appSubheadline())
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
        .font(.appHeadline())
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
    .clipShape(RoundedRectangle(cornerRadius: canvasCornerRadius, style: .continuous))
  }

  // MARK: - Camera Reference

  /// Render the picked image upright, then center-crop to a square so the
  /// backdrop matches the canvas aspect.
  private func centerCroppedSquare(_ image: UIImage) -> UIImage {
    let upright: UIImage = {
      if image.imageOrientation == .up { return image }
      let format = UIGraphicsImageRendererFormat()
      format.scale = image.scale
      format.opaque = true
      let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
      return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: image.size))
      }
    }()
    let s = min(upright.size.width, upright.size.height)
    let format = UIGraphicsImageRendererFormat()
    format.scale = upright.scale
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: format)
    return renderer.image { _ in
      let xOff = (upright.size.width - s) / 2
      let yOff = (upright.size.height - s) / 2
      upright.draw(at: CGPoint(x: -xOff, y: -yOff))
    }
  }


  private var cameraPermissionAlertBinding: Binding<Bool> {
    Binding(
      get: { !isMockMode && cameraContext.showPermissionDeniedAlert },
      set: { newValue in
        if !isMockMode {
          cameraContext.showPermissionDeniedAlert = newValue
        }
      }
    )
  }

  /// Camera-affecting buttons are locked out for the entire shutter cycle so a
  /// second action can't fire while the first one is still animating.
  private var isShutterCycling: Bool {
    !isMockMode && cameraContext.isShutterCycling
  }

  private var cameraReferenceButton: some View {
    Button {
      Haptic.play(with: .light)
      Task { await cameraContext.enterLive() }
    } label: {
      Image(systemName: "camera.fill")
    }
    .circularGlassButton()
    .disabled(isShutterCycling)
  }

  /// Top-right button in camera live mode — opens the system photo picker so
  /// the user can import a photo from their album as the tracing backdrop.
  private var albumPickerButton: some View {
    PhotosPicker(selection: $albumPickerItem, matching: .images, photoLibrary: .shared()) {
      Image(systemName: "photo.on.rectangle")
    }
    .circularGlassButton()
    .disabled(isShutterCycling)
  }

  /// Top-left button in camera live mode — exits the camera back to the
  /// drawing canvas without capturing.
  private var exitCameraButton: some View {
    Button {
      Haptic.play(with: .light)
      cameraContext.cancelLive()
    } label: {
      Image(systemName: "scribble.variable")
    }
    .circularGlassButton()
    .disabled(isShutterCycling)
  }

  private var cameraFlipButton: some View {
    Button {
      Haptic.play(with: .light)
      cameraContext.flip()
    } label: {
      Image(systemName: "arrow.triangle.2.circlepath.camera")
    }
    .circularGlassButton()
    .disabled(isShutterCycling)
  }

  // MARK: - Inspiration Bulb Button

  private var inspirationBulbButton: some View {
    Button(action: rollInspirationPrompt) {
      Image(systemName: "lightbulb.max.fill")
    }
    .circularGlassButton()
    .overlay {
      if isIlluminated {
        TorchlightGlowView()
          .transition(.opacity)
          .allowsHitTesting(false)
      }
    }
    .animation(.easeIn(duration: 0.15), value: isIlluminated)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          // Fires immediately on first finger contact
          guard !isIlluminated else { return }
          isIlluminated = true
        }
        .onEnded { _ in
          // Fires when finger lifts — hold for a moment then fade out
          DispatchQueue.main.async {
            withAnimation(.easeIn(duration: 0.25)) {
              isIlluminated = false
            }
          }
        }
    )
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
                String(localized: "Free account can only edit the first \(SubscriptionManager.freeJoodlesAllowed) Joodles. This Joodle is #\(index + 1).")
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

  // MARK: - Inspiration Prompt

  private func rollInspirationPrompt() {
    let candidates = PromptsManager.shared.allPrompts.filter { $0 != currentPrompt }
    guard let newPrompt = candidates.randomElement() else { return }
    
    // Add a haptic feedback
    Haptic.play(with: .light)

    // Swap prompt directly and force view recreation for fresh animation
    withAnimation(.springFkingSatifying) {
      currentPrompt = newPrompt
      promptID = UUID()
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

    // Drawing data lives in the in-memory `paths` array.
    // We only persist to SwiftData when the canvas is dismissed (saveDrawing)
    // to avoid any I/O lag during active drawing.

    // Reset drawing state
    isDrawing = false
    currentPathIsDot = false
  }

  private func saveStateToUndoStack() {
    // Save current paths and metadata state to undo stack
    undoStack.append((paths, pathMetadata))
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

  }

  private func loadExistingDrawing() {
    // Mark that we've loaded (or attempted to load) drawing state for this
    // session. This makes the canvas authoritative — save operations are
    // allowed only after this flag is set.
    drawingStateLoaded = true

    // Reset inspiration prompt for new session
    currentPrompt = nil
    isIlluminated = false

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

      // Pre-populate undo stack from stroke history so Undo is
      // immediately available when opening an existing doodle.
      // Each entry is a progressive prefix of the loaded strokes.
      undoStack = (0..<paths.count).map { i in
        (Array(paths.prefix(i)), Array(pathMetadata.prefix(i)))
      }
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
    didSaveOnDismiss = true
    onDismiss()
  }

  private func saveMockDrawing() {
    guard drawingStateLoaded else { return }
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

  private func saveDrawingToStore(generateThumbnails: Bool = true, scheduleWidgetSync: Bool = true) {
    // If the canvas was never loaded (e.g. hidden DI canvas torn down on
    // entry switch), skip saving to avoid overwriting another entry's doodle
    // with empty paths.
    guard drawingStateLoaded else { return }

    // Defense-in-depth: if the entry was deleted (e.g. via EntryEditingView)
    // but this view still holds a stale reference, bail out to avoid
    // re-inserting it through findOrCreate.
    if let entry, entry.isDeleted {
      return
    }

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

        if scheduleWidgetSync {
          WidgetHelper.shared.scheduleWidgetDataUpdate(in: modelContext)
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

      // Save drawing data synchronously so it persists immediately.
      try? modelContext.save()

      if generateThumbnails {
        // Generate thumbnails asynchronously — runs right after dismiss,
        // no artificial delay since this only fires once on canvas close.
        thumbnailTask?.cancel()
        thumbnailTask = Task {
          let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(from: data)
          guard !Task.isCancelled else { return }

          await MainActor.run {
            entryToSave.drawingThumbnail20 = thumbnails.0
            entryToSave.drawingThumbnail200 = thumbnails.1
            try? modelContext.save()
          }
        }
      } else {
        // Avoid extra writes when app is transitioning to background.
        thumbnailTask?.cancel()
      }
    } catch {
      print("Failed to save drawing data: \(error)")
    }

    if scheduleWidgetSync {
      // Schedule a debounced widget update so rapid strokes don't overload WidgetCenter
      WidgetHelper.shared.scheduleWidgetDataUpdate(in: modelContext)
    }
  }

  private func beginBackgroundSaveTaskIfNeeded() {
    guard backgroundSaveTaskId == .invalid else { return }

    backgroundSaveTaskId = UIApplication.shared.beginBackgroundTask(withName: "PersistDrawingOnBackground") {
      Task { @MainActor in
        endBackgroundSaveTaskIfNeeded()
      }
    }
  }

  private func endBackgroundSaveTaskIfNeeded() {
    guard backgroundSaveTaskId != .invalid else { return }

    UIApplication.shared.endBackgroundTask(backgroundSaveTaskId)
    backgroundSaveTaskId = .invalid
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

    // Don't persist the clear immediately — let the dismiss logic
    // (onChange(of: isShowing) / onDisappear / saveDrawing) handle saving
    // the empty-paths state to the store when the canvas is closed.
  }

}

#Preview {
  ZStack {
    Color.black
    DrawingCanvasView(
      date: Date(),
      entry: DayEntry(body: "HELLO", createdAt: Date(), drawingData: nil),
      onDismiss: {},
      isShowing: true
    )
    .environmentObject(CameraReferenceContext())
  }

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
      .environmentObject(CameraReferenceContext())
    }
  }
  return MockPreview()
}
