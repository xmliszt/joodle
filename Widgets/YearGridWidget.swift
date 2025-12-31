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
      entries: [],
      isSubscribed: true
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (YearGridEntry) -> Void) {
    let isSubscribed = WidgetDataManager.shared.isSubscribed()
    let entry = YearGridEntry(
      date: Date(),
      year: Calendar.current.component(.year, from: Date()),
      percentage: calculateYearProgress(),
      entries: isSubscribed ? loadEntries() : [],
      isSubscribed: isSubscribed
    )
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<YearGridEntry>) -> Void) {
    let currentDate = Date()
    let year = Calendar.current.component(.year, from: currentDate)
    let percentage = calculateYearProgress()
    let isSubscribed = WidgetDataManager.shared.isSubscribed()
    let entries = isSubscribed ? loadEntries() : []

    let entry = YearGridEntry(
      date: currentDate,
      year: year,
      percentage: percentage,
      entries: entries,
      isSubscribed: isSubscribed
    )

    // Update widget at midnight for the new day
    // Subscription changes are handled by WidgetCenter.reloadAllTimelines() in the main app
    let calendar = Calendar.current
    let nextUpdate = calendar.date(
      byAdding: .day,
      value: 1,
      to: calendar.startOfDay(for: currentDate)
    )!

    let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
    completion(timeline)
  }

  private func calculateYearProgress() -> Double {
    let calendar = Calendar.current
    let now = Date()
    let year = calendar.component(.year, from: now)

    guard
      let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))
    else {
      return 0.0
    }

    // Get total days in the year
    let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count ?? 365

    // Get current day of year (1-indexed, so Jan 1 = 1)
    let currentDayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1

    // Calculate progress: on the last day (e.g., day 365 of 365), this gives 100%
    return (Double(currentDayOfYear) / Double(daysInYear)) * 100.0
  }

  private func loadEntries() -> [WidgetDayEntry] {
    let widgetEntries = WidgetDataManager.shared.loadEntries()

    return widgetEntries.map { entry in
      WidgetDayEntry(
        dateString: entry.dateString,
        hasText: entry.hasText,
        hasDrawing: entry.hasDrawing,
        thumbnail: entry.thumbnail,
        drawingData: entry.drawingData
      )
    }
  }
}

struct YearGridEntry: TimelineEntry {
  let date: Date
  let year: Int
  let percentage: Double
  let entries: [WidgetDayEntry]
  let isSubscribed: Bool
}

struct WidgetDayEntry {
  /// The timezone-agnostic date string in "yyyy-MM-dd" format
  let dateString: String
  let hasText: Bool
  let hasDrawing: Bool
  let thumbnail: Data?
  let drawingData: Data?

  /// Computed display date from dateString (for UI components that need Date)
  var date: Date {
    let components = dateString.split(separator: "-")
    if components.count == 3,
       let year = Int(components[0]),
       let month = Int(components[1]),
       let day = Int(components[2]) {
      var dateComponents = DateComponents()
      dateComponents.year = year
      dateComponents.month = month
      dateComponents.day = day
      return Calendar.current.date(from: dateComponents) ?? Date()
    }
    return Date()
  }

  var hasEntry: Bool {
    return hasText || hasDrawing
  }
}

struct YearGridWidgetView: View {
  var entry: YearGridProvider.Entry
  var showJoodles: Bool
  var showEmptyDots: Bool

  @Environment(\.widgetFamily) var widgetFamily

  private var dotSize: CGFloat {
    widgetFamily == .systemMedium ? 4.5 : 6.5
  }

  private var horizontalPadding: CGFloat {
    widgetFamily == .systemMedium ? 12.0 : 18.0
  }

  // Check if widget should show locked view
  private var shouldShowLockedView: Bool {
    !entry.isSubscribed
  }

