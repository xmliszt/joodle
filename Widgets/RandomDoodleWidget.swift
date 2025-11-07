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
    RandomDoodleEntry(date: Date(), doodle: nil)
  }
  
  func getSnapshot(in context: Context, completion: @escaping (RandomDoodleEntry) -> Void) {
    let entry = RandomDoodleEntry(
      date: Date(),
      doodle: getRandomDoodle()
    )
    completion(entry)
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<RandomDoodleEntry>) -> Void)
  {
    let currentDate = Date()
    let doodle = getRandomDoodle()
    
    let entry = RandomDoodleEntry(
      date: currentDate,
      doodle: doodle
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
    
    // Select a stable random doodle based on current day
    // This ensures the same doodle is shown all day regardless of widget reloads
    let daysSince1970 = Int(today.timeIntervalSince1970 / 86400)
    let stableIndex = daysSince1970 % doodleEntries.count
    let selectedEntry = doodleEntries[stableIndex]
    
    return DoodleData(
      date: selectedEntry.date,
      drawingData: selectedEntry.drawingData!
    )
  }
}

struct RandomDoodleEntry: TimelineEntry {
  let date: Date
  let doodle: DoodleData?
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
  
  var body: some View {
    if let doodle = entry.doodle {
      // Show doodle centered with 36pt padding
      DoodleView(drawingData: doodle.drawingData)
        .padding(24)
        .widgetURL(URL(string: "goodday://date/\(Int(doodle.date.timeIntervalSince1970))"))
        .containerBackground(.fill.tertiary, for: .widget)
    } else {
      // Show not found status
      NotFoundView()
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }
  }
}

struct DoodleView: View {
  let drawingData: Data
  
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
          context.fill(scaledPath, with: .color(.accentColor))
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
            with: .color(.accentColor),
            style: StrokeStyle(
              lineWidth: 5.0 * scale,
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
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "scribble")
        .font(.system(size: 32))
        .foregroundColor(.accentColor)
      Text("No Doodle")
        .font(.caption)
        .foregroundColor(.secondary)
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
    .description("Shows a random doodle from past one year.")
    .supportedFamilies([.systemSmall])
  }
}

#Preview(as: .systemSmall) {
  RandomDoodleWidget()
} timeline: {
  // Preview with a doodle
  let mockDrawingData = createMockDrawingData()
  RandomDoodleEntry(
    date: Date(),
    doodle: DoodleData(date: Date(), drawingData: mockDrawingData)
  )
  
  // Preview without a doodle
  RandomDoodleEntry(date: Date(), doodle: nil)
}

// Mock drawing data for preview
private func createMockDrawingData() -> Data {
  struct PathData: Codable {
    let points: [CGPoint]
    let isDot: Bool
  }
  
  // Draw a rectangle around the border of the 300x300 canvas
  let paths = [
    // Border rectangle
    PathData(
      points: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 300, y: 0),
        CGPoint(x: 300, y: 300),
        CGPoint(x: 0, y: 300),
        CGPoint(x: 0, y: 0),
      ], isDot: false),
    // Diagonal lines to show the full area
    PathData(
      points: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 300, y: 300),
      ], isDot: false),
    PathData(
      points: [
        CGPoint(x: 300, y: 0),
        CGPoint(x: 0, y: 300),
      ], isDot: false),
  ]
  
  return (try? JSONEncoder().encode(paths)) ?? Data()
}
