//
//  YearGridDotsView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// Data structure for year grid share card entries
struct ShareCardDayEntry: Identifiable {
  var id: String { dateString }
  let dateString: String
  let date: Date
  let hasEntry: Bool
  let thumbnail: Data?
  let drawingData: Data?

  init(from dayEntry: DayEntry) {
    self.dateString = dayEntry.dateString
    self.date = dayEntry.displayDate
    self.hasEntry = !dayEntry.body.isEmpty || (dayEntry.drawingData != nil && !dayEntry.drawingData!.isEmpty)
    self.thumbnail = dayEntry.drawingThumbnail20
    self.drawingData = dayEntry.drawingData
  }

  init(dateString: String, date: Date, hasEntry: Bool = false, thumbnail: Data? = nil, drawingData: Data? = nil) {
    self.dateString = dateString
    self.date = date
    self.hasEntry = hasEntry
    self.thumbnail = thumbnail
    self.drawingData = drawingData
  }
}

/// Date item for year grid
struct ShareCardDateItem: Identifiable {
  var id: String
  var date: Date
}

/// Dot view for share cards - wrapper around shared DoodleRendererView
struct ShareCardDotView: View {
  let size: CGFloat
  let hasEntry: Bool
  let dotStyle: DoodleDotStyle
  var thumbnail: Data? = nil
  var drawingData: Data? = nil

  var body: some View {
    DoodleRendererView(
      size: size,
      hasEntry: hasEntry,
      dotStyle: dotStyle,
      drawingData: drawingData,
      thumbnail: thumbnail,
      strokeColor: .appAccent,
      strokeMultiplier: 3.0,
      renderScale: 2.0
    )
  }
}

struct YearGridDotsView: View {
  private let cardStyle: ShareCardStyle = .yearGridDots
  let year: Int
  let percentage: Double
  let entries: [ShareCardDayEntry]
  var showWatermark: Bool = true

  // Base dimensions for 1080x1080 card
  private let baseDotSize: CGFloat = 26
  private let baseHorizontalPadding: CGFloat = 60
  private let baseTopPadding: CGFloat = 60
  private let baseBottomPadding: CGFloat = 40
  private let baseHeaderSpacing: CGFloat = 32
  private let baseFontSize: CGFloat = 56
  private let baseMinSpacing: CGFloat = 20

  private var dateItems: [ShareCardDateItem] {
    let calendar = Calendar.current
    guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
      return []
    }

    let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count ?? 365

