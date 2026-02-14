//
//  WeekGridView.swift
//  Joodle
//
//  Created by Li Yuxuan on 14/2/26.
//

import SwiftUI

struct WeekGridView: View {
  private let cardStyle: ShareCardStyle = .weekGrid
  let year: Int
  let weekStartDate: Date
  let startOfWeek: String
  let entries: [DayEntry]
  var highResDrawings: [String: UIImage] = [:]
  var showWatermark: Bool = true
  var strokeMultiplier: CGFloat = 1.0

  // Base dimensions for 1920×1080 card
  private let baseHorizontalPadding: CGFloat = 80
  private let baseTopPadding: CGFloat = 60
  private let baseBottomPadding: CGFloat = 40
  private let baseHeaderSpacing: CGFloat = 40
  private let baseFontSize: CGFloat = 56
  private let baseLabelFontSize: CGFloat = 36
  private let baseCellCornerRadius: CGFloat = 24
  private let baseCellSpacing: CGFloat = 24
  private let baseLabelSpacing: CGFloat = 16

  @Environment(\.colorScheme) private var colorScheme

  /// The 7 days of the week starting from `weekStartDate`
  private var weekDates: [Date] {
    (0..<7).compactMap { offset in
      Calendar.current.date(byAdding: .day, value: offset, to: weekStartDate)
    }
  }

  /// Weekday labels based on `startOfWeek` preference
  private var weekdayLabels: [String] {
    startOfWeek.lowercased() == "monday"
      ? ["M", "T", "W", "T", "F", "S", "S"]
      : ["S", "M", "T", "W", "T", "F", "S"]
  }

  /// Format the date range string, e.g. "Feb 9 - Feb 15"
  private var dateRangeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    guard let lastDate = weekDates.last else { return "" }
    return "\(formatter.string(from: weekStartDate)) - \(formatter.string(from: lastDate))"
  }

  /// The unscaled cell size at base card resolution
  private var baseCellSize: CGFloat {
    (cardStyle.cardSize.width - baseHorizontalPadding * 2 - baseCellSpacing * 6) / 7
  }

  private var entriesByDateKey: [String: DayEntry] {
    var lookup: [String: DayEntry] = [:]
    lookup.reserveCapacity(entries.count)
    for entry in entries {
      lookup[entry.dateString] = entry
    }
    return lookup
  }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / cardStyle.cardSize.width

      let horizontalPadding = baseHorizontalPadding * scale
      let topPadding = baseTopPadding * scale
      let headerSpacing = baseHeaderSpacing * scale
      let fontSize = baseFontSize * scale
      let labelFontSize = baseLabelFontSize * scale
      let cellSpacing = baseCellSpacing * scale
      let cellCornerRadius = baseCellCornerRadius * scale
      let labelSpacing = baseLabelSpacing * scale

      let availableWidth = size.width - (horizontalPadding * 2)
      let cellSize = (availableWidth - cellSpacing * 6) / 7

      ZStack {
        // Background
        (colorScheme == .dark ? Color.black : Color.white)

        VStack(alignment: .leading, spacing: headerSpacing) {
          // Header row: year (left), date range (right)
          HStack {
            Text(String(year))
              .font(.appFont(size: fontSize, weight: .semibold))
              .foregroundColor(.primary)

            Spacer()

            Text(dateRangeString)
              .font(.appFont(size: fontSize, weight: .semibold))
              .foregroundColor(.primary)
          }
          .padding(.horizontal, horizontalPadding)
          
        
          Spacer()

          VStack(spacing: labelSpacing) {
            // Weekday labels
            HStack(spacing: cellSpacing) {
              ForEach(0..<7, id: \.self) { index in
                Text(weekdayLabels[index])
                  .font(.appFont(size: labelFontSize, weight: .medium))
                  .foregroundColor(.secondary)
                  .frame(width: cellSize)
              }
            }
            .padding(.horizontal, horizontalPadding)

            // Doodle cells
            HStack(spacing: cellSpacing) {
              ForEach(0..<7, id: \.self) { index in
                let date = weekDates[index]
                let dayEntry = getEntryForDate(date)

                ZStack {
                  RoundedRectangle(cornerRadius: cellCornerRadius)
                    .fill(colorScheme == .dark
                      ? Color.white.opacity(0.08)
                      : Color.appSurface)

                  if let dayEntry = dayEntry {
                    DrawingPreviewView(
                      entry: dayEntry,
                      highResDrawing: highResDrawings[dayEntry.dateString],
                      size: baseCellSize,
                      scale: scale,
                      strokeMultiplier: strokeMultiplier
                    )
                  }
                }
                .frame(width: cellSize, height: cellSize)
                .clipShape(RoundedRectangle(cornerRadius: cellCornerRadius))
              }
            }
            .padding(.horizontal, horizontalPadding)
          }

          Spacer()
          Spacer()
        }
        .padding(.top, topPadding)

        // Watermark
        if showWatermark {
          MushroomWatermarkView(scale: scale)
        }
      }
      .frame(width: size.width, height: size.height)
    }
    .aspectRatio(cardStyle.cardSize.width / cardStyle.cardSize.height, contentMode: .fit)
  }

  private func getEntryForDate(_ date: Date) -> DayEntry? {
    let dateString = CalendarDate.from(date).dateString
    return entriesByDateKey[dateString]
  }
}

// MARK: - Preview Helpers

private func createMockWeekDayEntries(weekStart: Date) -> [DayEntry] {
  let calendar = Calendar.current
  var entries: [DayEntry] = []

  // Create entries for some days in the week
  for dayOffset in [0, 2, 3, 5] {
    if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
      entries.append(DayEntry(
        body: "",
        createdAt: date,
        drawingData: createMockDrawingData()
      ))
    }
  }

  return entries
}

private func currentWeekStart(startOfWeek: String) -> Date {
  let calendar = Calendar.current
  let today = Date()
  let weekday = calendar.component(.weekday, from: today)

  let offset: Int
  if startOfWeek.lowercased() == "monday" {
    // Monday = 2, so offset = (weekday - 2 + 7) % 7
    offset = (weekday - 2 + 7) % 7
  } else {
    // Sunday = 1, so offset = weekday - 1
    offset = weekday - 1
  }

  return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: today))!
}

#Preview("Week Grid - Monday Start") {
  let weekStart = currentWeekStart(startOfWeek: "monday")
  WeekGridView(
    year: 2026,
    weekStartDate: weekStart,
    startOfWeek: "monday",
    entries: createMockWeekDayEntries(weekStart: weekStart)
  )
  .frame(width: 300, height: 150)
  .border(Color.gray)
}

#Preview("Week Grid - Sunday Start") {
  let weekStart = currentWeekStart(startOfWeek: "sunday")
  WeekGridView(
    year: 2026,
    weekStartDate: weekStart,
    startOfWeek: "sunday",
    entries: createMockWeekDayEntries(weekStart: weekStart)
  )
  .frame(width: 300, height: 150)
  .border(Color.gray)
}

#Preview("Week Grid - Full Size") {
  let weekStart = currentWeekStart(startOfWeek: "monday")
  WeekGridView(
    year: 2026,
    weekStartDate: weekStart,
    startOfWeek: "monday",
    entries: createMockWeekDayEntries(weekStart: weekStart)
  )
  .frame(width: 1920, height: 960)
}

#Preview("Week Grid - Empty") {
  let weekStart = currentWeekStart(startOfWeek: "monday")
  WeekGridView(
    year: 2026,
    weekStartDate: weekStart,
    startOfWeek: "monday",
    entries: []
  )
  .frame(width: 300, height: 150)
  .border(Color.gray)
}
