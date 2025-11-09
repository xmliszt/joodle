//
//  MinimalCardStyleView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

struct MinimalCardStyleView: View {
  let entry: DayEntry?
  let date: Date
  let highResDrawing: UIImage?

  private var dateString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM d, yyyy"
    return formatter.string(from: date)
  }

  private var weekdayString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date)
  }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / 1080.0

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
          } else if let entry = entry, let drawingData = entry.drawingData, !drawingData.isEmpty {
            // Fallback to live Canvas rendering (for previews)
            DrawingDisplayView(
              entry: entry,
              displaySize: 450 * scale,
              dotStyle: .present,
              accent: true,
              highlighted: false,
              scale: 1.0,
              useThumbnail: false
            )
            .frame(width: 600 * scale, height: 600 * scale)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 80 * scale, style: .continuous)
                .foregroundStyle(.appSurface)
            )
          } else if let entry = entry, !entry.body.isEmpty {
            // Show text
            Text(entry.body)
              .font(.custom(size: 48 * scale))
              .foregroundColor(.textColor)
              .lineLimit(10)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 80 * scale)
          } else {
            // Empty state
            Image(systemName: "scribble")
              .font(.custom(size: 120 * scale))
              .foregroundColor(.textColor.opacity(0.3))
          }

          Spacer()

        }
        // Date footer
        VStack {
          Spacer()
          VStack {
            Text(dateString)
              .font(.custom(size: 64 * scale))
              .foregroundColor(.textColor)
            Spacer()
            Text(weekdayString)
              .font(.custom(size: 52 * scale))
              .foregroundColor(.secondaryTextColor)
          }
          .padding(.top, 30 * scale)
          .padding(.bottom, 80 * scale)
          .padding(.horizontal, 80 * scale)
        }
      }
      .frame(width: size.width, height: size.height)
    }
    .aspectRatio(1.0, contentMode: .fit)
  }
}

#Preview("With Drawing") {
  MinimalCardStyleView(
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
  MinimalCardStyleView(
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
  MinimalCardStyleView(
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
  MinimalCardStyleView(
    entry: nil,
    date: Date(),
    highResDrawing: nil
  )
  .frame(width: 300, height: 300)
  // add border
  .border(Color.black)
}
