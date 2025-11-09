//
//  ClassicCardStyleView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

struct ClassicCardStyleView: View {
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
        // Date header at top
        VStack(spacing: 8) {
          Text(weekdayString)
            .font(.system(size: 28, weight: .medium))
            .foregroundColor(.textColor)

          Text(dateString)
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(.secondaryTextColor)
        }
        .padding(.top, 60)
        .padding(.bottom, 40)

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
            .font(.system(size: 42, weight: .regular))
            .foregroundColor(.textColor)
            .lineLimit(15)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 80)
        } else {
          // Empty state
          Image(systemName: "scribble")
            .font(.system(size: 100))
            .foregroundColor(.textColor.opacity(0.3))
        }

        Spacer()

        // Footer branding
        Text("GoodDay")
          .font(.system(size: 20, weight: .regular))
          .foregroundColor(.secondaryTextColor.opacity(0.5))
          .padding(.bottom, 60)
      }
    }
    .frame(width: 1080, height: 1350)
  }
}

#Preview("With Drawing") {
  ClassicCardStyleView(
    entry: DayEntry(
      body: "",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("With Text") {
  ClassicCardStyleView(
    entry: DayEntry(
      body: "Today was a wonderful day filled with new experiences and learning opportunities.",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("Empty") {
  ClassicCardStyleView(
    entry: nil,
    date: Date()
  )
}
