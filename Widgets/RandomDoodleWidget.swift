//
//  RandomDoodleWidget.swift
//  Widgets
//
//  Created by Widget Extension
//

import SwiftUI
import WidgetKit

struct RandomDoodleProvider: TimelineProvider {
  func placeholder(in context: Context) -> RandomDoodleEntry {
    RandomDoodleEntry(date: Date(), doodle: nil, prompt: getRandomPrompt())
  }

  func getSnapshot(in context: Context, completion: @escaping (RandomDoodleEntry) -> Void) {
    let entry = RandomDoodleEntry(
      date: Date(),
      doodle: getRandomDoodle(),
      prompt: getRandomPrompt()
    )
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RandomDoodleEntry>) -> Void)
  {
    let currentDate = Date()
    let doodle = getRandomDoodle()

    let entry = RandomDoodleEntry(
      date: currentDate,
      doodle: doodle,
      prompt: getRandomPrompt()
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

  private func getRandomDoodle() -> DoodleData? {
    let entries = WidgetDataManager.shared.loadEntries()

    // Filter entries from the past year (365 days back) that have drawings
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let oneYearAgo = calendar.date(byAdding: .day, value: -365, to: today)!

    let doodleEntries = entries.filter { entry in
      let entryDate = calendar.startOfDay(for: entry.date)
      return entry.hasDrawing && entry.drawingData != nil && entryDate >= oneYearAgo
      && entryDate <= today
    }

    guard !doodleEntries.isEmpty else {
      return nil
    }

    // Select a random doodle
    guard let selectedEntry = doodleEntries.randomElement() else {
      return nil
    }

    return DoodleData(
      date: selectedEntry.date,
      drawingData: selectedEntry.drawingData!
    )
  }

  private func getRandomPrompt() -> String {
    return EMPTY_PLACEHOLDERS.randomElement()!
  }
}

struct RandomDoodleEntry: TimelineEntry {
  let date: Date
  let doodle: DoodleData?
  let prompt: String
}

struct DoodleData {
  let date: Date
  let drawingData: Data
}

struct PathData: Codable {
  let points: [CGPoint]
  let isDot: Bool

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    points = try container.decode([CGPoint].self, forKey: .points)
    isDot = try container.decodeIfPresent(Bool.self, forKey: .isDot) ?? false
  }

  private enum CodingKeys: String, CodingKey {
    case points
    case isDot
  }
}

struct RandomDoodleWidgetView: View {
  var entry: RandomDoodleProvider.Entry
  @Environment(\.widgetFamily) var family

  var body: some View {
    switch family {
    case .accessoryCircular:
      LockScreenCircularView(doodle: entry.doodle, family: family)
    default:
      if let doodle = entry.doodle {
        DoodleView(drawingData: doodle.drawingData, family: family)
          .padding(family == .systemLarge ? 48 : 24)
          .widgetURL(URL(string: "goodday://date/\(Int(doodle.date.timeIntervalSince1970))"))
          .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
          }
      } else {
        // Show not found status
        NotFoundView(prompt: entry.prompt, family: family)
          .padding(8)
          .widgetURL(URL(string: "goodday://date/\(Int(Date().timeIntervalSince1970))"))
          .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
          }
      }
    }
  }
}

struct LockScreenCircularView: View {
  let doodle: DoodleData?
  let family: WidgetFamily

  var body: some View {
    if let doodle = doodle {
      ZStack {
        DoodleView(drawingData: doodle.drawingData, family: family)
          .padding(8)
      }
      .widgetURL(URL(string: "goodday://date/\(Int(doodle.date.timeIntervalSince1970))"))
      .containerBackground(for: .widget) {
        Color.clear
      }
    } else {
      ZStack {
        Circle()
          .strokeBorder(lineWidth: 2)
          .foregroundStyle(.secondary.opacity(0.3))

        Image(systemName: "scribble")
          .font(.system(size: 24))
          .foregroundStyle(.secondary)
      }
      .widgetURL(URL(string: "goodday://date/\(Int(Date().timeIntervalSince1970))"))
      .containerBackground(for: .widget) {
        Color.clear
      }
    }
  }
}

