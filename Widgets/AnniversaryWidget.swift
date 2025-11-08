//
//  AnniversaryWidget.swift
//  Widgets
//
//  Created by Widget Extension
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Anniversary Entry Entity

struct AnniversaryEntryEntity: AppEntity {
  let id: String
  let date: Date
  let preview: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(formatDate(date))", subtitle: "\(preview)")
  }

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Anniversary"
  static var defaultQuery = AnniversaryEntryQuery()

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}

// MARK: - Anniversary Entry Query

struct AnniversaryEntryQuery: EntityQuery, EntityStringQuery {
  func entities(for identifiers: [AnniversaryEntryEntity.ID]) async throws
    -> [AnniversaryEntryEntity]
  {
    let allEntries = loadFutureAnniversaries()
    return allEntries.filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [AnniversaryEntryEntity] {
    return loadFutureAnniversaries()
  }

  func entities(matching string: String) async throws -> [AnniversaryEntryEntity] {
    let allEntries = loadFutureAnniversaries()
    let lowercasedString = string.lowercased()
    return allEntries.filter { entity in
      entity.preview.lowercased().contains(lowercasedString)
        || formatDate(entity.date).lowercased().contains(lowercasedString)
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  private func loadFutureAnniversaries() -> [AnniversaryEntryEntity] {
    let entries = WidgetDataManager.shared.loadAllEntries()
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)

    // Filter future entries that have either text or drawing
    let futureEntries = entries.filter { entry in
      let entryDate = calendar.startOfDay(for: entry.date)
      return entryDate > today && (entry.hasText || entry.hasDrawing)
    }

    // Sort by date (nearest first)
    let sortedEntries = futureEntries.sorted { $0.date < $1.date }

    // Convert to entities
    return sortedEntries.map { entry in
      let preview = makePreview(for: entry)
      let id = String(Int(entry.date.timeIntervalSince1970))
      return AnniversaryEntryEntity(id: id, date: entry.date, preview: preview)
    }
  }

  private func makePreview(for entry: WidgetEntryData) -> String {
    if let text = entry.body, !text.isEmpty {
      // Show first 40 characters of text
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.count > 40 {
        return String(trimmed.prefix(40)) + "..."
      }
      return trimmed
    } else if entry.hasDrawing {
      return "🎨 Drawing"
    }
    return "Entry"
  }
}

// MARK: - Configuration Intent

struct AnniversaryConfigurationIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Anniversary Date"
  static var description = IntentDescription("Choose a specific anniversary to display.")

  @Parameter(title: "Anniversary Entry")
  var selectedEntry: AnniversaryEntryEntity?
}

// MARK: - Timeline Provider

struct AnniversaryProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> AnniversaryEntry {
    return AnniversaryEntry(
      date: Date(),
      anniversaryData: nil,
      configuration: AnniversaryConfigurationIntent()
    )
  }

  func snapshot(for configuration: AnniversaryConfigurationIntent, in context: Context) async
    -> AnniversaryEntry
  {
    let anniversaryData = getAnniversary(for: configuration)
    return AnniversaryEntry(
      date: Date(),
      anniversaryData: anniversaryData,
      configuration: configuration
    )
  }

  func timeline(for configuration: AnniversaryConfigurationIntent, in context: Context) async
    -> Timeline<AnniversaryEntry>
  {
    let currentDate = Date()
    let anniversaryData = getAnniversary(for: configuration)

    let entry = AnniversaryEntry(
      date: currentDate,
      anniversaryData: anniversaryData,
      configuration: configuration
    )

    // Update widget based on countdown timing
    let calendar = Calendar.current
    let nextUpdate: Date

    if let annivData = anniversaryData {
      let components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute],
        from: currentDate,
        to: annivData.date
      )

