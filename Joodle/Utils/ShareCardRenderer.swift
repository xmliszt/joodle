//
//  ShareCardRenderer.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import UIKit
import SwiftData

@MainActor
class ShareCardRenderer {
  static let shared = ShareCardRenderer()

  private init() {}

  /// Pre-renders a drawing at high resolution for embedding in share cards
  /// - Parameters:
  ///   - entry: The day entry containing the drawing data
  ///   - targetPixelSize: The desired output size in physical pixels
  ///   - colorScheme: The color scheme to use for rendering (affects dynamic colors like .appAccent)
  ///   - logicalDisplaySize: The logical display size for stroke calculations (should match the view's logicalDisplaySize)
  /// - Returns: A high-resolution UIImage at 1x scale that will be downsized by SwiftUI
  private func renderDrawingAtHighResolution(entry: DayEntry, targetPixelSize: CGSize, colorScheme: ColorScheme, logicalDisplaySize: CGFloat) -> UIImage? {
    guard let drawingData = entry.drawingData, !drawingData.isEmpty else {
      return nil
    }

    // Render at high physical pixel resolution to preserve vector quality
    // The image will be created at 1x scale with high pixel dimensions
    // SwiftUI will then scale it down to fit the container
    let renderSize = targetPixelSize

    // Create a high-res drawing view using the same logical display size as the live view
    // This ensures stroke calculations match between preview and render
    let drawingView = DrawingDisplayView(
      entry: entry,
      displaySize: logicalDisplaySize,
      dotStyle: .present,
      accent: true,
      highlighted: false,
      scale: renderSize.width / logicalDisplaySize,  // Scale to achieve target pixel size
      useThumbnail: false
    )
    .frame(width: renderSize.width, height: renderSize.height)
    .environment(\.colorScheme, colorScheme)

    // Render to high-res image
    let controller = UIHostingController(rootView: drawingView)
    controller.view.bounds = CGRect(origin: .zero, size: renderSize)
    controller.view.backgroundColor = .clear

    // Add to a temporary window to ensure the view is in a window hierarchy
    let window = UIWindow(frame: CGRect(origin: .zero, size: renderSize))
    window.rootViewController = controller
    window.isHidden = false

    // Force layout
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0  // Use 1x scale so image size = pixel size, SwiftUI will downsize
    format.opaque = false

    let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
    let image = renderer.image { context in
      controller.view.drawHierarchy(in: CGRect(origin: .zero, size: renderSize), afterScreenUpdates: true)
    }

    // Clean up window
    window.isHidden = true
    window.rootViewController = nil

    return image
  }