    return (0..<daysInYear).map { dayOffset in
      let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear)!
      return ShareCardDateItem(
        id: "\(dayOffset)",
        date: date
      )
    }
  }

  private var todayStart: Date {
    Calendar.current.startOfDay(for: Date())
  }

  private var entriesByDateKey: [String: ShareCardDayEntry] {
    var lookup: [String: ShareCardDayEntry] = [:]
    lookup.reserveCapacity(entries.count)
    for entry in entries {
      lookup[entry.dateString] = entry
    }
    return lookup
  }

  private func calculateGridLayout(availableWidth: CGFloat, scale: CGFloat) -> (dotsPerRow: Int, dotSize: CGFloat, spacing: CGFloat) {
    let scaledDotSize = baseDotSize * scale
    let scaledMinSpacing = baseMinSpacing * scale

    // Calculate how many dots can fit in a row
    let dotsPerRow = max(1, Int((availableWidth + scaledMinSpacing) / (scaledDotSize + scaledMinSpacing)))

    // Calculate actual spacing to distribute dots evenly
    let totalDotWidth = CGFloat(dotsPerRow) * scaledDotSize
    let totalSpacing = availableWidth - totalDotWidth
    let spacing = dotsPerRow > 1 ? totalSpacing / CGFloat(dotsPerRow - 1) : 0

    return (dotsPerRow, scaledDotSize, spacing)
  }

  private func numberOfRows(dotsPerRow: Int) -> Int {
    let totalDays = dateItems.count
    return (totalDays + dotsPerRow - 1) / dotsPerRow
  }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / cardStyle.cardSize.width

      let horizontalPadding = baseHorizontalPadding * scale
      let topPadding = baseTopPadding * scale
      let bottomPadding = baseBottomPadding * scale
      let headerSpacing = baseHeaderSpacing * scale
      let fontSize = baseFontSize * scale

      let availableWidth = size.width - (horizontalPadding * 2)
      let layout = calculateGridLayout(availableWidth: availableWidth, scale: scale)

      ZStack {
        // Background
        Color.backgroundColor

        VStack(alignment: .leading, spacing: headerSpacing) {
          // Header
          HStack {
            Text(String(year))
              .font(.system(size: fontSize, weight: .semibold))
              .foregroundColor(.primary)

            Spacer()

            Text(String(format: "%.1f%%", percentage))
              .font(.system(size: fontSize, weight: .semibold))
              .foregroundColor(.appAccent)
          }
          .padding(.horizontal, horizontalPadding)

          // Grid
          VStack(alignment: .leading, spacing: layout.spacing) {
            ForEach(0..<numberOfRows(dotsPerRow: layout.dotsPerRow), id: \.self) { rowIndex in
              createRow(
                for: rowIndex,
                dotsPerRow: layout.dotsPerRow,
                spacing: layout.spacing,
                dotSize: layout.dotSize
              )
            }
          }
          .padding(.horizontal, horizontalPadding)

          Spacer(minLength: 0)
        }
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)

        // Watermark - bottom right corner
        if showWatermark {
          MushroomWatermarkView(scale: scale)
        }
      }
      .frame(width: size.width, height: size.height)
    }
    .aspectRatio(1, contentMode: .fit)
  }

  @ViewBuilder
  private func createRow(for rowIndex: Int, dotsPerRow: Int, spacing: CGFloat, dotSize: CGFloat) -> some View {
    let rowStart = rowIndex * dotsPerRow
    let rowEnd = min(rowStart + dotsPerRow, dateItems.count)

    if rowStart < dateItems.count {
      HStack(spacing: spacing) {
        ForEach(rowStart..<rowEnd, id: \.self) { index in
          let item = dateItems[index]
          let dotStyle = getDotStyle(for: item.date)
          let dayEntry = getEntryForDate(item.date)
          let hasEntry = dayEntry?.hasEntry ?? false

          ShareCardDotView(
            size: dotSize,
            hasEntry: hasEntry,
            dotStyle: dotStyle,
            thumbnail: nil // Dots view doesn't show thumbnails
          )
        }

        // Add spacer for the last row if it's not full
        if rowEnd - rowStart < dotsPerRow {
          Spacer(minLength: 0)
        }
      }
    }
  }

  private func getDotStyle(for date: Date) -> DoodleDotStyle {
    if date < todayStart {
      return .past
    } else if Calendar.current.isDate(date, inSameDayAs: todayStart) {
      return .present
    }
    return .future
  }

  private func getEntryForDate(_ date: Date) -> ShareCardDayEntry? {
    let dateString = DayEntry.dateToString(date)
    return entriesByDateKey[dateString]
  }
}

/// Helper function to create mock year entries for previews
func createMockYearEntries(year: Int, entryCount: Int) -> [ShareCardDayEntry] {
  let calendar = Calendar.current
  guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
    return []
  }

  let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count ?? 365
  var entries: [ShareCardDayEntry] = []

  // Create entries for random days up to today
  let today = Date()
  var validDays: [Int] = []

  for dayOffset in 0..<daysInYear {
    if let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear),
       date <= today {
      validDays.append(dayOffset)
    }
  }

  let daysWithEntries = Set(validDays.shuffled().prefix(min(entryCount, validDays.count)))

  for dayOffset in daysWithEntries {
    let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear)!
    let dateString = DayEntry.dateToString(date)
    entries.append(ShareCardDayEntry(
      dateString: dateString,
      date: date,
      hasEntry: true,
      thumbnail: nil
    ))
  }

  return entries
}

#Preview("Year Grid Dots - Current Year") {
  YearGridDotsView(
    year: 2025,
    percentage: 45.2,
    entries: createMockYearEntries(year: 2025, entryCount: 120)
  )
  .frame(width: 300, height: 300)
  .border(Color.gray)
}

#Preview("Year Grid Dots - Full Size") {
  YearGridDotsView(
    year: 2025,
    percentage: 45.2,
    entries: createMockYearEntries(year: 2025, entryCount: 120)
  )
  .frame(width: 1080, height: 1080)
}

#Preview("Year Grid Dots - Empty") {
  YearGridDotsView(
    year: 2025,
    percentage: 0.0,
    entries: []
  )
  .frame(width: 300, height: 300)
  .border(Color.gray)
}
