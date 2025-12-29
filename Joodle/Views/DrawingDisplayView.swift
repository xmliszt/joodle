//
//  DrawingDisplayView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

struct DrawingDisplayView: View {
  let entry: DayEntry?
  let displaySize: CGFloat
  let dotStyle: DotStyle
  let accent: Bool
  let highlighted: Bool
  let scale: CGFloat
  let useThumbnail: Bool  // Use pre-rendered thumbnail for performance
  let animateDrawing: Bool  // Animate path drawing replay
  let animationDuration: Double  // Total duration for drawing animation

  @State private var pathsWithMetadata: [PathWithMetadata] = []
  @State private var isVisible = false
  @State private var thumbnailImage: UIImage?

  // Animation state for drawing replay
  @State private var drawingProgress: CGFloat = 0.0
  @State private var hasAnimatedDrawing: Bool = false
  @State private var isAnimatingDrawing: Bool = false
  @State private var animationStartTime: Date?

  // Use shared cache for drawing paths
  private let pathCache = DrawingPathCache.shared

  init(
    entry: DayEntry?,
    displaySize: CGFloat,
    dotStyle: DotStyle = .present,
    accent: Bool = true,
    highlighted: Bool = false,
    scale: CGFloat = 1.0,
    useThumbnail: Bool = false,
    animateDrawing: Bool = false,
    animationDuration: Double = 1.5
  ) {
    self.entry = entry
    self.displaySize = displaySize
    self.dotStyle = dotStyle
    self.accent = accent
    self.highlighted = highlighted
    self.scale = scale
    self.useThumbnail = useThumbnail
    self.animateDrawing = animateDrawing
    self.animationDuration = animationDuration
  }

  private var foregroundColor: Color {
    if highlighted { return .appSecondary }
    if accent { return .appAccent }

    // Override base color if it is a present dot.
    if dotStyle == .present { return .appAccent }
    if dotStyle == .future { return .textColor.opacity(0.15) }
    return .textColor
  }

  var body: some View {
    Group {
      if useThumbnail, let thumbnailImage = thumbnailImage {
        // Use pre-rendered thumbnail for performance
        Image(uiImage: thumbnailImage)
          .resizable()
          .renderingMode(.template)
          .foregroundStyle(foregroundColor)
          .frame(width: displaySize * scale, height: displaySize * scale)
          .scaleEffect(isVisible ? 1.0 : 0.9)
          .blur(radius: isVisible ? 0 : 5)
      } else {
        // Use TimelineView to drive animation when animating, otherwise static Canvas
        TimelineView(isAnimatingDrawing ? .animation : .animation(minimumInterval: 1000)) { timeline in
          // Calculate progress based on elapsed time during animation
          let currentProgress: CGFloat = {
            if isAnimatingDrawing, let startTime = animationStartTime {
              let elapsed = timeline.date.timeIntervalSince(startTime)
              let progress = min(1.0, CGFloat(elapsed / animationDuration))
              // Apply easeOut curve: 1 - (1 - t)^2
              let eased = 1.0 - pow(1.0 - progress, 2)
              return eased
            }
            return drawingProgress
          }()

          Canvas { context, size in
            // Calculate scale from canvas size (300x300) to display size
            let canvasScale = (displaySize * scale) / CANVAS_SIZE

            // Scale the context to render at display size
            context.scaleBy(x: canvasScale, y: canvasScale)

            // Calculate how many paths to show based on animation progress
            let totalPaths = pathsWithMetadata.count
            let effectiveProgress = animateDrawing ? currentProgress : 1.0
            let pathsToShow = animateDrawing ? Int(ceil(effectiveProgress * CGFloat(totalPaths))) : totalPaths

            for (index, pathWithMetadata) in pathsWithMetadata.enumerated() {
              // Skip paths that haven't been "drawn" yet
              guard index < pathsToShow else { break }

              let path = pathWithMetadata.path

              // Calculate trim for the current path being drawn
              let pathProgress: CGFloat
              if animateDrawing && index == pathsToShow - 1 && totalPaths > 0 {
                // This is the path currently being drawn - calculate partial progress
                let progressPerPath = 1.0 / CGFloat(totalPaths)
                let pathStartProgress = CGFloat(index) * progressPerPath
                let progressInCurrentPath = (effectiveProgress - pathStartProgress) / progressPerPath
                pathProgress = min(1.0, max(0.0, progressInCurrentPath))
              } else {
                pathProgress = 1.0
              }

              // Render based on original intent stored in metadata
              if pathWithMetadata.metadata.isDot {
                // For dots, fade in based on progress
                if pathProgress > 0.5 {
                  context.fill(path, with: .color(foregroundColor))
                }
              } else {
                // For strokes, use trim effect
                let trimmedPath = path.trimmedPath(from: 0, to: pathProgress)
                context.stroke(
                  trimmedPath,
                  with: .color(foregroundColor),
                  style: StrokeStyle(
                    lineWidth: DRAWING_LINE_WIDTH * (displaySize <= 20 ? 2 : 1),
                    lineCap: .round,
                    lineJoin: .round
                  )
                )
              }
            }
          }
          .onChange(of: currentProgress) { _, newProgress in
            // Stop animation when complete
            if newProgress >= 1.0 && isAnimatingDrawing {
              isAnimatingDrawing = false
              drawingProgress = 1.0
            }
          }
        }
        .frame(width: displaySize * scale, height: displaySize * scale)
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .blur(radius: isVisible ? 0 : 5)
      }
    }
    .animation(.springFkingSatifying, value: isVisible)
    .animation(.springFkingSatifying, value: scale)
    .onAppear {
      // Load data immediately and animate
      loadDrawingData()
      withAnimation(.springFkingSatifying) {
        isVisible = true
      }
      // Start drawing animation if enabled and not yet animated
      startDrawingAnimationIfNeeded()
    }
    .onChange(of: entry?.drawingData) { oldValue, newValue in
      // Load new data and animate immediately
      loadDrawingData()
      withAnimation(.springFkingSatifying) {
        isVisible = true
      }
      // Reset and restart drawing animation for new data
      if animateDrawing && newValue != oldValue {
        hasAnimatedDrawing = false
        drawingProgress = 0.0
        startDrawingAnimationIfNeeded()
      }
    }
    .onChange(of: entry?.drawingThumbnail20) { _, _ in
      // Reload thumbnail when it's updated
      if useThumbnail {
        loadDrawingData()
      }
    }
    .onChange(of: entry?.drawingThumbnail200) { _, _ in
      // Reload thumbnail when it's updated
      if useThumbnail {
        loadDrawingData()
      }
    }
  }

