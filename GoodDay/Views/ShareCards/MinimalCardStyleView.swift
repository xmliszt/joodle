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

  private var dateString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM d"
    return formatter.string(from: date)
  }

  private var weekdayString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date)
  }

  var body: some View {
    ZStack {
      // Background
      Color.backgroundColor
        .ignoresSafeArea()

      VStack(spacing: 0) {
        Spacer()

        // Main content - Drawing or Text
        if let entry = entry, let drawingData = entry.drawingData, !drawingData.isEmpty {
          // Show drawing
          DrawingDisplayView(
            entry: entry,
            displaySize: 600,
            dotStyle: .present,
            accent: true,
            highlighted: false,
            scale: 1.0,
            useThumbnail: false
          )
          .frame(width: 600, height: 600)
        } else if let entry = entry, !entry.body.isEmpty {
          // Show text
          Text(entry.body)
            .font(.system(size: 48, weight: .regular))
            .foregroundColor(.textColor)
            .lineLimit(10)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 80)
        } else {
          // Empty state
          Image(systemName: "scribble")
            .font(.system(size: 120))
            .foregroundColor(.textColor.opacity(0.3))
        }

        Spacer()

        // Date footer
        VStack(spacing: 8) {
          Text(dateString)
            .font(.system(size: 32, weight: .medium))
            .foregroundColor(.textColor)

          Text(weekdayString)
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(.secondaryTextColor)
        }
        .padding(.bottom, 80)
      }
    }
    .frame(width: 1080, height: 1080)
  }
}

#Preview("With Drawing") {
  MinimalCardStyleView(
    entry: DayEntry(
      body: "",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("With Text") {
  MinimalCardStyleView(
    entry: DayEntry(
      body: "Today was amazing! I learned so much and felt really productive.",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("Empty") {
  MinimalCardStyleView(
    entry: nil,
    date: Date()
  )
}
