import SwiftUI

struct DetailedView: View {
  private let cardStyle: ShareCardStyle = .detailed
  let entry: DayEntry?
  let date: Date
  let highResDrawing: UIImage?

  private var dateString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, yyyy MMM dd"
    return formatter.string(from: date)
  }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / cardStyle.cardSize.width

      ZStack(alignment: .topLeading) {
        // Background
        Color.backgroundColor
          .ignoresSafeArea()

        HStack(spacing: 0) {
          // Drawing
          VStack {
            // Main content - Drawing or Text
            // Main content - Drawing or Text
            DrawingPreviewView(
              entry: entry,
              highResDrawing: highResDrawing,
              size: 200 * scale,
              scale: scale,
              logicalDisplaySize: 200 // Matches original 200
            )
            .padding(32 * scale)
            .background(
              RoundedRectangle(cornerRadius: 50 * scale, style: .continuous)
                .foregroundStyle(.appSurface)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
            
            Spacer()
          }
          .padding(.leading, 60 * scale)
          .padding(.vertical, 60 * scale)
          .padding(.trailing, 24 * scale)

          VStack(spacing: 24 * scale) {
            VStack(spacing: 0) {
              Text(entry?.body ?? "")
                .font(.system(size: 40 * scale))
                .lineSpacing(4 * scale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(spacing: 0) {
              Text(dateString)
                .font(.system(size: 48 * scale))
                .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

          }
          .frame(maxWidth: .infinity)
          .padding(.leading, 24 * scale)
          .padding(.vertical, 60 * scale)
          .padding(.trailing, 80 * scale)
        }
      }
    }
    .aspectRatio(cardStyle.cardSize.width / cardStyle.cardSize.height, contentMode: .fit)
  }
}

#Preview("With Drawing") {
  DetailedView(
    entry: DayEntry(
      body: "",
      createdAt: Date(),
      drawingData: createMockDrawingData()
    ),
    date: Date(),
    highResDrawing: nil
  )
  .frame(width: 300, height: 150)
  .clipShape(RoundedRectangle(cornerRadius: 30))
  .shadow(color: .black.opacity(0.1), radius: 25, x: 0, y: 8)
}

#Preview("With Text") {
  DetailedView(
    entry: DayEntry(
      body: "Today was amazing! I learned so much and felt really productive.",
      createdAt: Date()
    ),
    date: Date(),
    highResDrawing: nil
  )
  .frame(width: 300, height: 150)
  .clipShape(RoundedRectangle(cornerRadius: 30))
  .shadow(color: .black.opacity(0.1), radius: 25, x: 0, y: 8)
}

#Preview("With Drawing & Text") {
  DetailedView(
    entry: DayEntry(
      body: "Today was amazing! I learned so much and felt really productive.",
      createdAt: Date(),
      drawingData: createMockDrawingData()
    ),
    date: Date(),
    highResDrawing: nil
  )
  .frame(width: 300, height: 150)
  .clipShape(RoundedRectangle(cornerRadius: 30))
  .shadow(color: .black.opacity(0.1), radius: 25, x: 0, y: 8)
}

#Preview("Empty") {
  DetailedView(
    entry: nil,
    date: Date(),
    highResDrawing: nil
  )
  .frame(width: 300, height: 150)
  .clipShape(RoundedRectangle(cornerRadius: 30))
  .shadow(color: .black.opacity(0.1), radius: 25, x: 0, y: 8)
}
