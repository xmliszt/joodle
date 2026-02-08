import SwiftUI

struct DetailedView: View {
  private let cardStyle: ShareCardStyle = .detailed
  let entry: DayEntry?
  let date: Date
  let highResDrawing: UIImage?
  var showWatermark: Bool = true

  private var dateString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, dd MMM yyyy"
    return formatter.string(from: date)
  }

  private var hasDrawing: Bool {
    entry?.drawingData != nil || highResDrawing != nil
  }

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / cardStyle.cardSize.width
      let imageSize: CGFloat = 200 * scale
      let imagePadding: CGFloat = 32 * scale
      let totalImageSize = imageSize + imagePadding * 2
      let outerPadding: CGFloat = 60 * scale
      let dateHeight: CGFloat = 60 * scale
      let contentWidth = size.width - outerPadding * 2 - 20 * scale
      let contentHeight = size.height - outerPadding * 2 - dateHeight - 24 * scale

      ZStack(alignment: .topLeading) {
        // Background
        (colorScheme == .dark ? Color.black : Color.white)
          .ignoresSafeArea()

        VStack(spacing: 24 * scale) {
          // Text content that wraps around the image
          ExclusionTextView(
            text: entry?.body ?? "",
            font: .appFont(ofSize: 40 * scale),
            textColor: UIColor.label,
            lineSpacing: 4 * scale,
            exclusionRect: hasDrawing ? CGRect(
              x: 0,
              y: 0,
              width: totalImageSize + 64 * scale,
              height: totalImageSize + 16 * scale
            ) : .zero
          )
          .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
          .clipped()
        }
        .padding(.horizontal, outerPadding)
        .padding(.vertical, outerPadding)
        .padding(.trailing, 20 * scale)

        // Date at the bottom right
        HStack (alignment: .bottom) {
          VStack (alignment: .trailing) {
            Spacer()
            Text(dateString)
              .font(.appFont(size: 32 * scale))
              .foregroundColor(.appTextSecondary)
          }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(40 * scale)
        
        // Joodle image overlay in top-left corner
        if hasDrawing {
          DrawingPreviewView(
            entry: entry,
            highResDrawing: highResDrawing,
            size: 200,
            scale: scale,
          )
          .background(
            RoundedRectangle(cornerRadius: 50 * scale, style: .continuous)
              .foregroundStyle(.appSurface)
          )
          .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
          .padding(.leading, outerPadding)
          .padding(.top, outerPadding)
        }

        // Watermark - bottom LEFT corner
        if showWatermark {
          MushroomWatermarkView(scale: scale, alignment: .bottomLeading)
        }
      }
    }
    .aspectRatio(cardStyle.cardSize.width / cardStyle.cardSize.height, contentMode: .fit)
    .clipped()
  }
}

/// A UIViewRepresentable that renders text with an exclusion zone using TextKit
struct ExclusionTextView: UIViewRepresentable {
  let text: String
  let font: UIFont
  let textColor: UIColor
  let lineSpacing: CGFloat
  let exclusionRect: CGRect

  func makeUIView(context: Context) -> ExclusionTextUIView {
    let view = ExclusionTextUIView()
    view.backgroundColor = .clear
    view.isOpaque = false
    return view
  }

  func updateUIView(_ uiView: ExclusionTextUIView, context: Context) {
    uiView.text = text
    uiView.font = font
    uiView.textColor = textColor
    uiView.lineSpacing = lineSpacing
    uiView.exclusionRect = exclusionRect
    uiView.setNeedsDisplay()
  }
}

/// Custom UIView that draws text with exclusion paths using TextKit
class ExclusionTextUIView: UIView {
  var text: String = ""
  var font: UIFont = .appFont(ofSize: 16)
  var textColor: UIColor = .label
  var lineSpacing: CGFloat = 4
  var exclusionRect: CGRect = .zero

  override func draw(_ rect: CGRect) {
    super.draw(rect)

    guard !text.isEmpty else { return }

    // Create the text storage with attributed string
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = lineSpacing
    paragraphStyle.lineBreakMode = .byWordWrapping

    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: textColor,
      .paragraphStyle: paragraphStyle
    ]

    let attributedString = NSAttributedString(string: text, attributes: attributes)
    let textStorage = NSTextStorage(attributedString: attributedString)

    // Create the layout manager
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)

    // Create the text container with the view's bounds
    let textContainer = NSTextContainer(size: bounds.size)
    textContainer.lineFragmentPadding = 0
    textContainer.lineBreakMode = .byWordWrapping

    // Add exclusion path if needed
    if exclusionRect != .zero {
      let exclusionPath = UIBezierPath(rect: exclusionRect)
      textContainer.exclusionPaths = [exclusionPath]
    }

    layoutManager.addTextContainer(textContainer)

    // Calculate the glyph range and draw
    let glyphRange = layoutManager.glyphRange(for: textContainer)
    layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
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
      body: "Today was amazing! I learned so much and felt really productive. The weather was beautiful and I went for a long walk in the park. I also finished reading that book I've been working on.",
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

#Preview("With Drawing & Long Text") {
  DetailedView(
    entry: DayEntry(
      body: "Today was amazing! I learned so much and felt really productive. The weather was beautiful and I went for a long walk in the park. I also finished reading that book I've been working on. Later in the evening, I cooked a delicious dinner and watched a great movie. It was truly a perfect day from start to finish! Today was amazing! I learned so much and felt really productive. The weather was beautiful and I went for a long walk in the park. I also finished reading that book I've been working on. Later in the evening, I cooked a delicious dinner and watched a great movie. It was truly a perfect day from start to finish! Today was amazing! I learned so much and felt really productive. The weather was beautiful and I went for a long walk in the park. I also finished reading that book I've been working on. Later in the evening, I cooked a delicious dinner and watched a great movie. It was truly a perfect day from start to finish!",
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

#Preview("Without Watermark") {
  DetailedView(
    entry: DayEntry(
      body: "Today was amazing! I learned so much and felt really productive.",
      createdAt: Date(),
      drawingData: createMockDrawingData()
    ),
    date: Date(),
    highResDrawing: nil,
    showWatermark: false
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
