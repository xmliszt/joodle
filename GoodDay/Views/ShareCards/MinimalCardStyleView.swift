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
    formatter.dateStyle = .long
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

      VStack(alignment: .leading, spacing: 32) {
        Spacer()

        // Date header
        VStack(alignment: .leading, spacing: 8) {
          Text(weekdayString.uppercased())
            .font(.customSubheadline)
            .foregroundColor(.secondaryTextColor)
            .tracking(2)

          Text(dateString)
            .font(.customTitle)
            .foregroundColor(.textColor)
        }

        // Drawing
        if let entry = entry, let drawingData = entry.drawingData, !drawingData.isEmpty {
          DrawingDisplayView(
            entry: entry,
            displaySize: 400,
            dotStyle: .present,
            accent: true,
            highlighted: false,
            scale: 1.0,
            useThumbnail: false
          )
          .frame(width: 400, height: 400)
        }

        // Body text
        if let entry = entry, !entry.body.isEmpty {
          Text(entry.body)
            .font(.customBody)
            .foregroundColor(.textColor)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        // Footer
        HStack {
          Spacer()
          Text("GoodDay")
            .font(.customSubheadline)
            .foregroundColor(.secondaryTextColor.opacity(0.5))
        }
      }
      .padding(80)
    }
    .frame(width: 1080, height: 1920)
  }
}

#Preview("With Drawing and Text") {
  MinimalCardStyleView(
    entry: DayEntry(
      body: "Today was amazing! I learned so much and felt really productive. Looking forward to tomorrow.",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("Text Only") {
  MinimalCardStyleView(
    entry: DayEntry(
      body: "A simple note for the day. Sometimes less is more, and today proved that.",
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
