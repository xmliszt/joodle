//
//  TodayDoodleWidget.swift
//  Widgets
//
//  Created by Widget Extension
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct TodayDoodleProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayDoodleEntry {
    return TodayDoodleEntry(
      date: Date(),
      todayData: nil,
      isSubscribed: true
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayDoodleEntry) -> Void) {
    let isSubscribed = WidgetDataManager.shared.isSubscribed()
    let todayData = isSubscribed ? getTodayEntry() : nil
    let entry = TodayDoodleEntry(
      date: Date(),
      todayData: todayData,
      isSubscribed: isSubscribed
    )
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayDoodleEntry>) -> Void) {
    let currentDate = Date()
    let isSubscribed = WidgetDataManager.shared.isSubscribed()
    let todayData = isSubscribed ? getTodayEntry() : nil

    let entry = TodayDoodleEntry(
      date: currentDate,
      todayData: todayData,
      isSubscribed: isSubscribed
    )

    // Update widget at midnight to refresh for the new day
    // Subscription changes are handled by WidgetCenter.reloadAllTimelines() in the main app
    let calendar = Calendar.current
    let nextUpdate = calendar.date(
      byAdding: .day,
      value: 1,
      to: calendar.startOfDay(for: currentDate)
    ) ?? currentDate

    let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
    completion(timeline)
  }

  private func getTodayEntry() -> TodayDoodleData? {
    let entries = WidgetDataManager.shared.loadAllEntries()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Find today's entry
    let todayEntry = entries.first { entry in
      let entryDate = calendar.startOfDay(for: entry.date)
      return entryDate == today && (entry.hasText || entry.hasDrawing)
    }

    guard let entry = todayEntry else {
      return nil
    }

    return TodayDoodleData(
      date: entry.date,
      text: entry.body,
      drawingData: entry.drawingData
    )
  }
}

// MARK: - Timeline Entry

struct TodayDoodleEntry: TimelineEntry {
  let date: Date
  let todayData: TodayDoodleData?
  let isSubscribed: Bool
}

struct TodayDoodleData {
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

struct TodayDoodleWidgetView: View {
  var entry: TodayDoodleProvider.Entry
  @Environment(\.widgetFamily) var family

  var body: some View {
    // Check subscription status first
    if !entry.isSubscribed {
      TodayDoodleWidgetLockedView(family: family)
        .widgetURL(URL(string: "joodle://paywall"))
        .containerBackground(for: .widget) {
          Color(UIColor.systemBackground)
        }
    } else if let todayData = entry.todayData {
      Group {
        switch family {
        case .systemSmall:
          SmallTodayDoodleView(todayData: todayData)
        case .systemMedium:
          MediumTodayDoodleView(todayData: todayData)
        case .systemLarge:
          LargeTodayDoodleView(todayData: todayData)
        case .accessoryCircular:
          CircularTodayDoodleView(todayData: todayData)
        default:
          NoTodayDoodleView(family: family)
        }
      }
      .widgetURL(URL(string: "joodle://date/\(Int(todayData.date.timeIntervalSince1970))"))
    } else {
      NoTodayDoodleView(family: family)
        .widgetURL(URL(string: "joodle://date/\(Int(Date().timeIntervalSince1970))"))
    }
  }
}

// MARK: - Today Doodle Widget Locked View (Premium Required)

struct TodayDoodleWidgetLockedView: View {
  let family: WidgetFamily

  private var themeColor: Color {
    WidgetDataManager.shared.loadThemeColor()
  }

