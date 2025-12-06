import SwiftUI

struct MinimalView: View {
  private let cardStyle: ShareCardStyle = .minimal
  let entry: DayEntry?
  let date: Date
  let highResDrawing: UIImage?

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / cardStyle.cardSize.width

      ZStack {
        // Background
        Color.backgroundColor
          .ignoresSafeArea()

        VStack {
          // Main content - Drawing or Text
          // Main content - Drawing or Text
          DrawingPreviewView(
            entry: entry,
            highResDrawing: highResDrawing,
            size: 800 * scale,
            scale: scale,
            logicalDisplaySize: nil // Use default calculation
          )
          .padding()
          .background(
            RoundedRectangle(cornerRadius: 80 * scale, style: .continuous)
              .foregroundStyle(.appSurface)
          )
          .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
        }
      }
      .frame(width: size.width, height: size.height)
    }
    .aspectRatio(cardStyle.cardSize.width / cardStyle.cardSize.height, contentMode: .fit)
  }
}

#Preview("With Drawing") {
  MinimalView(
    entry: DayEntry(
      body: "",
      createdAt: Date(),
      drawingData: createMockDrawingData()
    ),
    date: Date(),
    highResDrawing: nil
  )
  .frame(width: 300, height: 300)
  // add border
  .border(Color.black)
}

#Preview("Empty") {
  MinimalView(
    entry: nil,
    date: Date(),
    highResDrawing: nil
  )
  .frame(width: 300, height: 300)
  // add border
  .border(Color.black)
}
