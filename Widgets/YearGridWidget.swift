//
//  YearGridWidget.swift
//  Widgets
//
//  Created by Widget Extension
//

import SwiftUI
import WidgetKit

struct YearGridProvider: TimelineProvider {
  func placeholder(in context: Context) -> YearGridEntry {
    YearGridEntry(
      date: Date(),
      year: Calendar.current.component(.year, from: Date()),
      percentage: 0.0,
      entries: []
    )
  }
  
  func getSnapshot(in context: Context, completion: @escaping (YearGridEntry) -> Void) {
    let entry = YearGridEntry(
      date: Date(),
      year: Calendar.current.component(.year, from: Date()),
      percentage: calculateYearProgress(),
      entries: loadEntries()
    )
    completion(entry)
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<YearGridEntry>) -> Void) {
    let currentDate = Date()
    let year = Calendar.current.component(.year, from: currentDate)
    let percentage = calculateYearProgress()
    let entries = loadEntries()
    
    let entry = YearGridEntry(
      date: currentDate,
      year: year,
      percentage: percentage,
      entries: entries
    )
    
    // Update widget at midnight
    let calendar = Calendar.current
    let tomorrow = calendar.date(
      byAdding: .day,
      value: 1,
      to: calendar.startOfDay(for: currentDate)
    )!
    
    let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
    completion(timeline)
  }
  
  private func calculateYearProgress() -> Double {
    let calendar = Calendar.current
    let now = Date()
    let year = calendar.component(.year, from: now)
    
    guard
      let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
      let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
    else {
      return 0.0
    }
    
    let totalSeconds = endOfYear.timeIntervalSince(startOfYear)
    let elapsedSeconds = now.timeIntervalSince(startOfYear)
    
    return (elapsedSeconds / totalSeconds) * 100.0
  }
  
  private func loadEntries() -> [WidgetDayEntry] {
    let widgetEntries = WidgetDataManager.shared.loadEntries()
    // Only keep essential data to reduce memory usage
    return widgetEntries.map { entry in
      WidgetDayEntry(
        date: entry.date,
        hasText: entry.hasText,
        hasDrawing: entry.hasDrawing
      )
    }
  }
}

struct YearGridEntry: TimelineEntry {
  let date: Date
  let year: Int
  let percentage: Double
  let entries: [WidgetDayEntry]
}

struct WidgetDayEntry {
  let date: Date
  let hasText: Bool
  let hasDrawing: Bool
  
  var hasEntry: Bool {
    return hasText || hasDrawing
  }
}

struct YearGridWidgetView: View {
  var entry: YearGridProvider.Entry
  @Environment(\.widgetFamily) var widgetFamily
  
  private var dotSize: CGFloat {
    widgetFamily == .systemMedium ? 4.5 : 7.5
  }
  
  private var horizontalPadding: CGFloat {
    widgetFamily == .systemMedium ? 12.0 : 18.0
  }
  
  private func calculateDotsPerRow(availableWidth: CGFloat) -> Int {
    // Calculate how many dots can fit in the available width
    // Formula: (availableWidth + spacing) / (dotSize + spacing)
    let minSpacing: CGFloat = widgetFamily == .systemMedium ? 4.0 : 6.0
    let dotsPerRow = Int((availableWidth + minSpacing) / (dotSize + minSpacing))
    return max(1, dotsPerRow)
  }
  
  private func calculateSpacing(availableWidth: CGFloat, dotsCount: Int) -> CGFloat {
    // Calculate spacing to distribute dots evenly across the width
    guard dotsCount > 1 else { return 0 }
    let totalDotWidth = CGFloat(dotsCount) * dotSize
    let totalSpacing = availableWidth - totalDotWidth
    return totalSpacing / CGFloat(dotsCount - 1)
  }
  
