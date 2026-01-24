import SwiftUI

struct AnimatedExcerptCardView: View {
  let entry: DayEntry?
  let date: Date?
  let drawingImage: UIImage?
  let cardSize: CGSize
  var showWatermark: Bool = true
  var animateDrawing: Bool = true
  var looping: Bool = true

  private var aspectRatio: CGFloat {
    guard cardSize.height != 0 else { return 1 }
    return cardSize.width / cardSize.height
  }

  private var dateString: String {
    guard let date = date else { return "" }
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, dd MMM yyyy"
    return formatter.string(from: date)
  }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / cardSize.width

      ZStack {
        // Background
        Color.backgroundColor
          .ignoresSafeArea()

        VStack(spacing: 0) {
          Spacer()

          DrawingPreviewView(
            entry: entry,
            highResDrawing: drawingImage,
            size: 600 * scale,
            scale: scale,
            logicalDisplaySize: 450,
            animateDrawing: animateDrawing,
            looping: looping
          )
          .padding()
          .background(
            RoundedRectangle(cornerRadius: 80 * scale, style: .continuous)
              .foregroundStyle(.appSurface)
          )
          .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)

          Spacer()
          Spacer()
        }

        // Date footer
        VStack {
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
    .aspectRatio(aspectRatio, contentMode: .fit)
  }
}
