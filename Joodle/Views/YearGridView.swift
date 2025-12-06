//
//  YearGridView.swift
//  Joodle
//
//  Created by Li Yuxuan on 11/8/25.
//

import SwiftUI

// MARK: - Constants
let GRID_HORIZONTAL_PADDING: CGFloat = 40
let MAX_SCALE: CGFloat = 1.5
let MAX_SCALE_DISTANCE: CGFloat = 2.5

struct DateItem: Identifiable {
  var id: String
  var date: Date
}

struct YearGridView: View {

  // MARK: Params
  /// The year to display
  let year: Int
  /// The mode to display the grid in
  let viewMode: ViewMode
  /// The spacing between dots
  let dotsSpacing: CGFloat
  /// The items to display in the grid
  let items: [DateItem]
  /// The entries to display in the grid
  let entries: [DayEntry]
  /// The id of the highlighted item
  let highlightedItemId: String?
  /// The id of the selected item
  let selectedItemId: String?

  // MARK: Cached Computed Properties
  /// Pre-computed layout metrics to avoid repeated calculations
  private var layoutMetrics: LayoutMetrics {
    let numberOfRows = (items.count + viewMode.dotsPerRow - 1) / viewMode.dotsPerRow
    let totalContentHeight = CGFloat(numberOfRows) * (viewMode.dotSize + dotsSpacing)
    return LayoutMetrics(
      numberOfRows: numberOfRows,
      totalContentHeight: totalContentHeight
    )
  }

  private struct LayoutMetrics {
    let numberOfRows: Int
    let totalContentHeight: CGFloat
  }

  /// Pre-computed today's date for comparison
  private var todayStart: Date {
    Calendar.current.startOfDay(for: Date())
  }

  // MARK: View
  var body: some View {
    let entriesByDateKey = buildEntriesLookup()

    // Find the index of the highlighted item for distance calculation
    let highlightedIndex = items.firstIndex { $0.id == highlightedItemId }

    // Split items into rows for proper grid layout
    let rows = stride(from: 0, to: items.count, by: viewMode.dotsPerRow).map { rowStart in
      Array(items[rowStart..<min(rowStart + viewMode.dotsPerRow, items.count)])
    }

    VStack(spacing: dotsSpacing) {
      ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowItems in
        HStack(alignment: .top, spacing: dotsSpacing) {
          ForEach(rowItems) { item in
            let dotStyle = getDotStyle(for: item.date)
            let entry = getEntryForDate(item.date, from: entriesByDateKey)
            let hasEntry = entry != nil && entry!.body.isEmpty == false
            let hasDrawing = entry?.drawingData != nil && !(entry?.drawingData?.isEmpty ?? true)
            let isHighlighted = highlightedItemId == item.id

            // Calculate current item index
            let currentIndex = items.firstIndex { $0.id == item.id } ?? 0

            // Calculate scale based on distance from highlighted dot
            let scale = calculateScale(
              currentIndex: currentIndex,
              highlightedIndex: highlightedIndex,
              dotsPerRow: viewMode.dotsPerRow
            )

            Group {
              if hasDrawing {
                // Show drawing instead of dot with specific frame sizes
                // Use thumbnail for performance optimization
                DrawingDisplayView(
                  entry: entry,
                  displaySize: viewMode.drawingSize,
                  dotStyle: dotStyle,
                  accent: false,
                  highlighted: isHighlighted || selectedItemId == item.id,
                  scale: scale,
                  useThumbnail: true
                )
                .frame(width: viewMode.dotSize, height: viewMode.dotSize)
              } else {
                // Show regular dot
                DotView(
                  size: viewMode.dotSize,
                  highlighted: isHighlighted || selectedItemId == item.id,
                  withEntry: hasEntry,
                  dotStyle: dotStyle,
                  scale: scale
                )
                .frame(width: viewMode.dotSize, height: viewMode.dotSize)
              }
            }
            // Stable identity based on date
            .id(item.id)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(
      .init(
        top: 0, leading: GRID_HORIZONTAL_PADDING, bottom: GRID_HORIZONTAL_PADDING,
        trailing: GRID_HORIZONTAL_PADDING)
    )
    .frame(maxWidth: .infinity, alignment: .top)
  }

  // MARK: Functions
  /// Get the style of the dot for a given date (optimized)
  private func getDotStyle(for date: Date) -> DotStyle {
    if date < todayStart {
      return .past
    } else if Calendar.current.isDate(date, inSameDayAs: todayStart) {
      return .present
    }
    return .future
  }

  /// Build a dictionary for O(1) entry lookups by date
  private func buildEntriesLookup() -> [String: DayEntry] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"

    var lookup: [String: DayEntry] = [:]
    for entry in entries {
      let dayStart = calendar.startOfDay(for: entry.createdAt)
      let key = formatter.string(from: dayStart)
      lookup[key] = entry
    }
    return lookup
  }

  /// Find the entry for a given date using pre-built lookup
  private func getEntryForDate(_ date: Date, from lookup: [String: DayEntry]) -> DayEntry? {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: date)
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let key = formatter.string(from: dayStart)
    return lookup[key]
  }

  /// Find the entry for a given date (legacy method for backward compatibility)
  private func entryForDate(_ date: Date) -> DayEntry? {
    let calendar = Calendar.current
    return entries.first { entry in
      calendar.isDate(entry.createdAt, inSameDayAs: date)
    }
  }

  /// Check if a given date is today's date (optimized)
  private func isToday(for date: Date) -> Bool {
    return Calendar.current.isDate(date, inSameDayAs: todayStart)
  }

  /// Check if a given date is in the past (before today) (optimized)
  private func isPastDay(for date: Date) -> Bool {
    return date < todayStart
  }

  /// Calculate scale for a dot based on its distance from the highlighted dot
  private func calculateScale(currentIndex: Int, highlightedIndex: Int?, dotsPerRow: Int) -> CGFloat
  {
    // If no highlighted dot, return default scale
    guard let highlightedIndex = highlightedIndex else {
      return 1.0
    }

    // Calculate row and column for both dots
    let currentRow = currentIndex / dotsPerRow
    let currentCol = currentIndex % dotsPerRow
    let highlightedRow = highlightedIndex / dotsPerRow
    let highlightedCol = highlightedIndex % dotsPerRow

    // Calculate distance
    let rowDiff = abs(currentRow - highlightedRow)
    let colDiff = abs(currentCol - highlightedCol)

    // Calculate distance with diagonal penalty
    // Adjacent dots (horizontal/vertical) = 1.0
    // Diagonal dots = 1.5 (sqrt(2) ≈ 1.414, rounded to 1.5 for smoother effect)
    let distance: CGFloat
    if rowDiff == 0 && colDiff == 0 {
      // Center dot
      distance = 0
    } else if rowDiff == 0 || colDiff == 0 {
      // Same row or column (horizontal/vertical)
      distance = CGFloat(max(rowDiff, colDiff))
    } else {
      // Diagonal - use the larger diff plus 0.5 per diagonal step
      distance = CGFloat(max(rowDiff, colDiff)) + CGFloat(min(rowDiff, colDiff)) * 0.5
    }

    // Apply decay effect
    if distance > MAX_SCALE_DISTANCE {
      return 1.0
    }

    // Linear interpolation from MAX_SCALE at distance 0 to 1.0 at MAX_SCALE_DISTANCE
    let scaleFactor = 1.0 - (distance / MAX_SCALE_DISTANCE)
    return 1.0 + (MAX_SCALE - 1.0) * scaleFactor
  }
}

#Preview {
  let calendar = Calendar.current
  let currentYear = calendar.component(.year, from: Date())

