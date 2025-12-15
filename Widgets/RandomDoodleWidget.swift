//
//  RandomJoodleWidget.swift
//  Widgets
//
//  Created by Widget Extension
//

import SwiftUI
import WidgetKit

struct RandomJoodleProvider: TimelineProvider {
  func placeholder(in context: Context) -> RandomJoodleEntry {
    RandomJoodleEntry(date: Date(), Joodle: nil, prompt: getRandomPrompt(), isSubscribed: true)
  }

  func getSnapshot(in context: Context, completion: @escaping (RandomJoodleEntry) -> Void) {
    let isSubscribed = WidgetDataManager.shared.isSubscribed()
    let entry = RandomJoodleEntry(
      date: Date(),
      Joodle: isSubscribed ? getRandomJoodle() : nil,
      prompt: getRandomPrompt(),
      isSubscribed: isSubscribed
    )
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RandomJoodleEntry>) -> Void)
  {
    let currentDate = Date()
    let isSubscribed = WidgetDataManager.shared.isSubscribed()
    let Joodle = isSubscribed ? getRandomJoodle() : nil

    let entry = RandomJoodleEntry(
      date: currentDate,
      Joodle: Joodle,
      prompt: getRandomPrompt(),
      isSubscribed: isSubscribed
    )

    // Update widget more frequently to catch subscription changes
    // Every 15 minutes if not subscribed, midnight if subscribed
    let calendar = Calendar.current
    let nextUpdate: Date
    if isSubscribed {
      nextUpdate = calendar.date(
        byAdding: .day,
        value: 1,
        to: calendar.startOfDay(for: currentDate)
      )!
    } else {
      nextUpdate = calendar.date(byAdding: .minute, value: 15, to: currentDate)!
    }

    let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
    completion(timeline)
  }

  private func getRandomJoodle() -> JoodleData? {
    let entries = WidgetDataManager.shared.loadEntries()

    // Filter entries from the past year (365 days back) that have drawings
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let oneYearAgo = calendar.date(byAdding: .day, value: -365, to: today)!

    let JoodleEntries = entries.filter { entry in
      let entryDate = calendar.startOfDay(for: entry.date)
      return entry.hasDrawing && entry.drawingData != nil && entryDate >= oneYearAgo
      && entryDate <= today
    }

    guard !JoodleEntries.isEmpty else {
      return nil
    }

    // Select a random Joodle
    guard let selectedEntry = JoodleEntries.randomElement() else {
      return nil
    }

    return JoodleData(
      date: selectedEntry.date,
      drawingData: selectedEntry.drawingData!
    )
  }

  private func getRandomPrompt() -> String {
    return EMPTY_PLACEHOLDERS.randomElement()!
  }
}

struct RandomJoodleEntry: TimelineEntry {
  let date: Date
  let Joodle: JoodleData?
  let prompt: String
  let isSubscribed: Bool
}

struct JoodleData {
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

struct RandomJoodleWidgetView: View {
  var entry: RandomJoodleProvider.Entry
  @Environment(\.widgetFamily) var family

  /// Theme color loaded from shared preferences
  private var themeColor: Color {
    WidgetDataManager.shared.loadThemeColor()
  }

  var body: some View {
    // Check subscription status first
    if !entry.isSubscribed {
      WidgetLockedView(family: family)
        .widgetURL(URL(string: "joodle://paywall"))
        .containerBackground(for: .widget) {
          Color(UIColor.systemBackground)
        }
    } else {
      switch family {
      case .accessoryCircular:
        LockScreenCircularView(Joodle: entry.Joodle, family: family, themeColor: themeColor)
      default:
        if let Joodle = entry.Joodle {
          JoodleView(drawingData: Joodle.drawingData, family: family, themeColor: themeColor)
            .padding(family == .systemLarge ? 48 : 24)
            .widgetURL(URL(string: "joodle://date/\(Int(Joodle.date.timeIntervalSince1970))"))
            .containerBackground(for: .widget) {
              Color(UIColor.systemBackground)
            }
        } else {
          // Show not found status
          NotFoundView(prompt: entry.prompt, family: family)
            .padding(8)
            .widgetURL(URL(string: "joodle://date/\(Int(Date().timeIntervalSince1970))"))
            .containerBackground(for: .widget) {
              Color(UIColor.systemBackground)
            }
        }
      }
    }
  }
}

// MARK: - Widget Locked View (Premium Required)

struct WidgetLockedView: View {
  let family: WidgetFamily