struct DoodleView: View {
  let drawingData: Data
  let family: WidgetFamily

  var body: some View {
    Canvas { context, size in
      // Decode and draw the paths
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
          let dotRadius = 2.5 * scale  // DRAWING_LINE_WIDTH / 2 * scale
          scaledPath.addEllipse(
            in: CGRect(
              x: center.x * scale + offsetX - dotRadius,
              y: center.y * scale + offsetY - dotRadius,
              width: dotRadius * 2,
              height: dotRadius * 2
            )
          )
          context.fill(scaledPath, with: .color(.accent))
        } else {
          // Draw line
          for (index, point) in pathData.points.enumerated() {
            let scaledPoint = CGPoint(
              x: point.x * scale + offsetX,
              y: point.y * scale + offsetY
            )
            if index == 0 {
              scaledPath.move(to: scaledPoint)
            } else {
              scaledPath.addLine(to: scaledPoint)
            }
          }
          context.stroke(
            scaledPath,
            with: .color(.accent),
            style: StrokeStyle(
              lineWidth: (family == .accessoryCircular ? 10.0 :5.0) * scale,
              lineCap: .round,
              lineJoin: .round
            )
          )
        }
      }
    }
  }

  private func decodePaths(from data: Data) -> [PathData] {
    do {
      return try JSONDecoder().decode([PathData].self, from: data)
    } catch {
      print("Failed to decode drawing data: \(error)")
      return []
    }
  }
}

struct NotFoundView: View {
  let prompt: String
  let family: WidgetFamily

  var body: some View {
    VStack(alignment: .center, spacing: 8) {
      Image(systemName: "scribble")
        .font(.system(size: family == .systemLarge ? 50 : 32))
        .foregroundColor(.secondary.opacity(0.3))
      Text(prompt)
        .font(family == .systemLarge ? .mansalva(size: 16) : .mansalva(size: 12))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
  }
}

struct RandomDoodleWidget: Widget {
  let kind: String = "RandomDoodleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RandomDoodleProvider()) { entry in
      RandomDoodleWidgetView(entry: entry)
    }
    .configurationDisplayName("Random Doodle")
    .description("Random doodle from past year.")
    .supportedFamilies([.systemSmall, .systemLarge, .accessoryCircular])
  }
}

#Preview(as: .systemSmall) {
  RandomDoodleWidget()
} timeline: {
  // Preview with a doodle
  let mockDrawingData = createMockDrawingData()
  RandomDoodleEntry(
    date: Date(),
    doodle: DoodleData(date: Date(), drawingData: mockDrawingData),
    prompt: "Draw something"
  )

  // Preview without a doodle
  RandomDoodleEntry(date: Date(), doodle: nil, prompt: "Your canvas is lonely 🥺")
}

#Preview(as: .systemLarge) {
  RandomDoodleWidget()
} timeline: {
  // Preview with a doodle from 5 days ago
  let mockDrawingData = createMockDrawingData()
  let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
  RandomDoodleEntry(
    date: Date(),
    doodle: DoodleData(date: fiveDaysAgo, drawingData: mockDrawingData),
    prompt: "Draw something"
  )

  // Preview without a doodle
  RandomDoodleEntry(date: Date(), doodle: nil, prompt: "Your canvas is lonely 🥺")
}

#Preview(as: .accessoryCircular) {
  RandomDoodleWidget()
} timeline: {
  // Preview with a doodle
  let mockDrawingData = createMockDrawingData()
  RandomDoodleEntry(
    date: Date(),
    doodle: DoodleData(date: Date(), drawingData: mockDrawingData),
    prompt: "Draw something"
  )

  // Preview without a doodle
  RandomDoodleEntry(date: Date(), doodle: nil, prompt: "Your canvas is lonely 🥺")
}
