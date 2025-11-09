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

      VStack(spacing: 48) {
        Spacer()

        // Date header - centered
        VStack(spacing: 12) {
          Text(weekdayString)
            .font(.customHeadline)
            .foregroundColor(.appPrimary)

          Rectangle()
            .fill(.appPrimary.opacity(0.3))
            .frame(width: 60, height: 2)

          Text(dateString)
            .font(.customSubheadline)
            .foregroundColor(.secondaryTextColor)
        }

        // Drawing
        if let entry = entry, let drawingData = entry.drawingData, !drawingData.isEmpty {
          DrawingDisplayView(
            entry: entry,
            displaySize: 450,
            dotStyle: .present,
            accent: true,
            highlighted: false,
            scale: 1.0,
            useThumbnail: false
          )
          .frame(width: 450, height: 450)
          .background(.appSurface)
          .clipShape(RoundedRectangle(cornerRadius: 32))
          .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        }

        // Body text
        if let entry = entry, !entry.body.isEmpty {
          Text(entry.body)
            .font(.customBody)
            .foregroundColor(.textColor)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 80)
        }

        Spacer()

        // Footer branding
        VStack(spacing: 8) {
          Circle()
            .fill(.appPrimary)
            .frame(width: 8, height: 8)

          Text("GoodDay")
            .font(.customSubheadline)
            .foregroundColor(.secondaryTextColor.opacity(0.6))
        }
        .padding(.bottom, 40)
      }
      .padding(60)
    }
    .frame(width: 1080, height: 1920)
  }
}

#Preview("With Drawing and Text") {
  ClassicCardStyleView(
    entry: DayEntry(
      body: "Today was a wonderful day filled with new experiences and learning opportunities. Every moment counts.",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("Text Only") {
  ClassicCardStyleView(
    entry: DayEntry(
      body: "Sometimes the simplest days are the most memorable ones. Today was one of those days.",
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
