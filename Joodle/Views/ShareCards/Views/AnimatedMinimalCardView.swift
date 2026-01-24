import SwiftUI

struct AnimatedMinimalCardView: View {
  let entry: DayEntry?
  let drawingImage: UIImage?
  let cardSize: CGSize
  var showWatermark: Bool = true
  var animateDrawing: Bool = true
  var looping: Bool = true

  private var aspectRatio: CGFloat {
    guard cardSize.height != 0 else { return 1 }
    return cardSize.width / cardSize.height
  }

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / cardSize.width

      ZStack {
        // Background
        (colorScheme == .dark ? Color.black : Color.white)
          .ignoresSafeArea()

        VStack {
          DrawingPreviewView(
            entry: entry,
            highResDrawing: drawingImage,
            size: 800 * scale,
            scale: scale,
            logicalDisplaySize: 800,
            animateDrawing: animateDrawing,
            looping: looping
          )
          .padding()
          .background(
            RoundedRectangle(cornerRadius: 80 * scale, style: .continuous)
              .foregroundStyle(.appSurface)
          )
          .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
        }

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
