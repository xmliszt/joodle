//
//  MonthGridView.swift
//  Joodle
//
//  Created by Li Yuxuan on 14/2/26.
//

import SwiftUI

struct MonthGridView: View {
  private let cardStyle: ShareCardStyle = .monthGrid
  let year: Int
  let month: Int
  let startOfWeek: String
  let entries: [DayEntry]
  var highResDrawings: [String: UIImage] = [:]
  var showWatermark: Bool = true
  var strokeMultiplier: CGFloat = 1.0

  // Base dimensions for 1080×1080 card
  private let baseHorizontalPadding: CGFloat = 60
  private let baseTopPadding: CGFloat = 60
  private let baseBottomPadding: CGFloat = 40
  private let baseHeaderSpacing: CGFloat = 32
  private let baseFontSize: CGFloat = 56
  private let baseMonthFontSize: CGFloat = 56
  private let baseLabelFontSize: CGFloat = 28
  private let baseCellCornerRadius: CGFloat = 16
  private let baseCellSpacing: CGFloat = 12
  private let baseLabelSpacing: CGFloat = 12

  @Environment(\.colorScheme) private var colorScheme

  /// Weekday labels based on `startOfWeek` preference
  private var weekdayLabels: [String] {
    startOfWeek.lowercased() == "monday"
      ? ["M", "T", "W", "T", "F", "S", "S"]
      : ["S", "M", "T", "W", "T", "F", "S"]
  }

  /// Month name string
  private var monthName: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM"
    let components = DateComponents(year: year, month: month, day: 1)
    guard let date = Calendar.current.date(from: components) else { return "" }
    return formatter.string(from: date)
  }

  /// Number of days in the month
  private var daysInMonth: Int {
    let calendar = Calendar.current
    let components = DateComponents(year: year, month: month)
    guard let date = calendar.date(from: components) else { return 30 }
    return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
  }

  /// Number of leading empty cells before day 1
  private var leadingEmptyCells: Int {
    let calendar = Calendar.current
    guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
      return 0
    }
    // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    let weekday = calendar.component(.weekday, from: firstOfMonth)

    if startOfWeek.lowercased() == "sunday" {
      return weekday - 1
    } else {
      // Monday start: (weekday - 2 + 7) % 7
      return (weekday - 2 + 7) % 7
    }
  }

  /// Total grid cells (leading empties + days in month)
  private var totalCells: Int {
    leadingEmptyCells + daysInMonth
  }

  /// Number of rows needed
  private var numberOfRows: Int {
    (totalCells + 6) / 7
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
      let monthFontSize = baseMonthFontSize * scale
      let labelFontSize = baseLabelFontSize * scale
      let cellSpacing = baseCellSpacing * scale
      let cellCornerRadius = baseCellCornerRadius * scale
      let labelSpacing = baseLabelSpacing * scale

      let availableWidth = size.width - (horizontalPadding * 2)
      let cellSize = (availableWidth - cellSpacing * 6) / 7

      ZStack {
        // Background
        (colorScheme == .dark ? Color.black : Color.white)

        VStack(spacing: headerSpacing) {
          // Header: year (left) + month name (right)
          HStack {
            Text(String(year))
              .font(.appFont(size: fontSize, weight: .semibold))
              .foregroundColor(.primary)

            Spacer()

            Text(monthName)
              .font(.appFont(size: monthFontSize, weight: .semibold))
              .foregroundColor(.primary)
          }
          .padding(.horizontal, horizontalPadding)

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

            // Calendar grid
            VStack(spacing: cellSpacing) {
              ForEach(0..<numberOfRows, id: \.self) { rowIndex in
                HStack(spacing: cellSpacing) {
                  ForEach(0..<7, id: \.self) { colIndex in
                    let cellIndex = rowIndex * 7 + colIndex
                    let dayNumber = cellIndex - leadingEmptyCells + 1

                    if dayNumber >= 1 && dayNumber <= daysInMonth {
                      let date = dateForDay(dayNumber)
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
                    } else {
                      // Empty cell (leading/trailing)
                      Color.clear
                        .frame(width: cellSize, height: cellSize)
                    }
                  }
                }
                .padding(.horizontal, horizontalPadding)
              }
            }
          }

          Spacer(minLength: 0)
        }
        .padding(.top, topPadding)

        // Watermark
        if showWatermark {
          MushroomWatermarkView(scale: scale)
        }
      }
      .frame(width: size.width, height: size.height)
    }
    .aspectRatio(1, contentMode: .fit)
  }

  private func dateForDay(_ day: Int) -> Date {
    let components = DateComponents(year: year, month: month, day: day)
    return Calendar.current.date(from: components) ?? Date()
  }

  private func getEntryForDate(_ date: Date) -> DayEntry? {
    let dateString = CalendarDate.from(date).dateString
    return entriesByDateKey[dateString]
  }
}

// MARK: - Preview Helpers

private func createMockMonthDayEntries(year: Int, month: Int) -> [DayEntry] {
  let calendar = Calendar.current
  guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
    return []
  }
  let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
  var entries: [DayEntry] = []

  // Create entries for roughly half the days
  let daysWithEntries = Set((1...daysInMonth).shuffled().prefix(daysInMonth / 2))

  for day in daysWithEntries {
    if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
      entries.append(DayEntry(
        body: "",
        createdAt: date,
        drawingData: createMockDrawingData()
      ))
    }
  }

  return entries
}

#Preview("Month Grid - February 2026 (Sunday Start)") {
  MonthGridView(
    year: 2026,
    month: 2,
    startOfWeek: "sunday",
    entries: createMockMonthDayEntries(year: 2026, month: 2)
  )
  .frame(width: 300, height: 300)
  .border(Color.gray)
}

#Preview("Month Grid - February 2026 (Monday Start)") {
  MonthGridView(
    year: 2026,
    month: 2,
    startOfWeek: "monday",
    entries: createMockMonthDayEntries(year: 2026, month: 2)
  )
  .frame(width: 300, height: 300)
  .border(Color.gray)
}

#Preview("Month Grid - Full Size") {
  MonthGridView(
    year: 2026,
    month: 2,
    startOfWeek: "sunday",
    entries: createMockMonthDayEntries(year: 2026, month: 2)
  )
  .frame(width: 1080, height: 1080)
}

#Preview("Month Grid - Empty") {
  MonthGridView(
    year: 2026,
    month: 2,
    startOfWeek: "sunday",
    entries: []
  )
  .frame(width: 300, height: 300)
  .border(Color.gray)
}