      // If less than a day away, update more frequently
      if let days = components.day, days == 0 {
        // Update every minute for same-day countdowns
        nextUpdate = calendar.date(byAdding: .minute, value: 1, to: currentDate) ?? currentDate
      } else {
        // Update at midnight for longer countdowns
        nextUpdate =
          calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: currentDate)
          ) ?? currentDate
      }
    } else {
      // No anniversary found, update at midnight
      nextUpdate =
        calendar.date(
          byAdding: .day,
          value: 1,
          to: calendar.startOfDay(for: currentDate)
        ) ?? currentDate
    }

    let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
    return timeline
  }

  private func getAnniversary(for configuration: AnniversaryConfigurationIntent) -> AnniversaryData?
  {
    let entries = WidgetDataManager.shared.loadAllEntries()

    // Filter future entries that have either text or drawing
    let calendar = Calendar.current
    let now = Date()

    let futureEntries = entries.filter { entry in
      let entryDate = calendar.startOfDay(for: entry.date)
      let today = calendar.startOfDay(for: now)
      return entryDate > today && (entry.hasText || entry.hasDrawing)
    }

    guard !futureEntries.isEmpty else {
      return nil
    }

    // If user selected a specific entry, use that
    if let selectedEntry = configuration.selectedEntry {
      let targetDay = calendar.startOfDay(for: selectedEntry.date)
      if let matchingEntry = futureEntries.first(where: {
        calendar.startOfDay(for: $0.date) == targetDay
      }) {
        return AnniversaryData(
          date: matchingEntry.date,
          text: matchingEntry.body,
          drawingData: matchingEntry.drawingData
        )
      }
    }

    // Use stable randomness based on current day
    let today = calendar.startOfDay(for: now)
    let daysSince1970 = Int(today.timeIntervalSince1970 / 86400)
    let stableIndex = daysSince1970 % futureEntries.count
    let selectedEntry = futureEntries[stableIndex]

    return AnniversaryData(
      date: selectedEntry.date,
      text: selectedEntry.body,
      drawingData: selectedEntry.drawingData
    )
  }
}

// MARK: - Timeline Entry

struct AnniversaryEntry: TimelineEntry {
  let date: Date
  let anniversaryData: AnniversaryData?
  let configuration: AnniversaryConfigurationIntent
}

struct AnniversaryData {
  let date: Date
  let text: String?
  let drawingData: Data?

  var hasText: Bool {
    text != nil && !(text?.isEmpty ?? true)
  }

  var hasDrawing: Bool {
    drawingData != nil && !(drawingData?.isEmpty ?? true)
  }
}

// MARK: - Countdown Helper

struct CountdownHelper {
  static func countdownText(from now: Date, to targetDate: Date) -> String {
    let calendar = Calendar.current
    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: now,
      to: targetDate
    )

    guard let years = components.year,
      let months = components.month,
      let days = components.day,
      let hours = components.hour,
      let minutes = components.minute,
      let seconds = components.second
    else { return "" }

    // More than a year: show year + month + day
    if years > 0 {
      var parts: [String] = []

      if years == 1 {
        parts.append("1 year")
      } else {
        parts.append("\(years) years")
      }

      if months > 0 {
        if months == 1 {
          parts.append("1 month")
        } else {
          parts.append("\(months) months")
        }
      }

      if days > 0 {
        if days == 1 {
          parts.append("1 day")
        } else {
          parts.append("\(days) days")
        }
      }

      return "in " + parts.joined(separator: ", ")
    }

    // More than a month but less than a year: show month + day
    if months > 0 {
      var parts: [String] = []

      if months == 1 {
        parts.append("1 month")
      } else {
        parts.append("\(months) months")
      }

      if days > 0 {
        if days == 1 {
          parts.append("1 day")
        } else {
          parts.append("\(days) days")
        }
      }

      return "in " + parts.joined(separator: ", ")
    }

    // More than 1 day: show days only
    if days > 1 {
      return "in \(days) days"
    }

    if days == 1 {
      return "in 1 day"
    }

    // Same day or next day with less than 24 hours: show hours, minutes, seconds
    if days == 0 && (hours > 0 || minutes > 0 || seconds > 0) {
      var parts: [String] = []

      if hours > 0 {
        if hours == 1 {
          parts.append("1h")
        } else {
          parts.append("\(hours)h")
        }
      }

      if minutes > 0 {
        if minutes == 1 {
          parts.append("1m")
        } else {
          parts.append("\(minutes)m")
        }
      }

      // More than 1 hour, only show hours and minutes
      if hours >= 1 {
        return "in " + parts.joined(separator: " ")
      }

      if seconds > 0 {
        if seconds == 1 {
          parts.append("1s")
        } else {
          parts.append("\(seconds)s")
        }
      }

      if parts.isEmpty {
        return "now"
      }

      return "in " + parts.joined(separator: " ")
    }

    return ""
  }

  static func dateText(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: date)
  }
}

// MARK: - Widget View

struct AnniversaryWidgetView: View {
  var entry: AnniversaryProvider.Entry
  @Environment(\.widgetFamily) var family

