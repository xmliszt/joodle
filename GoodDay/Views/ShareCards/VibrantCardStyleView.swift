//
//  VibrantCardStyleView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

struct VibrantCardStyleView: View {
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
      // Gradient background
      LinearGradient(
        gradient: Gradient(colors: [
          .appPrimary.opacity(0.8),
          .appSecondary.opacity(0.6),
          .appPrimary.opacity(0.4),
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 40) {
        // Date header with bold style
        VStack(alignment: .leading, spacing: 16) {
          Text(weekdayString.uppercased())
            .font(.system(size: 32, weight: .black))
            .foregroundColor(.white)
            .tracking(4)

          Text(dateString)
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
        }
        .padding(.top, 80)

        Spacer()

        // Content area with white background card
        VStack(alignment: .leading, spacing: 32) {
          // Drawing
          if let entry = entry, let drawingData = entry.drawingData, !drawingData.isEmpty {
            HStack {
              Spacer()
              DrawingDisplayView(
                entry: entry,
                displaySize: 380,
                dotStyle: .present,
                accent: true,
                highlighted: false,
                scale: 1.0,
                useThumbnail: false
              )
              .frame(width: 380, height: 380)
              Spacer()
            }
          }

          // Body text
          if let entry = entry, !entry.body.isEmpty {
            Text(entry.body)
              .font(.system(size: 28, weight: .medium))
              .foregroundColor(.primary)
              .lineLimit(nil)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(48)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 40))
        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)

        Spacer()

        // Footer
        HStack {
          Spacer()
          VStack(spacing: 8) {
            Circle()
              .fill(.white)
              .frame(width: 10, height: 10)

            Text("GoodDay")
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.white.opacity(0.9))
          }
        }
        .padding(.bottom, 60)
      }
      .padding(.horizontal, 80)
    }
    .frame(width: 1080, height: 1920)
  }
}

#Preview("With Drawing and Text") {
  VibrantCardStyleView(
    entry: DayEntry(
      body: "Feeling energized and motivated! Today brought so many opportunities and I'm grateful for every single one of them.",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("Text Only") {
  VibrantCardStyleView(
    entry: DayEntry(
      body: "Bold moves lead to bold results. Today was proof of that!",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("Empty") {
  VibrantCardStyleView(
    entry: nil,
    date: Date()
  )
}
