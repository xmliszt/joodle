//
//  SharedCanvasView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import AVFoundation
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
  /// Optional view shown in the center slot when undo/redo buttons are hidden
  let centerContent: AnyView?
  /// Optional view shown overlapping the clear-button slot (top-left).
  /// Used for the camera/reference button which only appears when canClear is false.
  let leadingExtra: AnyView?
  /// Optional view shown in the trailing slot when stroke buttons are hidden
  /// (e.g. camera live mode). Replaces the normal trailing save button.
  let trailingExtra: AnyView?
  /// When true, hide clear/undo/redo entirely (camera mode)
  let hideStrokeButtons: Bool

  init(
    onClear: @escaping () -> Void,
    onUndo: (() -> Void)? = nil,
    onRedo: (() -> Void)? = nil,
    canClear: Bool = true,
    canUndo: Bool = false,
    canRedo: Bool = false,
    showClearConfirmation: Binding<Bool>? = nil,
    centerContent: AnyView? = nil,
    leadingExtra: AnyView? = nil,
    trailingExtra: AnyView? = nil,
    hideStrokeButtons: Bool = false
  ) {
    self.onClear = onClear
    self.onUndo = onUndo
    self.onRedo = onRedo
    self.canClear = canClear
    self.canUndo = canUndo
    self.canRedo = canRedo
    self.showClearConfirmation = showClearConfirmation
    self.centerContent = centerContent
    self.leadingExtra = leadingExtra
    self.trailingExtra = trailingExtra
    self.hideStrokeButtons = hideStrokeButtons
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
  var canvasCornerRadius: CGFloat = 32

  /// Optional tracing-reference image rendered as a 30% backdrop inside the canvas.
  var backdropImage: UIImage? = nil
  /// When set and `isCameraLive` is true, shows a live camera preview filling the canvas.
  var liveCameraSession: AVCaptureSession? = nil
  /// Active capture device — drives the preview's rotation coordinator so
  /// orientation tracks correctly across camera flips.
  var liveCameraDevice: AVCaptureDevice? = nil
  var isCameraLive: Bool = false
  var liveCameraMirrored: Bool = false
  /// Drives the shutter overlay and the gating of the live preview mount.
  /// `nil` in tutorial/mock mode where the camera feature is disabled.
  var shutterController: CameraShutterController? = nil
  /// Mirror of `shutterController?.isFullyClosed`, sourced from
  /// `CameraReferenceContext` so changes actually drive a re-render here.
  var isShutterFullyClosed: Bool = false
  /// True for the entire close → open shutter sequence. Drives the inner
  /// shadow so it appears the instant the shutter starts closing (well before
  /// `isCameraLive` flips, which only happens after the shutter reopens).
  var isShutterCycling: Bool = false
  /// When true, forcibly unmount the live preview even if camera mode is
  /// still active — used during a flip cycle to avoid a stale frame from the
  /// previous device showing through.
  var suppressLivePreview: Bool = false

  /// Track the maximum distance from start point during a gesture to detect dots vs strokes
  @State private var maxDistanceFromStart: CGFloat = 0
  @State private var gestureStartPoint: CGPoint = .zero

  /// Callback when a stroke is finished (finger lifted or moved out of bounds)
  var onCommitStroke: () -> Void

  /// Optional trailing content for the header row (e.g. Save button)
  var TrailingHeaderView: () -> TrailingHeader

  @State private var placeholderPaths: [(path: Path, isDot: Bool)] = []
  @State private var placeholderID = UUID()
  /// Mounted only while the shutter is fully closed over the canvas, so the
  /// live feed never appears during a transition. Latches across the open
  /// phase so the preview stays visible once the shutter has retracted.
  @State private var cameraPreviewMounted: Bool = false

  init(
    paths: Binding<[Path]>,
    pathMetadata: Binding<[PathMetadata]>,
    currentPath: Binding<Path>,
    currentPathIsDot: Binding<Bool>,
    isDrawing: Binding<Bool>,
    placeholderData: Data? = nil,
    buttonsConfig: CanvasButtonsConfig? = nil,
    canvasCornerRadius: CGFloat = 32,
    backdropImage: UIImage? = nil,
    liveCameraSession: AVCaptureSession? = nil,
    liveCameraDevice: AVCaptureDevice? = nil,
    isCameraLive: Bool = false,
    liveCameraMirrored: Bool = false,
    shutterController: CameraShutterController? = nil,
    isShutterFullyClosed: Bool = false,
    isShutterCycling: Bool = false,
    suppressLivePreview: Bool = false,
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
    self.canvasCornerRadius = canvasCornerRadius
    self.backdropImage = backdropImage
    self.liveCameraSession = liveCameraSession
    self.liveCameraDevice = liveCameraDevice
    self.isCameraLive = isCameraLive
    self.liveCameraMirrored = liveCameraMirrored
    self.shutterController = shutterController
    self.isShutterFullyClosed = isShutterFullyClosed
    self.isShutterCycling = isShutterCycling
    self.suppressLivePreview = suppressLivePreview
    self.onCommitStroke = onCommitStroke
    self.TrailingHeaderView = trailingHeader
  }

  var body: some View {
    VStack(spacing: 16) {
      // Action Buttons Row
      if let config = buttonsConfig {
        HStack() {
          // Clear button — use opacity to reserve space and prevent layout shift.
          // Hidden entirely in camera mode (hideStrokeButtons).
          // `leadingExtra` (e.g. camera button) overlays the same slot when canClear is false.
          ZStack {
            if !config.hideStrokeButtons {
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
              .opacity(config.canClear ? 1.0 : 0.0)
              .disabled(!config.canClear)
              .allowsHitTesting(config.canClear)
            }
            if !config.canClear || config.hideStrokeButtons, let leading = config.leadingExtra {
              leading
                .transition(.opacity.combined(with: .scale))
            }
          }

          Spacer()

          // Trailing content: in camera mode, prefer a `trailingExtra` override
          // (e.g. album picker button); otherwise show the normal trailing
          // (e.g. Save button).
          if config.hideStrokeButtons {
            if let trailing = config.trailingExtra {
              trailing
            }
          } else if !(TrailingHeaderView() is EmptyView) {
            TrailingHeaderView()
          }

        }
        .overlay {
          // Center content absolutely centered, ignoring left/right widths
          if !config.hideStrokeButtons, config.canUndo || config.canRedo {
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
            .transition(.opacity.combined(with: .scale))
          } else if let centerContent = config.centerContent {
            centerContent
              .transition(.opacity.combined(with: .scale))
          }
        }
        // Reserve enough height for a circular glass button (40pt + 2pt padding on
        // iOS 26+) so the row keeps the same height whether the leading/trailing
        // glass buttons are visible or only the center content (e.g. camera flip)
        // is shown. Avoids a layout shift on entering/leaving camera mode.
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 12)
        // Drive the leading/center/trailing transitions with a springy curve.
        // Kept as an implicit `.animation(value:)` rather than baked into the
        // transitions themselves so a `disablesAnimations=true` transaction
        // (e.g. `CameraReferenceContext.reset()` during backgrounding) can
        // override it — baked-in transition animations otherwise leave the
        // glass buttons stranded mid-transition when the app snapshots.
        .animation(.springFkingSatifying, value: isCameraLive)
        // Elevate buttons row above the canvas in z-order so overlays
        // (e.g. TorchlightGlowView on the bulb button) render on top of the canvas.
        .zIndex(1)
      }

      ZStack {
        // Inner content — backdrop, drawing surface, live preview, shutter and
        // inner shadow all share a single rounded-rect clip applied at this
        // container level. Individual layers can overscan their own frames
        // (e.g. the shutter blades) and the container clip handles trimming —
        // no per-layer clipShape/mask needed, and no hairline aliasing along
        // the canvas rim.
        ZStack {
          // Canvas background — switches to black in camera mode so the white
          // drawing surface doesn't bleed through while the live preview fades in.
          Rectangle()
            .fill(isCameraLive ? Color.black : Color.backgroundColor)

          // Tracing-reference backdrop: photo at 30% opacity over a fixed white
          // base so its appearance is identical in light/dark themes (opacity
          // would otherwise blend with the theme-dependent canvas background).
          if !isCameraLive, let backdrop = backdropImage {
            ZStack {
              Color.white
              Image(uiImage: backdrop)
                .resizable()
                .scaledToFill()
                .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
                .opacity(0.3)
            }
            .allowsHitTesting(false)
          }

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
              context.fill(path, with: .color(.appAccent))
            } else {
              // Stroke line paths
              context.stroke(
                path,
                with: .color(.appAccent),
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
              context.fill(currentPath, with: .color(.appAccent))
            } else {
              // Stroke line paths
              context.stroke(
                currentPath,
                with: .color(.appAccent),
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
        .id(placeholderID)
        .opacity(isCameraLive ? 0 : 1)
        .allowsHitTesting(!isCameraLive)
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

        // Live camera preview — only mounted while the shutter is fully closed
        // over the canvas, then latched across the open phase so the feed stays
        // visible once the blades retract.
        if cameraPreviewMounted, !suppressLivePreview, let session = liveCameraSession {
          CameraPreviewView(session: session, device: liveCameraDevice, mirrored: liveCameraMirrored)
            .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
            .allowsHitTesting(false)
        }

        // Camera shutter — overlays the canvas area regardless of mode so it can
        // close over either the live preview (entry) or the drawing canvas (exit).
        // Overscans past the canvas; the container clip below trims it.
        if let shutterController {
          let shutterOverscan: CGFloat = 2
          CameraShutterView(controller: shutterController)
            .frame(width: CANVAS_SIZE + shutterOverscan * 2, height: CANVAS_SIZE + shutterOverscan * 2)
            .allowsHitTesting(false)
        }

        // Inner shadow hugging the canvas cutout — drawn last so it overlays
        // the shutter blades, giving the rounded-rect rim depth even while
        // the shutter is fully closed. Stroke is drawn at 2× the desired
        // shadow depth so its centerline (peak intensity) lands on the rect
        // edge; the container clip below removes the outer half, leaving a
        // one-directional gradient that fades purely inward.
        RoundedRectangle(cornerRadius: canvasCornerRadius, style: .continuous)
          .stroke(Color.black.opacity(0.7), lineWidth: 8)
          .blur(radius: 4)
          .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
          .opacity((isCameraLive || isShutterCycling) ? 1 : 0)
          .animation(.easeInOut(duration: 0.15), value: isCameraLive || isShutterCycling)
          .allowsHitTesting(false)
        }
        .compositingGroup()
        .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
        .mask(
          RoundedRectangle(cornerRadius: canvasCornerRadius, style: .continuous)
            .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
        )

        // Border drawn on top of the clipped container so it remains visible
        // above the shutter / preview / inner shadow.
        RoundedRectangle(cornerRadius: canvasCornerRadius, style: .continuous)
          .strokeBorder(.borderColor, lineWidth: 1.0)
          .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
          .allowsHitTesting(false)
      }
    }
    .onAppear {
      decodePlaceholder()
      cameraPreviewMounted = isCameraLive
    }
    .onChange(of: placeholderData) { _, _ in
      decodePlaceholder()
    }
    .onChange(of: isShutterFullyClosed) { _, closed in
      // Latch the preview to the live-mode state on each edge of the shutter
      // being fully closed — that's exactly when the swap behind the blades
      // happens, so mounting/unmounting is invisible.
      if closed {
        cameraPreviewMounted = isCameraLive
      }
    }
    .onChange(of: isCameraLive) { _, live in
      if !live {
        // Always tear the preview down the moment we leave live mode — covers
        // both the in-cycle exit (shutter is closed over it) and out-of-band
        // teardowns like `reset()` triggered by a sheet dismiss.
        cameraPreviewMounted = false
      } else if isShutterFullyClosed {
        cameraPreviewMounted = true
      }
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
    canvasCornerRadius: CGFloat = 32,
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
      canvasCornerRadius: canvasCornerRadius,
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