  var body: some View {
    if let anniversaryData = entry.anniversaryData {
      Group {
        switch family {
        case .systemSmall:
          SmallAnniversaryView(anniversaryData: anniversaryData, currentDate: entry.date)
        case .systemMedium:
          MediumAnniversaryView(anniversaryData: anniversaryData, currentDate: entry.date)
        case .systemLarge:
          LargeAnniversaryView(anniversaryData: anniversaryData, currentDate: entry.date)
        default:
          NoAnniversaryView(family: family)
        }
      }
      .widgetURL(URL(string: "goodday://date/\(Int(anniversaryData.date.timeIntervalSince1970))"))
    } else {
      NoAnniversaryView(family: family)
    }
  }
}

// MARK: - Small Widget View

struct SmallAnniversaryView: View {
  let anniversaryData: AnniversaryData
  let currentDate: Date

  var body: some View {
    VStack(spacing: 0) {
      VStack {
        Spacer()
        // Doodle or text content
        if anniversaryData.hasDrawing, let drawingData = anniversaryData.drawingData {
          AnniversaryDoodleView(drawingData: drawingData)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if anniversaryData.hasText, let text = anniversaryData.text {
          Text(text)
            .font(.caption)
            .lineLimit(4)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
        Spacer()
      }

      Spacer()

      // Countdown text at bottom
      Text(CountdownHelper.countdownText(from: currentDate, to: anniversaryData.date))
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
    }
    .containerBackground(for: .widget) { Color.clear }
  }
}

// MARK: - Medium Widget View

struct MediumAnniversaryView: View {
  let anniversaryData: AnniversaryData
  let currentDate: Date

  var body: some View {
    VStack(spacing: 0) {
      // Top bar with date and countdown
      HStack {
        Text(CountdownHelper.dateText(for: anniversaryData.date))
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
        Text(CountdownHelper.countdownText(from: currentDate, to: anniversaryData.date))
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 8)

      // Main content area
      HStack(spacing: 12) {
        // Left side: Doodle or placeholder
        if anniversaryData.hasDrawing, let drawingData = anniversaryData.drawingData {
          AnniversaryDoodleView(drawingData: drawingData)
            .frame(width: 80, height: 80)
            .padding(10)
        } else {
          Image(systemName: "scribble")
            .font(.system(size: 40))
            .foregroundColor(.secondary.opacity(0.3))
            .frame(width: 80, height: 80)
            .padding(10)
        }

        // Right side: Text or placeholder
        if anniversaryData.hasText, let text = anniversaryData.text {
          Text(text)
            .font(.caption)
            .lineLimit(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 16)
        } else {
          Text("No notes for this special day")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 16)
        }
      }
      .padding(.bottom, 12)
    }
    .containerBackground(for: .widget) { Color.clear }
  }
}

// MARK: - Large Widget View

struct LargeAnniversaryView: View {
  let anniversaryData: AnniversaryData
  let currentDate: Date

