//
//  ElegantCardStyleView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

struct ElegantCardStyleView: View {
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

  private var dayNumber: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd"
    return formatter.string(from: date)
  }

  private var monthYear: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: date)
  }

  var body: some View {
    ZStack {
      // Subtle gradient background
      LinearGradient(
        gradient: Gradient(colors: [
          Color.backgroundColor,
          Color.backgroundColor.opacity(0.95),
        ]),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        // Elegant header with decorative elements
        VStack(spacing: 24) {
          // Decorative top line
          HStack(spacing: 12) {
            Rectangle()
              .fill(.appPrimary.opacity(0.3))
              .frame(width: 40, height: 1)

            Circle()
              .fill(.appPrimary.opacity(0.5))
              .frame(width: 6, height: 6)

            Rectangle()
              .fill(.appPrimary.opacity(0.3))
              .frame(width: 40, height: 1)
          }
          .padding(.top, 80)

          // Large day number
          Text(dayNumber)
            .font(.system(size: 120, weight: .thin))
            .foregroundColor(.textColor.opacity(0.2))

          // Date info
          VStack(spacing: 8) {
            Text(weekdayString.uppercased())
              .font(.system(size: 18, weight: .medium))
              .foregroundColor(.appPrimary)
              .tracking(3)

            Text(monthYear)
              .font(.system(size: 16, weight: .light))
              .foregroundColor(.secondaryTextColor)
          }
        }

        Spacer()

        // Content area
        VStack(spacing: 48) {
          // Drawing
          if let entry = entry, let drawingData = entry.drawingData, !drawingData.isEmpty {
            VStack(spacing: 0) {
              // Top decorative line
              Rectangle()
                .fill(.appPrimary.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 100)

              DrawingDisplayView(
                entry: entry,
                displaySize: 420,
                dotStyle: .present,
                accent: true,
                highlighted: false,
                scale: 1.0,
                useThumbnail: false
              )
              .frame(width: 420, height: 420)
              .padding(.vertical, 40)

              // Bottom decorative line
              Rectangle()
                .fill(.appPrimary.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 100)
            }
          }

          // Body text with elegant typography
          if let entry = entry, !entry.body.isEmpty {
            Text(entry.body)
              .font(.system(size: 26, weight: .light))
              .foregroundColor(.textColor.opacity(0.9))
              .lineLimit(nil)
              .multilineTextAlignment(.center)
              .lineSpacing(8)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 100)
          }
        }

        Spacer()

        // Footer with refined branding
        VStack(spacing: 16) {
          // Decorative separator
          HStack(spacing: 12) {
            Rectangle()
              .fill(.secondaryTextColor.opacity(0.3))
              .frame(width: 30, height: 1)

            Circle()
              .fill(.secondaryTextColor.opacity(0.4))
              .frame(width: 4, height: 4)

            Text("GoodDay")
              .font(.system(size: 16, weight: .light))
              .foregroundColor(.secondaryTextColor.opacity(0.6))
              .tracking(2)

            Circle()
              .fill(.secondaryTextColor.opacity(0.4))
              .frame(width: 4, height: 4)

            Rectangle()
              .fill(.secondaryTextColor.opacity(0.3))
              .frame(width: 30, height: 1)
          }
        }
        .padding(.bottom, 80)
      }
    }
    .frame(width: 1080, height: 1920)
  }
}

#Preview("With Drawing and Text") {
  ElegantCardStyleView(
    entry: DayEntry(
      body: "In the quiet moments of reflection, we find the greatest insights. Today reminded me of the beauty in simplicity and the power of presence.",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("Text Only") {
  ElegantCardStyleView(
    entry: DayEntry(
      body: "Grace is found not in perfection, but in the gentle acceptance of each moment as it unfolds.",
      createdAt: Date()
    ),
    date: Date()
  )
}

#Preview("Empty") {
  ElegantCardStyleView(
    entry: nil,
    date: Date()
  )
}
