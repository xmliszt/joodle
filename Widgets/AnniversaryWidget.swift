//
//  AnniversaryWidget.swift
//  Widgets
//
//  Created by Widget Extension
//

import AppIntents
import SwiftUI
import WidgetKit
import Foundation

// MARK: - Constants

private let kRandomAnniversaryID = "random_anniversary"

// MARK: - Anniversary Entry Entity

struct AnniversaryEntryEntity: AppEntity {
  let id: String
  let date: Date?
  let preview: String

  var displayRepresentation: DisplayRepresentation {
    if let date = date {
      // Regular anniversary with date
      return DisplayRepresentation(
        title: "\(formatDate(date))",
        subtitle: "\(preview)"
      )
    } else {
      // Random anniversary option
      return DisplayRepresentation(title: "Random", subtitle: "\(preview)")
    }
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
    let randomEntity = AnniversaryEntryEntity(
      id: kRandomAnniversaryID,
      date: nil,
      preview: "🎲 Random anniversary (changes daily)"
    )

    var results: [AnniversaryEntryEntity] = []
    if identifiers.contains(kRandomAnniversaryID) {
      results.append(randomEntity)
    }

    let allEntries = loadFutureAnniversaries()
    results += allEntries.filter { identifiers.contains($0.id) }

    return results
  }

  func suggestedEntities() async throws -> [AnniversaryEntryEntity] {
    let randomEntity = AnniversaryEntryEntity(
      id: kRandomAnniversaryID,
      date: nil,
      preview: "🎲 Random anniversary (changes daily)"
    )
    return [randomEntity] + loadFutureAnniversaries()
  }

  func entities(matching string: String) async throws -> [AnniversaryEntryEntity] {
    let randomEntity = AnniversaryEntryEntity(
      id: kRandomAnniversaryID,
      date: nil,
      preview: "🎲 Random anniversary (changes daily)"
    )

    let allEntries = loadFutureAnniversaries()
    let lowercasedString = string.lowercased()

    var results: [AnniversaryEntryEntity] = []

    // Check if random entity matches
    if "random".contains(lowercasedString) || randomEntity.preview.lowercased().contains(lowercasedString) {
      results.append(randomEntity)
    }

    // Add matching anniversaries
    results += allEntries.filter { entity in
      entity.preview.lowercased().contains(lowercasedString)
        || formatDate(entity.date!).lowercased().contains(lowercasedString)
    }

    return results
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
      return AnniversaryEntryEntity(
        id: id,
        date: entry.date,
        preview: preview
      )
    }
  }

  private func makePreview(for entry: WidgetEntryData) -> String {
    // If have text, show text
    if let text = entry.body, !text.isEmpty {
      // Show first 40 characters of text
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.count > 40 {
        return String(trimmed.prefix(40)) + "..."
      }
      return trimmed
    }
    // Otherwise, only has drawing, show an emoji
    else if entry.hasDrawing {
      return "🎨"
    }
    // This is not possible, a future entry in this list should have at least either text or drawing
    else {
      fatalError("Future entry in anniversary list must have either text or drawing")
    }
  }
}

// MARK: - Configuration Intent

struct AnniversaryOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [AnniversaryEntryEntity] {
        let query = AnniversaryEntryQuery()
        return try await query.suggestedEntities()
    }
}

struct AnniversaryConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Anniversary"
    static var description = IntentDescription("Select an anniversary to display.")

    @Parameter(
      title: "Anniversary",
      description: "Choose an anniversary to display in the widget.",
      default: nil
    )
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

    // If user selected a specific entry (not random or nil), use that
    if let selectedEntry = configuration.selectedEntry,
       selectedEntry.id != kRandomAnniversaryID {
      let targetDay = calendar.startOfDay(for: selectedEntry.date!)
      if let matchingEntry = futureEntries.first(where: {
        calendar.startOfDay(for: $0.date) == targetDay
      }) {
        return AnniversaryData(
          date: matchingEntry.date,
          text: matchingEntry.body,
          drawingData: matchingEntry.drawingData
        )
      }

      // Selected entry has passed - automatically select the next closest anniversary
      // Sort by date and pick the earliest one
      let sortedEntries = futureEntries.sorted { $0.date < $1.date }
      if let nextEntry = sortedEntries.first {
        return AnniversaryData(
          date: nextEntry.date,
          text: nextEntry.body,
          drawingData: nextEntry.drawingData
        )
      }
    }

    // Use true random selection (default behavior when nil or when random is selected)
    guard let selectedEntry = futureEntries.randomElement() else {
      return nil
    }

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
      .widgetURL(URL(string: "joodle://date/\(Int(anniversaryData.date.timeIntervalSince1970))"))
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
            .font(.mansalva(size: 12))
            .lineLimit(4)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
        Spacer()
      }

      Spacer()

      // Countdown text at bottom
      Text(CountdownHelper.countdownText(from: currentDate, to: anniversaryData.date))
        .font(.mansalva(size: 12))
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
    }
    .containerBackground(for: .widget) {
      Color(UIColor.systemBackground)
    }
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
          .font(.mansalva(size: 12))
          .foregroundColor(.secondary)
        Spacer()
        Text(CountdownHelper.countdownText(from: currentDate, to: anniversaryData.date))
          .font(.mansalva(size: 12))
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
            .font(.mansalva(size: 12))
            .lineLimit(5)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Text("No notes for this special day.")
            .font(.mansalva(size: 12))
            .foregroundColor(.secondary.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.bottom, 12)
    }
    .containerBackground(for: .widget) {
      Color(UIColor.systemBackground)
    }
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
            .font(.mansalva(size: 20))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
        Spacer()
      }

      // Countdown text at bottom
      Text(CountdownHelper.countdownText(from: currentDate, to: anniversaryData.date))
        .font(.mansalva(size: 16))
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
    }
    .containerBackground(for: .widget) {
      Color(UIColor.systemBackground)
    }
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
          style: StrokeStyle(
            lineWidth: 5.0 * scale,
            lineCap: .round,
            lineJoin: .round
          )
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
        .font(.system(size: family == .systemSmall ? 32 : family == .systemMedium ? 40 : 48))
        .foregroundColor(.secondary.opacity(0.3))
      Text("No future anniversaries")
        .font(family == .systemSmall ? .mansalva(size: 11) : family == .systemMedium ? .mansalva(size: 11) : .mansalva(size: 15))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .containerBackground(for: .widget) {
      Color(UIColor.systemBackground)
    }
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
      text: "Parents coming to Singapore! Finally!",
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