  /// Start the drawing animation if enabled and not yet played
  private func startDrawingAnimationIfNeeded() {
    guard animateDrawing, !hasAnimatedDrawing, !pathsWithMetadata.isEmpty else { return }

    hasAnimatedDrawing = true
    drawingProgress = 0.0
    animationStartTime = Date()
    isAnimatingDrawing = true
  }

  private func loadDrawingData() {
    guard let drawingData = entry?.drawingData else {
      pathsWithMetadata = []
      thumbnailImage = nil
      return
    }

    if useThumbnail {
      // Select appropriate thumbnail based on display size
      let thumbnailData: Data?
      if displaySize <= 20 {
        thumbnailData = entry?.drawingThumbnail20
      } else {
        thumbnailData = entry?.drawingThumbnail200
      }

      if let thumbnailData = thumbnailData {
        thumbnailImage = UIImage(data: thumbnailData)
      } else {
        // Fallback to vector rendering if thumbnail not available
        pathsWithMetadata = pathCache.getPathsWithMetadata(for: drawingData)
      }
    } else {
      // Use cached paths with metadata to avoid repeated JSON decoding
      pathsWithMetadata = pathCache.getPathsWithMetadata(for: drawingData)
    }
  }
}

#Preview("Vector Mode") {
  DrawingDisplayView(
    entry: nil,
    displaySize: 200,
    dotStyle: .present,
    accent: true,
    highlighted: true,
    scale: 1.0,
    useThumbnail: false
  )
  .frame(width: 200, height: 200)
  .background(.gray.opacity(0.1))
}

#Preview("Thumbnail Mode") {
  DrawingDisplayView(
    entry: nil,
    displaySize: 20,
    dotStyle: .present,
    accent: true,
    highlighted: true,
    scale: 1.0,
    useThumbnail: true
  )
  .frame(width: 20, height: 20)
  .background(.gray.opacity(0.1))
}

#Preview("Animated Drawing") {
  DrawingDisplayView(
    entry: nil,
    displaySize: 200,
    animateDrawing: true,
    animationDuration: 2.0
  )
  .frame(width: 200, height: 200)
  .background(.gray.opacity(0.1))
}