  private var dateItems: [WidgetDateItem] {
    let calendar = Calendar.current
    guard let startOfYear = calendar.date(from: DateComponents(year: entry.year, month: 1, day: 1))
    else {
      return []
    }
    
    let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count ?? 365
    
    return (0..<daysInYear).map { dayOffset in
      let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear)!
      return WidgetDateItem(
        id: "\(dayOffset)",
        date: date
      )
    }
  }
  
  private var todayStart: Date {
    Calendar.current.startOfDay(for: Date())
  }
  
  private var entriesByDateKey: [String: WidgetDayEntry] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    
    var lookup: [String: WidgetDayEntry] = [:]
    lookup.reserveCapacity(entry.entries.count)
    
    for dayEntry in entry.entries {
      let dayStart = calendar.startOfDay(for: dayEntry.date)
      let key = formatter.string(from: dayStart)
      lookup[key] = dayEntry
    }
    return lookup
  }
  
  private func numberOfRows(dotsPerRow: Int) -> Int {
    dateItems.count / dotsPerRow + (dateItems.count.isMultiple(of: dotsPerRow) ? 0 : 1)
  }
  
  var body: some View {
    GeometryReader { geometry in
      VStack(alignment: .leading, spacing: widgetFamily == .systemMedium ? 8 : 12) {
        // Header
        HStack {
          Text(String(entry.year))
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(.primary)
          
          Spacer()
          
          Text(String(format: "%.1f%%", entry.percentage))
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(.accent)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, widgetFamily == .systemMedium ? 4 : 16)
        
        // Grid
        let availableWidth = geometry.size.width - (horizontalPadding * 2)
        let dotsPerRow = calculateDotsPerRow(availableWidth: availableWidth)
        let spacing = calculateSpacing(availableWidth: availableWidth, dotsCount: dotsPerRow)
        
        LazyVStack(alignment: .leading, spacing: spacing) {
          ForEach(0..<numberOfRows(dotsPerRow: dotsPerRow), id: \.self) { rowIndex in
            createRow(for: rowIndex, dotsPerRow: dotsPerRow, spacing: spacing)
          }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, widgetFamily == .systemMedium ? 4 : 8)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }
  
  @ViewBuilder
  private func createRow(for rowIndex: Int, dotsPerRow: Int, spacing: CGFloat) -> some View {
    let rowStart = rowIndex * dotsPerRow
    let rowEnd = min(rowStart + dotsPerRow, dateItems.count)
    
    if rowStart < dateItems.count {
      HStack(alignment: .top, spacing: spacing) {
        ForEach(rowStart..<rowEnd, id: \.self) { index in
          let item = dateItems[index]
          let dotStyle = getDotStyle(for: item.date)
          let dayEntry = getEntryForDate(item.date)
          let hasEntry = dayEntry?.hasEntry ?? false
          
          WidgetDotView(
            size: dotSize,
            withEntry: hasEntry,
            dotStyle: dotStyle
          )
          .frame(width: dotSize, height: dotSize)
        }
        
        // Add spacer for the last row if it's not full
        if rowEnd < rowStart + dotsPerRow {
          Spacer(minLength: 0)
        }
      }
    }
  }
  
  private func getDotStyle(for date: Date) -> WidgetDotStyle {
    if date < todayStart {
      return .past
    } else if Calendar.current.isDate(date, inSameDayAs: todayStart) {
      return .present
    }
    return .future
  }
  
  private func getEntryForDate(_ date: Date) -> WidgetDayEntry? {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: date)
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let key = formatter.string(from: dayStart)
    return entriesByDateKey[key]
  }
}

struct WidgetDateItem: Identifiable {
  var id: String
  var date: Date
}

enum WidgetDotStyle {
  case past
  case present
  case future
}

struct WidgetDotView: View {
  let size: CGFloat
  let withEntry: Bool
  let dotStyle: WidgetDotStyle
  
  private var dotColor: Color {
    if withEntry { return .accent }
    if dotStyle == .present { return .primary }
    if dotStyle == .future { return .primary.opacity(0.15) }
    return .primary
  }
  
  var body: some View {
    ZStack {
      Circle()
        .fill(dotColor)
        .frame(width: size, height: size)
    }
    .frame(width: size, height: size)
  }
}

struct YearGridWidget: Widget {
  let kind: String = "YearGridWidget"
  
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: YearGridProvider()) { entry in
      YearGridWidgetView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Year Progress")
    .description("View your year at a glance with progress.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

#Preview(as: .systemMedium) {
  YearGridWidget()
} timeline: {
  // Create mock entries for preview
  let calendar = Calendar.current
  let currentYear = 2025
  let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
  
  let mockEntries: [WidgetDayEntry] = [
    // Text entries
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 5, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 12, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 23, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    // Drawing entries
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 18, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 30, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 45, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    // Both text and drawing
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 52, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 67, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 89, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 100, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 125, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 150, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 180, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 200, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 234, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 267, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 290, to: startOfYear)!, hasText: false,
      hasDrawing: true),
  ]
  
  YearGridEntry(date: Date(), year: 2025, percentage: 83.8, entries: mockEntries)
}

#Preview(as: .systemLarge) {
  YearGridWidget()
} timeline: {
  // Create mock entries for preview
  let calendar = Calendar.current
  let currentYear = 2025
  let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
  
  let mockEntries: [WidgetDayEntry] = [
    // Text entries
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 5, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 12, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 23, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    // Drawing entries
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 18, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 30, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 45, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    // Both text and drawing
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 52, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 67, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 89, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 100, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 125, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 150, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 180, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 200, to: startOfYear)!, hasText: false,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 234, to: startOfYear)!, hasText: true,
      hasDrawing: true),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 267, to: startOfYear)!, hasText: true,
      hasDrawing: false),
    WidgetDayEntry(
      date: calendar.date(byAdding: .day, value: 290, to: startOfYear)!, hasText: false,
      hasDrawing: true),
  ]
  
  YearGridEntry(date: Date(), year: 2025, percentage: 83.8, entries: mockEntries)
}