  var body: some View {
    if family == .accessoryCircular {
      VStack(spacing: 2) {
        Image(systemName: "crown.fill")
          .font(.system(size: 16))
          .foregroundStyle(themeColor)
        VStack(alignment: .center) {
          Text("Unlock")
            .font(.system(size: 8))
            .foregroundColor(.primary)
          Text("Super")
            .font(.system(size: 8))
            .foregroundColor(.primary)
        }
      }
    } else {
      VStack(spacing: family == .systemLarge ? 16 : (family == .systemMedium ? 12 : 8)) {
        Image(systemName: "crown.fill")
          .font(.system(size: family == .systemLarge ? 40 : (family == .systemMedium ? 28 : 24)))
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
}

// MARK: - Circular (Lock Screen) Widget View

struct CircularTodayDoodleView: View {
  let todayData: TodayDoodleData

  private var themeColor: Color {
    WidgetDataManager.shared.loadThemeColor()
  }

  var body: some View {
    if todayData.hasDrawing, let drawingData = todayData.drawingData {
      ZStack {
        TodayDoodleJoodleView(drawingData: drawingData, family: .accessoryCircular)
          .padding(8)
      }
      .containerBackground(for: .widget) {
        Color.clear
      }
    } else {
      ZStack {
        Circle()
          .strokeBorder(lineWidth: 2)
          .foregroundStyle(.secondary.opacity(0.3))

        Image(systemName: "pencil.tip")
          .font(.system(size: 24))
          .foregroundStyle(.secondary)
      }
      .containerBackground(for: .widget) {
        Color.clear
      }
    }
  }
}

// MARK: - Small Widget View

struct SmallTodayDoodleView: View {
  let todayData: TodayDoodleData

  var body: some View {
    VStack(spacing: 0) {
      VStack {
        Spacer()
        // Joodle or text content
        if todayData.hasDrawing, let drawingData = todayData.drawingData {
          TodayDoodleJoodleView(drawingData: drawingData, family: .systemSmall)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if todayData.hasText, let text = todayData.text {
          Text(text)
            .font(.system(size: 12))
            .lineLimit(4)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
        Spacer()
      }
    }
    .containerBackground(for: .widget) {
      Color(UIColor.systemBackground)
    }
  }
}

// MARK: - Medium Widget View

struct MediumTodayDoodleView: View {
  let todayData: TodayDoodleData

  var body: some View {
    VStack(spacing: 0) {
      // Top bar with date
      HStack {
        Text(formatDate(todayData.date))
          .font(.system(size: 12))
          .foregroundColor(.secondary)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 8)

      // Main content area
      HStack(spacing: 12) {
        // Left side: Joodle or placeholder
        if todayData.hasDrawing, let drawingData = todayData.drawingData {
          TodayDoodleJoodleView(drawingData: drawingData, family: .systemMedium)
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
        if todayData.hasText, let text = todayData.text {
          Text(text)
            .font(.system(size: 12))
            .lineLimit(5)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Text("No notes for today.")
            .font(.system(size: 12))
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

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}

// MARK: - Large Widget View

struct LargeTodayDoodleView: View {
  let todayData: TodayDoodleData

  var body: some View {
    VStack(spacing: 8) {
      VStack {
        Spacer()
        // Joodle or text content
        if todayData.hasDrawing, let drawingData = todayData.drawingData {
          TodayDoodleJoodleView(drawingData: drawingData, family: .systemLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if todayData.hasText, let text = todayData.text {
          Text(text)
            .font(.system(size: 20))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
        Spacer()
      }
    }
    .containerBackground(for: .widget) {
      Color(UIColor.systemBackground)
    }
    .padding()
  }
}

// MARK: - Joodle View

struct TodayDoodleJoodleView: View {
  let drawingData: Data
  let family: WidgetFamily

  /// Theme color loaded from shared preferences
  private var themeColor: Color {
    WidgetDataManager.shared.loadThemeColor()
  }

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
          with: .color(themeColor),
          style: StrokeStyle(
            lineWidth: (family == .accessoryCircular ? 10.0 : 5.0) * scale,
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

// MARK: - No Today Doodle View

struct NoTodayDoodleView: View {
  let family: WidgetFamily

  var body: some View {
    if family == .accessoryCircular {
      ZStack {
        Circle()
          .strokeBorder(lineWidth: 2)
          .foregroundStyle(.secondary.opacity(0.3))

        Image(systemName: "pencil.tip")
          .font(.system(size: 24))
          .foregroundStyle(.secondary)
      }
      .containerBackground(for: .widget) {
        Color.clear
      }
    } else {
      VStack(alignment: .center, spacing: 8) {
        Image(systemName: "pencil.and.scribble")
          .font(.system(size: family == .systemSmall ? 32 : family == .systemMedium ? 40 : 48))
          .foregroundColor(.secondary.opacity(0.3))
        Text("No Joodle today")
          .font(family == .systemSmall ? .system(size: 11) : family == .systemMedium ? .system(size: 11) : .system(size: 15))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding()
      .containerBackground(for: .widget) {
        Color(UIColor.systemBackground)
      }
    }
  }
}

// MARK: - Widget Configuration

struct TodayDoodleWidget: Widget {
  let kind: String = "TodayDoodleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayDoodleProvider()) { entry in
      TodayDoodleWidgetView(entry: entry)
    }
    .configurationDisplayName("Today's Joodle")
    .description("Shows today's Joodle entry.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular])
  }
}