  private var themeColor: Color {
    WidgetDataManager.shared.loadThemeColor()
  }

  var body: some View {
    VStack(spacing: family == .systemLarge ? 16 : 8) {
      Image(systemName: "crown.fill")
        .font(.system(size: family == .systemLarge ? 40 : 24))
        .foregroundStyle(
          LinearGradient(
            colors: [themeColor.opacity(0.5), themeColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      VStack(spacing: 4) {
        Text("Joodle Super")
          .font(family == .systemLarge ? .headline : .caption.bold())
          .foregroundColor(.primary)

        Text("Upgrade to unlock widgets")
          .font(family == .systemLarge ? .subheadline : .caption2)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }
    }
    .padding()
  }
}

struct LockScreenCircularView: View {
  let Joodle: JoodleData?
  let family: WidgetFamily
  let themeColor: Color

  var body: some View {
    if let Joodle = Joodle {
      ZStack {
        JoodleView(drawingData: Joodle.drawingData, family: family, themeColor: themeColor)
          .padding(8)
      }
      .widgetURL(URL(string: "joodle://date/\(Int(Joodle.date.timeIntervalSince1970))"))
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
      .widgetURL(URL(string: "joodle://date/\(Int(Date().timeIntervalSince1970))"))
      .containerBackground(for: .widget) {
        Color.clear
      }
    }
  }
}

struct JoodleView: View {
  let drawingData: Data
  let family: WidgetFamily
  let themeColor: Color

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
          context.fill(scaledPath, with: .color(themeColor))
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
            with: .color(themeColor),
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
        .font(family == .systemLarge ? .system(size: 16) : .system(size: 12))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
  }
}

struct RandomJoodleWidget: Widget {
  let kind: String = "RandomJoodleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RandomJoodleProvider()) { entry in
      RandomJoodleWidgetView(entry: entry)
    }
    .configurationDisplayName("Random Joodle")
    .description("Random Joodle from past year.")
    .supportedFamilies([.systemSmall, .systemLarge, .accessoryCircular])
  }
}

#Preview(as: .systemSmall) {
  RandomJoodleWidget()
} timeline: {
  // Preview with a Joodle (subscribed)
  let mockDrawingData = createMockDrawingData()
  RandomJoodleEntry(
    date: Date(),
    Joodle: JoodleData(date: Date(), drawingData: mockDrawingData),
    prompt: "Draw something",
    isSubscribed: true
  )

  // Preview without subscription (locked)
  RandomJoodleEntry(date: Date(), Joodle: nil, prompt: "Your canvas is lonely 🥺", isSubscribed: false)
}

#Preview(as: .systemLarge) {
  RandomJoodleWidget()
} timeline: {
  // Preview with a Joodle from 5 days ago (subscribed)
  let mockDrawingData = createMockDrawingData()
  let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
  RandomJoodleEntry(
    date: Date(),
    Joodle: JoodleData(date: fiveDaysAgo, drawingData: mockDrawingData),
    prompt: "Draw something",
    isSubscribed: true
  )

  // Preview without subscription (locked)
  RandomJoodleEntry(date: Date(), Joodle: nil, prompt: "Your canvas is lonely 🥺", isSubscribed: false)
}

#Preview(as: .accessoryCircular) {
  RandomJoodleWidget()
} timeline: {
  // Preview with a Joodle (subscribed)
  let mockDrawingData = createMockDrawingData()
  RandomJoodleEntry(
    date: Date(),
    Joodle: JoodleData(date: Date(), drawingData: mockDrawingData),
    prompt: "Draw something",
    isSubscribed: true
  )

  // Preview without subscription (locked)
  RandomJoodleEntry(date: Date(), Joodle: nil, prompt: "Your canvas is lonely 🥺", isSubscribed: false)
}
