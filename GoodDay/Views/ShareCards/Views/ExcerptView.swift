import SwiftUI

struct ExcerptView: View {
  private let cardStyle: ShareCardStyle = .excerpt
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

      ZStack {
        // Background
        Color.backgroundColor
          .ignoresSafeArea()

        VStack(spacing: 0) {
          Spacer()

          // Main content - Drawing or Text
          if let highResDrawing = highResDrawing {
            // Show pre-rendered high-resolution drawing
            // The image is already at the correct pixel size, just display it
            Image(uiImage: highResDrawing)
              .resizable()
              .scaledToFit()
              .frame(width: 600 * scale, height: 600 * scale)
              .padding()
              .background(
                RoundedRectangle(cornerRadius: 80 * scale, style: .continuous)
                  .foregroundStyle(.appSurface)
              )
              .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
          } else if let entry = entry, let drawingData = entry.drawingData, !drawingData.isEmpty {
            // Fallback to live Canvas rendering (for previews)
            DrawingDisplayView(
              entry: entry,
              displaySize: 450,
              dotStyle: .present,
              accent: true,
              highlighted: false,
              scale: scale,
              useThumbnail: false
            )
            .frame(width: 600 * scale, height: 600 * scale)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 80 * scale, style: .continuous)
                .foregroundStyle(.appSurface)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
          } else {
            // Empty state
            Image(systemName: "scribble")
              .font(.mansalva(size: 100 * scale))
              .frame(width: 600 * scale, height: 600 * scale)
              .foregroundColor(.textColor.opacity(0.3))
              .padding()
              .background(
                RoundedRectangle(cornerRadius: 80 * scale, style: .continuous)
                  .foregroundStyle(.appSurface)
              )
              .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
          }

          Spacer()
          Spacer()

        }
        // Date footer
        VStack(){
          Spacer()
          VStack(spacing: 14 * scale) {
            Text(entry?.body ?? "")
              .font(.mansalva(size: 52 * scale))
              .lineLimit(1)
              .padding(.horizontal, 140 * scale)
            Text(dateString)
              .font(.mansalva(size: 48 * scale))
              .foregroundColor(.appTextSecondary)
          }
        }
        .padding(.top, 30 * scale)
        .padding(.bottom, 100 * scale)
        .padding(.horizontal, 80 * scale)
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