  /// Renders a SwiftUI view as a UIImage
  /// - Parameters:
  ///   - view: The SwiftUI view to render
  ///   - size: The size of the output image
  /// - Returns: A UIImage representation of the view
  func render<Content: View>(view: Content, size: CGSize) -> UIImage? {
    let controller = UIHostingController(rootView: view)
    controller.view.bounds = CGRect(origin: .zero, size: size)
    controller.view.backgroundColor = .clear

    // Force layout pass
    let targetSize = controller.sizeThatFits(in: size)
    controller.view.bounds = CGRect(origin: .zero, size: targetSize)
    controller.view.layoutIfNeeded()

    // Use 1x scale for standard output
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = false  // Transparent background

    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
      controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
    }
  }

  /// Renders a card style with entry data as a UIImage
  /// - Parameters:
  ///   - style: The card style to render
  ///   - entry: The day entry containing the content
  ///   - date: The date for the entry
  ///   - colorScheme: The color scheme to use for rendering
  ///   - showWatermark: Whether to show the watermark (default: true)
  /// - Returns: A UIImage representation of the card
  func renderCard(
    style: ShareCardStyle,
    entry: DayEntry?,
    date: Date,
    colorScheme: ColorScheme,
    showWatermark: Bool = true
  ) -> UIImage? {
    // Pre-render drawing at high resolution if present
    var highResDrawing: UIImage?
    if let entry = entry, entry.drawingData != nil {
      // Determine the logical display size based on the card style
      // This should match what the view uses for logicalDisplaySize
      let logicalDisplaySize: CGFloat
      switch style {
      case .minimal:
        logicalDisplaySize = 800  // MinimalView uses nil → defaults to size/scale = 800
      case .excerpt, .anniversary:
        logicalDisplaySize = 450  // ExcerptView and AnniversaryView use 450
      case .detailed:
        logicalDisplaySize = 200  // DetailedView uses 200
      default:
        logicalDisplaySize = 800  // Default fallback
      }
      
      // Render at high pixel resolution (2700x2700) max limit.
      // Use the same logicalDisplaySize as the view for consistent stroke calculations
      let highResPixelSize = CGSize(width: 2700, height: 2700)  // High resolution pixels
      highResDrawing = renderDrawingAtHighResolution(
        entry: entry,
        targetPixelSize: highResPixelSize,
        colorScheme: colorScheme,
        logicalDisplaySize: logicalDisplaySize
      )
    }


    // Add padding to capture rounded corners and shadow
    let padding: CGFloat = 60
    let paddedSize = CGSize(
      width: style.cardSize.width + padding * 2,
      height: style.cardSize.height + padding * 2
    )
    let cardBackground = colorScheme == .dark ? Color.black : Color.white

    let cardView = ZStack(alignment: .center) {
      createCardView(
        style: style,
        entry: entry,
        date: date,
        highResDrawing: highResDrawing,
        showWatermark: showWatermark
      )
      .frame(width: style.cardSize.width, height: style.cardSize.height)
      .background(cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 80))
      .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 8)
    }
    .frame(width: paddedSize.width, height: paddedSize.height, alignment: .center)
    .environment(\.colorScheme, colorScheme)
    .fixedSize()

    return render(view: cardView, size: paddedSize)
  }

  /// Renders a year grid card style as a UIImage
  /// - Parameters:
  ///   - style: The card style to render (must be a year grid style)
  ///   - year: The year to display
  ///   - percentage: The year progress percentage
  ///   - entries: The entries for the year
  ///   - colorScheme: The color scheme to use for rendering
  ///   - showWatermark: Whether to show the watermark (default: true)
  /// - Returns: A UIImage representation of the card
  func renderYearGridCard(
    style: ShareCardStyle,
    year: Int,
    percentage: Double?,
    entries: [ShareCardDayEntry],
    colorScheme: ColorScheme,
    showWatermark: Bool = true
  ) -> UIImage? {
    guard style.isYearGridStyle else {
      return nil
    }

    // Add padding to capture rounded corners and shadow
    let padding: CGFloat = 60
    let paddedSize = CGSize(
      width: style.cardSize.width + padding * 2,
      height: style.cardSize.height + padding * 2
    )
    let cardBackground = colorScheme == .dark ? Color.black : Color.white

    let cardView = ZStack(alignment: .center) {
      createYearGridCardView(
        style: style,
        year: year,
        percentage: percentage,
        entries: entries,
        showWatermark: showWatermark
      )
      .frame(width: style.cardSize.width, height: style.cardSize.height)
      .background(cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 80))
      .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 8)
    }
    .frame(width: paddedSize.width, height: paddedSize.height, alignment: .center)
    .environment(\.colorScheme, colorScheme)
    .fixedSize()

    return render(view: cardView, size: paddedSize)
  }

  /// Creates the appropriate card view based on style
  @ViewBuilder
  private func createCardView(
    style: ShareCardStyle,
    entry: DayEntry?,
    date: Date,
    highResDrawing: UIImage?,
    showWatermark: Bool
  ) -> some View {
    switch style {
    case .minimal:
      MinimalView(entry: entry, date: date, highResDrawing: highResDrawing, showWatermark: showWatermark)
    case .excerpt:
      ExcerptView(entry: entry, date: date, highResDrawing: highResDrawing, showWatermark: showWatermark)
    case .detailed:
      DetailedView(entry: entry, date: date, highResDrawing: highResDrawing, showWatermark: showWatermark)
    case .anniversary:
      AnniversaryView(entry: entry, date: date, highResDrawing: highResDrawing, showWatermark: showWatermark)
    case .yearGridDots, .yearGridJoodles, .yearGridJoodlesOnly:
      // Year grid styles should use renderYearGridCard instead
      EmptyView()
    case .animatedMinimalVideo, .animatedExcerptVideo:
      // Animated styles should use renderAnimatedVideo instead
      EmptyView()
    }
  }

  // MARK: - Animated Export

  /// Renders an animated drawing as a video file
  /// - Parameters:
  ///   - style: The card style to render (must be a video style)
  ///   - entry: The day entry containing the drawing
  ///   - date: The date for the entry
  ///   - colorScheme: The color scheme to use for rendering
  ///   - showWatermark: Whether to show the watermark
  ///   - progressCallback: Optional callback for progress updates (0.0 to 1.0)
  /// - Returns: URL to the temporary video file
  func renderAnimatedVideo(
    style: ShareCardStyle,
    entry: DayEntry?,
    date: Date,
    colorScheme: ColorScheme,
    showWatermark: Bool = true,
    progressCallback: ((Double) -> Void)? = nil
  ) async throws -> URL? {
    guard let entry = entry, entry.drawingData != nil else {
      return nil
    }

    guard style.isVideoStyle else {
      return nil
    }

    let frameRenderer = AnimatedDrawingRenderer()
    let videoExporter = VideoExporter()
    let config = style.animationConfig

    // Generate card frames
    let frames = await frameRenderer.generateCardFrames(
      entry: entry,
      date: date,
      style: style,
      colorScheme: colorScheme,
      showWatermark: showWatermark,
      progressCallback: { progress in
        progressCallback?(progress)
      }
    )

    guard !frames.isEmpty else {
      return nil
    }

    // Export as video
    let videoURL = try await videoExporter.createVideo(from: frames, config: config)
    progressCallback?(1.0)

    return videoURL
  }

  /// Renders a single frame for animated preview at a specific progress
  /// - Parameters:
  ///   - style: The animated card style
  ///   - entry: The day entry containing the drawing
  ///   - date: The date for the entry
  ///   - colorScheme: The color scheme to use for rendering
  ///   - showWatermark: Whether to show the watermark
  ///   - progress: Animation progress from 0.0 to 1.0
  /// - Returns: A UIImage preview frame
  func renderAnimatedFrame(
    style: ShareCardStyle,
    entry: DayEntry?,
    date: Date,
    colorScheme: ColorScheme,
    showWatermark: Bool = true,
    progress: CGFloat = 1.0
  ) -> UIImage? {
    guard let entry = entry, entry.drawingData != nil else {
      return nil
    }

    guard style.isAnimatedStyle else {
      return nil
    }

    let frameRenderer = AnimatedDrawingRenderer()
    let config = style.animationConfig

    // Get the paths
    guard let drawingData = entry.drawingData else { return nil }
    let pathsWithMetadata = DrawingPathCache.shared.getPathsWithMetadata(for: drawingData)
    guard !pathsWithMetadata.isEmpty else { return nil }

    // Get stroke color
    let strokeColor = UIColor(Color.appAccent)

    // Calculate drawing size based on style
    let scale: CGFloat = 1.0
    let drawingSize: CGFloat = style.includesExcerpt ? 600 * scale : 800 * scale

    // Render drawing frame at current progress
    guard let drawingFrame = frameRenderer.renderDrawingFrame(
      pathsWithMetadata: pathsWithMetadata,
      progress: progress,
      size: CGSize(width: drawingSize, height: drawingSize),
      foregroundColor: strokeColor,
      config: config
    ) else {
      return nil
    }

    // Render complete card frame using the AnimatedDrawingRenderer
    return frameRenderer.renderCardFrame(
      drawingImage: drawingFrame,
      entry: entry,
      date: date,
      style: style,
      colorScheme: colorScheme,
      showWatermark: showWatermark
    )
  }

  /// Generate all frames for animated preview
  /// - Parameters:
  ///   - style: The animated card style
  ///   - entry: The day entry containing the drawing
  ///   - date: The date for the entry
  ///   - colorScheme: The color scheme to use for rendering
  ///   - showWatermark: Whether to show the watermark
  /// - Returns: Array of UIImage frames for animation
  func generateAnimatedPreviewFrames(
    style: ShareCardStyle,
    entry: DayEntry?,
    date: Date,
    colorScheme: ColorScheme,
    showWatermark: Bool = true
  ) async -> [UIImage] {
    guard let entry = entry, entry.drawingData != nil else {
      return []
    }

    guard style.isAnimatedStyle else {
      return []
    }

    let frameRenderer = AnimatedDrawingRenderer()

    return await frameRenderer.generateCardFrames(
      entry: entry,
      date: date,
      style: style,
      colorScheme: colorScheme,
      showWatermark: showWatermark,
      progressCallback: nil
    )
  }

  /// Creates the appropriate year grid card view based on style
  @ViewBuilder
  private func createYearGridCardView(
    style: ShareCardStyle,
    year: Int,
    percentage: Double?,
    entries: [ShareCardDayEntry],
    showWatermark: Bool
  ) -> some View {
    switch style {
    case .yearGridDots:
      YearGridDotsView(year: year, percentage: percentage, entries: entries, showWatermark: showWatermark)
    case .yearGridJoodles:
      YearGridJoodlesView(year: year, percentage: percentage, entries: entries, showWatermark: showWatermark, showEmptyDots: true)
    case .yearGridJoodlesOnly:
      YearGridJoodlesView(year: year, percentage: percentage, entries: entries, showWatermark: showWatermark, showEmptyDots: false)
    default:
      EmptyView()
    }
  }

  // MARK: - Year Data Helpers

  /// Calculates the year progress percentage for a given year
  /// - Parameter year: The year to calculate progress for
  /// - Returns: The percentage of the year that has passed (0-100)
  func calculateYearProgress(for year: Int) -> Double {
    let calendar = Calendar.current
    let now = Date()
    let year = calendar.component(.year, from: now)

    guard
      let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))
    else {
      return 0.0
    }

    // Get total days in the year
    let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count ?? 365

    // Get current day of year (1-indexed, so Jan 1 = 1)
    let currentDayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1

    // Calculate progress: on the last day (e.g., day 365 of 365), this gives 100%
    return (Double(currentDayOfYear) / Double(daysInYear)) * 100.0
  }

  /// Loads entries for a specific year from the model context
  /// - Parameters:
  ///   - year: The year to load entries for
  ///   - modelContext: The SwiftData model context
  /// - Returns: An array of ShareCardDayEntry for the year
  func loadEntriesForYear(_ year: Int, from modelContext: ModelContext) -> [ShareCardDayEntry] {
    let yearPrefix = "\(year)-"
    let predicate = #Predicate<DayEntry> { entry in
      entry.dateString.starts(with: yearPrefix)
    }
    let descriptor = FetchDescriptor<DayEntry>(predicate: predicate)

    do {
      let dayEntries = try modelContext.fetch(descriptor)
      return dayEntries.map { ShareCardDayEntry(from: $0) }
    } catch {
      print("ShareCardRenderer: Failed to load entries for year \(year): \(error)")
      return []
    }
  }
}
