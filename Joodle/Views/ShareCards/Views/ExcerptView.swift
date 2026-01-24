import SwiftUI

struct ExcerptView: View {
  private let cardStyle: ShareCardStyle = .excerpt
  let entry: DayEntry?
  let date: Date
  let highResDrawing: UIImage?
  var showWatermark: Bool = true

  private var dateString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, dd MMM yyyy"
    return formatter.string(from: date)
  }

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / cardStyle.cardSize.width

      ZStack {
        // Background
        (colorScheme == .dark ? Color.black : Color.white)
          .ignoresSafeArea()

        VStack(spacing: 0) {
          Spacer()

          // Main content - Drawing or Text
          DrawingPreviewView(
            entry: entry,
            highResDrawing: highResDrawing,
            size: 600,
            scale: scale
          )
          .background(
            RoundedRectangle(cornerRadius: 80 * scale, style: .continuous)
              .foregroundStyle(.appSurface)
          )
          .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)

          Spacer()
          Spacer()

        }
        // Date footer
        VStack(){
          Spacer()
          VStack(spacing: 14 * scale) {
            Text(entry?.body ?? "")
              .font(.system(size: 52 * scale))
              .lineLimit(1)
              .padding(.horizontal, 140 * scale)
            Text(dateString)
              .font(.system(size: 48 * scale))
              .foregroundColor(.appTextSecondary)
          }
        }
        .padding(.top, 30 * scale)
        .padding(.bottom, 100 * scale)
        .padding(.horizontal, 80 * scale)

        // Watermark - bottom right corner
        if showWatermark {
          MushroomWatermarkView(scale: scale)
        }
      }
      .frame(width: size.width, height: size.height)
    }
    .aspectRatio(cardStyle.cardSize.width / cardStyle.cardSize.height, contentMode: .fit)
  }
}

#Preview("With Drawing") {
  ExcerptView(
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

#Preview("With Text") {
  ExcerptView(
    entry: DayEntry(
      body: "Today was amazing! I learned so much and felt really productive.",
      createdAt: Date()
    ),
    date: Date(),
    highResDrawing: nil
  )
  .frame(width: 300, height: 300)
  // add border
  .border(Color.black)
}

#Preview("With Drawing & Text") {
  ExcerptView(
    entry: DayEntry(
      body: "Today was amazing! I learned so much and felt really productive.",
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

#Preview("Without Watermark") {
  ExcerptView(
    entry: DayEntry(
      body: "Today was amazing!",
      createdAt: Date(),
      drawingData: createMockDrawingData()
    ),
    date: Date(),
    highResDrawing: nil,
    showWatermark: false
  )
  .frame(width: 300, height: 300)
  // add border
  .border(Color.black)
}

#Preview("Empty") {
  ExcerptView(
    entry: nil,
    date: Date(),
    highResDrawing: nil
  )
  .frame(width: 300, height: 300)
  // add border
  .border(Color.black)
}
