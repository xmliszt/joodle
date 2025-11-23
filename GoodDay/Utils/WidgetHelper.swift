//
//  WidgetHelper.swift
//  GoodDay
//
//  Created by Widget Helper
//

import Foundation
import WidgetKit

/// Data model for encoding/decoding entries to share with widget
/// Note: Drawing data is included optionally for widgets that need to display the actual drawing
struct WidgetEntryData: Codable {
  let date: Date
  let hasText: Bool
  let hasDrawing: Bool
  let drawingData: Data?
  let thumbnail: Data?
  let body: String?

  init(date: Date, hasText: Bool, hasDrawing: Bool, drawingData: Data? = nil, thumbnail: Data? = nil, body: String? = nil) {
    self.date = date
    self.hasText = hasText
    self.hasDrawing = hasDrawing
    self.drawingData = drawingData
    self.thumbnail = thumbnail
    self.body = body
  }
}

/// Helper class for updating widget data from the main app
///
/// This class is responsible for syncing data between the main app and the widget.
/// It stores simplified entry data in shared UserDefaults and triggers widget reloads.
///
/// Usage: Call `updateWidgetData(with:)` whenever entries change in the main app.
/// The widget will automatically update via `@Query` observers in ContentView.
class WidgetHelper {
  static let shared = WidgetHelper()

  private let appGroupIdentifier = "group.dev.liyuxuan.GoodDay"
  private let entriesKey = "widgetEntries"

  private init() {}

  /// Update widget data with current entries from SwiftData and reload widget timelines
  ///
  /// This method:
  /// 1. Converts DayEntry objects to WidgetEntryData (excluding drawing data for memory efficiency)
  /// 2. Saves the data to shared UserDefaults accessible by the widget
  /// 3. Triggers widget timeline reload to display updated data
  ///
  /// - Parameter entries: Array of DayEntry objects from SwiftData
  func updateWidgetData(with entries: [DayEntry]) {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget")
      return
    }

    // Convert DayEntry to WidgetEntryData
    // Note: Drawing data is included to support widgets that display actual drawings
    let widgetEntries = entries.map { entry in
      WidgetEntryData(
        date: entry.createdAt,
        hasText: !entry.body.isEmpty,
        hasDrawing: entry.drawingData != nil && !(entry.drawingData?.isEmpty ?? true),
        drawingData: entry.drawingData,
        thumbnail: entry.drawingThumbnail20,
        body: entry.body.isEmpty ? nil : entry.body
      )
    }

    // Encode and save to shared UserDefaults
    do {
      let data = try JSONEncoder().encode(widgetEntries)
      sharedDefaults.set(data, forKey: entriesKey)
      sharedDefaults.synchronize()

      // Reload widget timelines
      WidgetCenter.shared.reloadAllTimelines()
    } catch {
      print("Failed to encode widget entries: \(error)")
    }
  }
}
