import SwiftUI

struct DrawingPreviewView: View {
  let entry: DayEntry?
  let highResDrawing: UIImage?
  let size: CGFloat
  let scale: CGFloat
  var animateDrawing: Bool = false
  var looping: Bool = false
  var strokeMultiplier: CGFloat = 1.0
  
  var actualSize: CGFloat {
    size * scale
  }
  
  var body: some View {
    if let highResDrawing = highResDrawing {
      // Show pre-rendered high-resolution drawing
      Image(uiImage: highResDrawing)
        .resizable()
        .scaledToFit()
        .frame(width: actualSize, height: actualSize)
    } else if let entry = entry, let drawingData = entry.drawingData, !drawingData.isEmpty {
      // Fallback to live Canvas rendering (for previews)
      DrawingDisplayView(
        entry: entry,
        displaySize: size,
        dotStyle: .present,
        accent: true,
        highlighted: false,
        scale: scale,
        useThumbnail: false,
        animateDrawing: animateDrawing,
        looping: looping,
        strokeMultiplier: strokeMultiplier
      )
      .frame(width: size, height: size)
    } else {
      // Empty state
      Image(systemName: "scribble.variable")
        .font(.appFont(size: actualSize * 0.16)) // Approx ratio based on ExcerptView (100/600)
        .frame(width: actualSize, height: actualSize)
        .foregroundColor(.textColor.opacity(0.3))
    }
  }
}
