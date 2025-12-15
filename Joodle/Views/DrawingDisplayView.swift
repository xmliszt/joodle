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

  @State private var pathsWithMetadata: [PathWithMetadata] = []
  @State private var isVisible = false
  @State private var thumbnailImage: UIImage?

  // Use shared cache for drawing paths
  private let pathCache = DrawingPathCache.shared

  init(
    entry: DayEntry?,
    displaySize: CGFloat,
    dotStyle: DotStyle,
    accent: Bool,
    highlighted: Bool,
    scale: CGFloat,
    useThumbnail: Bool = false
  ) {
    self.entry = entry
    self.displaySize = displaySize
    self.dotStyle = dotStyle
    self.accent = accent
    self.highlighted = highlighted
    self.scale = scale
    self.useThumbnail = useThumbnail
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
        // Render vector paths at actual display size for high quality
        Canvas { context, size in
          // Calculate scale from canvas size (300x300) to display size
          let canvasScale = (displaySize * scale) / CANVAS_SIZE

          // Scale the context to render at display size
          context.scaleBy(x: canvasScale, y: canvasScale)

          for pathWithMetadata in pathsWithMetadata {
            let path = pathWithMetadata.path

            // Render based on original intent stored in metadata
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
    }
    .onChange(of: entry?.drawingData) { _, _ in
      // Load new data and animate immediately
      loadDrawingData()
      withAnimation(.springFkingSatifying) {
        isVisible = true
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