  var body: some View {
    VStack(spacing: 8) {
      VStack {
        Spacer()
        // Doodle or text content
        if anniversaryData.hasDrawing, let drawingData = anniversaryData.drawingData {
          AnniversaryDoodleView(drawingData: drawingData)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if anniversaryData.hasText, let text = anniversaryData.text {
          Text(text)
            .font(.title3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
        Spacer()
      }

      // Countdown text at bottom
      Text(CountdownHelper.countdownText(from: currentDate, to: anniversaryData.date))
        .font(.callout)
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
    }
    .containerBackground(for: .widget) { Color.clear }
    .padding()
  }
}

// MARK: - Doodle View

struct AnniversaryDoodleView: View {
  let drawingData: Data

  var body: some View {
    Canvas { context, size in
      let paths = decodePaths(from: drawingData)

      // Calculate scale to fit drawing in widget
      let scale = min(size.width / 300, size.height / 300)
      let offsetX = (size.width - 300 * scale) / 2
      let offsetY = (size.height - 300 * scale) / 2

      for pathData in paths {
        var scaledPath = Path()

        if pathData.isDot && pathData.points.count >= 1 {
          // Draw dot
          let center = pathData.points[0]
          let scaledCenter = CGPoint(
            x: center.x * scale + offsetX,
            y: center.y * scale + offsetY
          )
          let radius: CGFloat = 3.0 * scale
          scaledPath.addEllipse(
            in: CGRect(
              x: scaledCenter.x - radius,
              y: scaledCenter.y - radius,
              width: radius * 2,
              height: radius * 2
            ))
        } else if pathData.points.count > 1 {
          // Draw path
          let firstPoint = pathData.points[0]
          let scaledFirst = CGPoint(
            x: firstPoint.x * scale + offsetX,
            y: firstPoint.y * scale + offsetY
          )
          scaledPath.move(to: scaledFirst)

          for point in pathData.points.dropFirst() {
            let scaledPoint = CGPoint(
              x: point.x * scale + offsetX,
              y: point.y * scale + offsetY
            )
            scaledPath.addLine(to: scaledPoint)
          }
        }

        context.stroke(
          scaledPath,
          with: .color(.accent),
          lineWidth: 2.0 * scale
        )
      }
    }
  }

  private func decodePaths(from data: Data) -> [PathData] {
    do {
      return try JSONDecoder().decode([PathData].self, from: data)
    } catch {
      print("Failed to decode drawing: \(error)")
      return []
    }
  }

  struct PathData: Codable {
    let points: [CGPoint]
    let isDot: Bool
  }
}

// MARK: - No Anniversary View

struct NoAnniversaryView: View {
  let family: WidgetFamily

  var body: some View {
    VStack(alignment: .center, spacing: 8) {
      Image(systemName: "calendar.badge.clock")
        .font(.system(size: family == .systemSmall ? 32 : 48))
        .foregroundColor(.secondary.opacity(0.3))
      Text("No future anniversaries")
        .font(family == .systemSmall ? .caption2 : .subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .containerBackground(for: .widget) { Color.clear }
  }
}

// MARK: - Widget Configuration

struct AnniversaryWidget: Widget {
  let kind: String = "AnniversaryWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind, intent: AnniversaryConfigurationIntent.self, provider: AnniversaryProvider()
    ) { entry in
      AnniversaryWidgetView(entry: entry)
    }
    .configurationDisplayName("Anniversary")
    .description("Upcoming anniversary with countdown.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

// MARK: - Previews

#Preview("Small - Drawing", as: .systemSmall) {
  AnniversaryWidget()
} timeline: {
  let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!

  AnniversaryEntry(
    date: Date(),
    anniversaryData: AnniversaryData(
      date: futureDate,
      text: nil,
      drawingData: createMockDrawingData()
    ),
    configuration: AnniversaryConfigurationIntent()
  )

  // Preview with text only
  AnniversaryEntry(
    date: Date(),
    anniversaryData: AnniversaryData(
      date: futureDate,
      text: "This is a special anniversary!",
      drawingData: nil
    ),
    configuration: AnniversaryConfigurationIntent()
  )

  // Preview with no anniversary
  AnniversaryEntry(
    date: Date(),
    anniversaryData: nil,
    configuration: AnniversaryConfigurationIntent()
  )
}

#Preview("Medium", as: .systemMedium) {
  AnniversaryWidget()
} timeline: {
  let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!

  // Preview with drawing
  AnniversaryEntry(
    date: Date(),
    anniversaryData: AnniversaryData(
      date: futureDate,
      text: nil,
      drawingData: createMockDrawingData()
    ),
    configuration: AnniversaryConfigurationIntent()
  )

  // Preview with text only
  AnniversaryEntry(
    date: Date(),
    anniversaryData: AnniversaryData(
      date: futureDate,
      text: "This is a special anniversary!",
      drawingData: nil
    ),
    configuration: AnniversaryConfigurationIntent()
  )

  // Preview with both
  AnniversaryEntry(
    date: Date(),
    anniversaryData: AnniversaryData(
      date: futureDate,
      text: "This is a special anniversary!",
      drawingData: createMockDrawingData()
    ),
    configuration: AnniversaryConfigurationIntent()
  )

  // Preview with no anniversary
  AnniversaryEntry(
    date: Date(),
    anniversaryData: nil,
    configuration: AnniversaryConfigurationIntent()
  )
}

#Preview("Large", as: .systemLarge) {
  AnniversaryWidget()
} timeline: {
  let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!

  // Preview with drawing
  AnniversaryEntry(
    date: Date(),
    anniversaryData: AnniversaryData(
      date: futureDate,
      text: nil,
      drawingData: createMockDrawingData()
    ),
    configuration: AnniversaryConfigurationIntent()
  )

  // Preview with text only
  AnniversaryEntry(
    date: Date(),
    anniversaryData: AnniversaryData(
      date: futureDate,
      text:
        "This is a special anniversary that I want to remember forever! This is a special anniversary that I want to remember forever! This is a special anniversary that I want to remember forever! This is a special anniversary that I want to remember forever! This is a special anniversary that I want to remember forever!",
      drawingData: nil
    ),
    configuration: AnniversaryConfigurationIntent()
  )

  // Preview with no anniversary
  AnniversaryEntry(
    date: Date(),
    anniversaryData: nil,
    configuration: AnniversaryConfigurationIntent()
  )
}