  private func calculateDotsPerRow(availableWidth: CGFloat) -> Int {
    // Calculate how many dots can fit in the available width
    // Formula: (availableWidth + spacing) / (dotSize + spacing)
    let minSpacing: CGFloat = widgetFamily == .systemMedium ? 4.0 : 7.0
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

  /// Theme color loaded from shared preferences
  private var themeColor: Color {
    WidgetDataManager.shared.loadThemeColor()
  }

  private var entriesByDateKey: [String: WidgetDayEntry] {
    var lookup: [String: WidgetDayEntry] = [:]
    lookup.reserveCapacity(entry.entries.count)

    // Use dateString directly as the key (timezone-agnostic)
    for dayEntry in entry.entries {
      lookup[dayEntry.dateString] = dayEntry
    }
    return lookup
  }

  private func numberOfRows(dotsPerRow: Int) -> Int {
    dateItems.count / dotsPerRow + (dateItems.count.isMultiple(of: dotsPerRow) ? 0 : 1)
  }

  var body: some View {
    if shouldShowLockedView {
      YearGridWidgetLockedView(widgetFamily: widgetFamily)
        .widgetURL(URL(string: "joodle://paywall"))
        .containerBackground(for: .widget) {
          Color(UIColor.systemBackground)
        }
    } else {
      GeometryReader { geometry in
        VStack(alignment: .leading, spacing: widgetFamily == .systemMedium ? 8 : 12) {
          // Header
          HStack {
            Text(String(entry.year))
              .font(.system(size: 20))
              .foregroundColor(.primary)

            Spacer()

            Text(String(format: "%.1f%%", entry.percentage))
              .font(.system(size: 20))
              .foregroundColor(themeColor)
          }
          .padding(.horizontal, horizontalPadding)

          // Grid
          let availableWidth = geometry.size.width - (horizontalPadding * 2)
          let dotsPerRow = calculateDotsPerRow(availableWidth: availableWidth)
          let spacing = calculateSpacing(availableWidth: availableWidth, dotsCount: dotsPerRow)
          let lookup = entriesByDateKey

          LazyVStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<numberOfRows(dotsPerRow: dotsPerRow), id: \.self) { rowIndex in
              createRow(for: rowIndex, dotsPerRow: dotsPerRow, spacing: spacing, lookup: lookup)
            }
          }
          .padding(.horizontal, horizontalPadding)
        }
        .padding(.top, widgetFamily == .systemMedium ? 4 : 16)
        .padding(.bottom, widgetFamily == .systemMedium ? 4 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .containerBackground(for: .widget) {
        Color(UIColor.systemBackground)
      }
    }
  }

  @ViewBuilder
  private func createRow(for rowIndex: Int, dotsPerRow: Int, spacing: CGFloat, lookup: [String: WidgetDayEntry]) -> some View {
    let rowStart = rowIndex * dotsPerRow
    let rowEnd = min(rowStart + dotsPerRow, dateItems.count)

    if rowStart < dateItems.count {
      HStack(alignment: .top, spacing: spacing) {
        ForEach(rowStart..<rowEnd, id: \.self) { index in
          let item = dateItems[index]
          let dotStyle = getDotStyle(for: item.date)
          let dayEntry = getEntryForDate(item.date, using: lookup)
          let hasEntry = dayEntry?.hasEntry ?? false

          DoodleRendererView(
            size: dotSize,
            hasEntry: hasEntry,
            dotStyle: dotStyle,
            thumbnail: showJoodles ? dayEntry?.thumbnail : nil,
            strokeColor: themeColor,
            strokeMultiplier: 2.0,
            renderScale: showJoodles ? 2.0 : 3.0,
            showEmptyDot: showEmptyDots
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

  private func getDotStyle(for date: Date) -> DoodleDotStyle {
    if date < todayStart {
      return .past
    } else if Calendar.current.isDate(date, inSameDayAs: todayStart) {
      return .present
    }
    return .future
  }

  private func getEntryForDate(_ date: Date, using lookup: [String: WidgetDayEntry]) -> WidgetDayEntry? {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    let key = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 1, components.day ?? 1)
    return lookup[key]
  }
}

struct WidgetDateItem: Identifiable {
  var id: String
  var date: Date
}

// MARK: - Widget definitions
// MARK: - Year Grid Widget Locked View (Premium Required)

struct YearGridWidgetLockedView: View {
  let widgetFamily: WidgetFamily

  private var themeColor: Color {
    WidgetDataManager.shared.loadThemeColor()
  }

  var body: some View {
    VStack(spacing: widgetFamily == .systemLarge ? 16 : 8) {
      Image(systemName: "crown.fill")
        .font(.system(size: widgetFamily == .systemLarge ? 40 : (widgetFamily == .systemMedium ? 28 : 24)))
        .foregroundStyle(
          LinearGradient(
            colors: [themeColor.opacity(0.5), themeColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      VStack(spacing: 4) {
        Text("Joodle Pro")
          .font(widgetFamily == .systemLarge ? .headline : .caption.bold())
          .foregroundColor(.primary)

        Text("Upgrade to unlock widgets")
          .font(widgetFamily == .systemLarge ? .subheadline : .caption2)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }
    }
    .padding()
  }
}

struct YearGridWidget: Widget {
  let kind: String = "YearGridWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: YearGridProvider()) { entry in
      YearGridWidgetView(entry: entry, showJoodles: false, showEmptyDots: true)
        .containerBackground(for: .widget) {
          Color(UIColor.systemBackground)
        }
    }
    .configurationDisplayName("Year Progress")
    .description("View your year progress at a glance.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

struct YearGridJoodleWidget: Widget {
  let kind: String = "YearGridJoodleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: YearGridProvider()) { entry in
      YearGridWidgetView(entry: entry, showJoodles: true, showEmptyDots: true)
        .containerBackground(for: .widget) {
          Color(UIColor.systemBackground)
        }
    }
    .configurationDisplayName("Year Progress (Joodles)")
    .description("View your year progress with Joodles.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

struct YearGridJoodleNoEmptyDotsWidget: Widget {
  let kind: String = "YearGridJoodleNoEmptyDotsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: YearGridProvider()) { entry in
      YearGridWidgetView(entry: entry, showJoodles: true, showEmptyDots: false)
        .containerBackground(for: .widget) {
          Color(UIColor.systemBackground)
        }
    }
    .configurationDisplayName("Year Progress (Joodles Only)")
    .description("View your year progress with Joodles. Empty days are hidden.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}
