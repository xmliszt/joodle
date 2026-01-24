import SwiftUI

struct DrawingPreviewView: View {
  let entry: DayEntry?
  let highResDrawing: UIImage?
  let size: CGFloat
  let scale: CGFloat
  /// Optional override for the logical display size used for stroke calculation.
  /// If nil, uses size / scale.
  var logicalDisplaySize: CGFloat? = nil
  var animateDrawing: Bool = false
  var looping: Bool = false
  
  var body: some View {
    if let highResDrawing = highResDrawing {
      // Show pre-rendered high-resolution drawing
      Image(uiImage: highResDrawing)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
    } else if let entry = entry, let drawingData = entry.drawingData, !drawingData.isEmpty {
      // Fallback to live Canvas rendering (for previews)
      DrawingDisplayView(
        entry: entry,
        displaySize: logicalDisplaySize ?? (size / scale),
        dotStyle: .present,
        accent: true,
        highlighted: false,
        scale: scale,
        useThumbnail: false,
        animateDrawing: animateDrawing,
        looping: looping
      )
      .frame(width: size, height: size)
    } else {
      // Empty state
      Image(systemName: "scribble.variable")
        .font(.system(size: size * 0.16)) // Approx ratio based on ExcerptView (100/600)
        .frame(width: size, height: size)
        .foregroundColor(.textColor.opacity(0.3))
    }
  }
}