  // Generate sample items for the year
  let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
  let daysInYear = calendar.dateInterval(of: .year, for: Date())!.duration / (24 * 60 * 60)
  let sampleItems = (0..<Int(daysInYear)).map { dayOffset in
    let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear)!
    return DateItem(
      id: "\(Int(date.timeIntervalSince1970))",
      date: date
    )
  }

  // Generate sample entries with some having text and some having drawings
  let sampleEntries: [DayEntry] = {
    var entries: [DayEntry] = []

    // Add entries for random past days
    for dayOffset in [5, 12, 18, 23, 30, 45, 52, 67, 89, 100, 125, 150, 180, 200, 234, 267, 290] {
      if dayOffset < Int(daysInYear) {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear)!

        // Some entries have text
        if dayOffset % 3 == 0 {
          entries.append(
            DayEntry(
              body: "Sample entry for day \(dayOffset)",
              createdAt: date,
              drawingData: nil
            ))
        }
        // Some entries have drawings (mock with non-empty data)
        else if dayOffset % 3 == 1 {
          entries.append(
            DayEntry(
              body: "",
              createdAt: date,
              drawingData: Data([0x01, 0x02, 0x03])  // Mock drawing data
            ))
        }
        // Some have both
        else {
          entries.append(
            DayEntry(
              body: "Entry with drawing",
              createdAt: date,
              drawingData: Data([0x01, 0x02, 0x03])
            ))
        }
      }
    }

    return entries
  }()

  ScrollView {
    VStack {
      YearGridView(
        year: currentYear,
        viewMode: .now,
        dotsSpacing: 25,
        items: sampleItems,
        entries: sampleEntries,
        highlightedItemId: nil,
        selectedItemId: nil
      )
      YearGridView(
        year: currentYear,
        viewMode: .year,
        dotsSpacing: 8,
        items: sampleItems,
        entries: sampleEntries,
        highlightedItemId: nil,
        selectedItemId: nil
      )
    }
  }
}
