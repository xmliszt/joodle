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
  let looping: Bool  // Loop animation infinitely

  // Animation timing constants
  private static let maxAnimationDuration: Double = 3.0  // Maximum total animation duration
  private static let durationPerPixel: Double = 0.2 / 50.0  // 0.2 seconds per 20 pixels
  private static let minStrokeDuration: Double = 0.05  // Minimum duration for very short strokes/dots

  @State private var pathsWithMetadata: [PathWithMetadata] = []
  @State private var isVisible = false
  @State private var thumbnailImage: UIImage?

  // Animation state for drawing replay
  @State private var drawingProgress: CGFloat = 0.0
  @State private var hasAnimatedDrawing: Bool = false
  @State private var isAnimatingDrawing: Bool = false
  @State private var animationStartTime: Date?
  @State private var lastCalculatedProgress: CGFloat = 0.0

  // Use shared cache for drawing paths
  private let pathCache = DrawingPathCache.shared

  /// Calculate per-stroke durations based on stroke lengths
  /// Returns array of durations and total animation duration
  private var strokeTimingInfo: (durations: [Double], totalDuration: Double, cumulativeEndTimes: [Double]) {
    guard !pathsWithMetadata.isEmpty else {
      return ([], 0, [])
    }

    // Calculate raw duration for each stroke based on length
    var rawDurations: [Double] = pathsWithMetadata.map { pathWithMetadata in
      if pathWithMetadata.metadata.isDot {
        return Self.minStrokeDuration
      } else {
        let lengthBasedDuration = Double(pathWithMetadata.metadata.length) * Self.durationPerPixel
        return max(Self.minStrokeDuration, lengthBasedDuration)
      }
    }

    let rawTotal = rawDurations.reduce(0, +)

    // If total exceeds max, scale down all durations proportionally
    if rawTotal > Self.maxAnimationDuration {
      let scaleFactor = Self.maxAnimationDuration / rawTotal
      rawDurations = rawDurations.map { $0 * scaleFactor }
    }

    let totalDuration = min(rawTotal, Self.maxAnimationDuration)

    // Calculate cumulative end times for each stroke
    var cumulativeEndTimes: [Double] = []
    var cumulative: Double = 0
    for duration in rawDurations {
      cumulative += duration
      cumulativeEndTimes.append(cumulative)
    }

    return (rawDurations, totalDuration, cumulativeEndTimes)
  }

  /// Calculated total animation duration based on stroke lengths
  private var calculatedAnimationDuration: Double {
    return strokeTimingInfo.totalDuration
  }

  init(
    entry: DayEntry?,
    displaySize: CGFloat,
    dotStyle: DotStyle = .present,
    accent: Bool = true,
    highlighted: Bool = false,
    scale: CGFloat = 1.0,
    useThumbnail: Bool = false,
    animateDrawing: Bool = false,
    looping: Bool = false
  ) {
    self.entry = entry
    self.displaySize = displaySize
    self.dotStyle = dotStyle
    self.accent = accent
    self.highlighted = highlighted
    self.scale = scale
    self.useThumbnail = useThumbnail
    self.animateDrawing = animateDrawing
    self.looping = looping
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
        if isAnimatingDrawing {
          TimelineView(.animation) { timeline in
            Canvas { context, size in
              renderAnimatedFrame(context: &context, size: size, timelineDate: timeline.date)
            }
          }
          .frame(width: displaySize * scale, height: displaySize * scale)
          .scaleEffect(isVisible ? 1.0 : 0.9)
          .blur(radius: isVisible ? 0 : 5)
          .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            // Check for animation completion/looping every frame (~60fps)
            if isAnimatingDrawing, let startTime = animationStartTime {
              let elapsed = Date().timeIntervalSince(startTime)
              let progress = min(1.0, CGFloat(elapsed / calculatedAnimationDuration))
              
              if progress >= 1.0 && lastCalculatedProgress < 1.0 {
                if looping {
                  animationStartTime = Date()
                  lastCalculatedProgress = 0.0
                } else {
                  isAnimatingDrawing = false
                  drawingProgress = 1.0
                }
              }
              lastCalculatedProgress = progress
            }
          }
        } else {
          // Static canvas when not animating - no TimelineView updates
          Canvas { context, size in
            renderStaticDrawing(context: &context, size: size)
          }
          .frame(width: displaySize * scale, height: displaySize * scale)
          .scaleEffect(isVisible ? 1.0 : 0.9)
          .blur(radius: isVisible ? 0 : 5)
        }
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
    .onChange(of: animateDrawing) { _, newValue in
      // When animateDrawing changes to true, reset and restart animation
      if newValue {
        hasAnimatedDrawing = false
        drawingProgress = 0.0
        startDrawingAnimationIfNeeded()
      } else {
        // When animateDrawing changes to false, stop the animation
        isAnimatingDrawing = false
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

  /// Render animated frame with progress calculation
  private func renderAnimatedFrame(context: inout GraphicsContext, size: CGSize, timelineDate: Date) {
    // Calculate progress based on elapsed time during animation
    let currentProgress: CGFloat = {
      if isAnimatingDrawing, let startTime = animationStartTime {
        let elapsed = timelineDate.timeIntervalSince(startTime)
        let progress = min(1.0, CGFloat(elapsed / calculatedAnimationDuration))
        // Apply easeOut curve: 1 - (1 - t)^2
        let eased = 1.0 - pow(1.0 - progress, 2)
        return eased
      }
      return drawingProgress
    }()

    // Calculate scale from canvas size (300x300) to display size
    let canvasScale = (displaySize * scale) / CANVAS_SIZE

    // Scale the context to render at display size
    context.scaleBy(x: canvasScale, y: canvasScale)

    // Get timing info for length-based animation
    let timingInfo = strokeTimingInfo
    let totalDuration = timingInfo.totalDuration
    let cumulativeEndTimes = timingInfo.cumulativeEndTimes
    let durations = timingInfo.durations

    // Calculate current elapsed time based on progress
    let effectiveProgress = animateDrawing ? currentProgress : 1.0
    let currentElapsedTime = effectiveProgress * CGFloat(totalDuration)

    for (index, pathWithMetadata) in pathsWithMetadata.enumerated() {
      // Determine start time for this stroke
      let strokeStartTime: CGFloat = index == 0 ? 0 : CGFloat(cumulativeEndTimes[index - 1])
      let strokeEndTime = CGFloat(cumulativeEndTimes[index])

      // Skip paths that haven't started yet
      guard currentElapsedTime > strokeStartTime || !animateDrawing else { continue }

      let path = pathWithMetadata.path

      // Calculate trim for the current path being drawn
      let pathProgress: CGFloat
      if animateDrawing && currentElapsedTime < strokeEndTime {
        // This stroke is currently being drawn
        let strokeDuration = CGFloat(durations[index])
        let timeIntoStroke = currentElapsedTime - strokeStartTime
        pathProgress = min(1.0, max(0.0, timeIntoStroke / strokeDuration))
      } else if animateDrawing && currentElapsedTime < strokeStartTime {
        // This stroke hasn't started yet
        pathProgress = 0.0
      } else {
        // Stroke is complete
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

  /// Update animation progress and handle looping
  private func updateAnimationProgress(timelineDate: Date) {
    guard isAnimatingDrawing, let startTime = animationStartTime else { return }

    let elapsed = timelineDate.timeIntervalSince(startTime)
    let progress = min(1.0, CGFloat(elapsed / calculatedAnimationDuration))

    if progress >= 1.0 {
      if looping {
        // Reset for next loop iteration
        animationStartTime = Date()
      } else {
        isAnimatingDrawing = false
        drawingProgress = 1.0
      }
    }
  }

  /// Render animated drawing with TimelineView
  @ViewBuilder
  private func renderDrawingCanvas(timelineDate: Date) -> some View {
    // Calculate progress based on elapsed time during animation
    let currentProgress: CGFloat = {
      if isAnimatingDrawing, let startTime = animationStartTime {
        let elapsed = timelineDate.timeIntervalSince(startTime)
        let progress = min(1.0, CGFloat(elapsed / calculatedAnimationDuration))
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

      // Get timing info for length-based animation
      let timingInfo = strokeTimingInfo
      let totalDuration = timingInfo.totalDuration
      let cumulativeEndTimes = timingInfo.cumulativeEndTimes
      let durations = timingInfo.durations

      // Calculate current elapsed time based on progress
      let effectiveProgress = animateDrawing ? currentProgress : 1.0
      let currentElapsedTime = effectiveProgress * CGFloat(totalDuration)

      for (index, pathWithMetadata) in pathsWithMetadata.enumerated() {
        // Determine start time for this stroke
        let strokeStartTime: CGFloat = index == 0 ? 0 : CGFloat(cumulativeEndTimes[index - 1])
        let strokeEndTime = CGFloat(cumulativeEndTimes[index])

        // Skip paths that haven't started yet
        guard currentElapsedTime > strokeStartTime || !animateDrawing else { continue }

        let path = pathWithMetadata.path

        // Calculate trim for the current path being drawn
        let pathProgress: CGFloat
        if animateDrawing && currentElapsedTime < strokeEndTime {
          // This stroke is currently being drawn
          let strokeDuration = CGFloat(durations[index])
          let timeIntoStroke = currentElapsedTime - strokeStartTime
          pathProgress = min(1.0, max(0.0, timeIntoStroke / strokeDuration))
        } else if animateDrawing && currentElapsedTime < strokeStartTime {
          // This stroke hasn't started yet
          pathProgress = 0.0
        } else {
          // Stroke is complete
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
      // Stop animation when complete, or restart if looping
      if newProgress >= 1.0 && isAnimatingDrawing {
        if looping {
          // Reset for next loop iteration
          animationStartTime = Date()
        } else {
          isAnimatingDrawing = false
          drawingProgress = 1.0
        }
      }
    }
  }

  /// Render static drawing without TimelineView updates
  private func renderStaticDrawing(context: inout GraphicsContext, size: CGSize) {
    // Calculate scale from canvas size (300x300) to display size
    let canvasScale = (displaySize * scale) / CANVAS_SIZE

    // Scale the context to render at display size
    context.scaleBy(x: canvasScale, y: canvasScale)

    // Render all paths at 100% progress
    for pathWithMetadata in pathsWithMetadata {
      let path = pathWithMetadata.path

      if pathWithMetadata.metadata.isDot {
        context.fill(path, with: .color(foregroundColor))
      } else {
        context.stroke(
          path,
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
    entry: DayEntry(body: "", createdAt: Date(), drawingData: createMockDrawingData()),
    displaySize: 200,
    dotStyle: .future,
    accent: false,
    highlighted: false,
    scale: 1.0,
    useThumbnail: false
  )
  .frame(width: 200, height: 200)
  .background(.gray.opacity(0.1))
}

#Preview("Thumbnail Mode") {
  DrawingDisplayView(
    entry: DayEntry(body: "", createdAt: Date(), drawingData: createMockDrawingData()),
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
    entry: DayEntry(body: "", createdAt: Date(), drawingData: createMockDrawingData()),
    displaySize: 200,
    animateDrawing: true,
    looping: true
  )
  .frame(width: 200, height: 200)
  .background(.gray.opacity(0.1))
}
