//
//  WidgetHelper.swift
//  GoodDay
//
//  Created by Widget Helper
//

import Foundation
import WidgetKit

/// Data model for encoding/decoding entries to share with widget
/// Note: Drawing data is excluded to reduce memory usage in widget (30MB limit)
struct WidgetEntryData: Codable {
  let date: Date
  let hasText: Bool
  let hasDrawing: Bool

  init(date: Date, hasText: Bool, hasDrawing: Bool) {
    self.date = date
    self.hasText = hasText
    self.hasDrawing = hasDrawing
  }
}

/// Helper class for updating widget data from the main app
class WidgetHelper {
  static let shared = WidgetHelper()

  private let appGroupIdentifier = "group.dev.liyuxuan.GoodDay"
  private let entriesKey = "widgetEntries"

  private init() {}

  /// Update widget data with current entries from SwiftData
  func updateWidgetData(with entries: [DayEntry]) {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget")
      return
    }

    // Convert DayEntry to WidgetEntryData
    // Note: Drawing data is NOT included to keep widget memory usage under 30MB limit
    let widgetEntries = entries.map { entry in
      WidgetEntryData(
        date: entry.createdAt,
        hasText: !entry.body.isEmpty,
        hasDrawing: entry.drawingData != nil && !(entry.drawingData?.isEmpty ?? true)
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

  /// Update widget immediately (call after saving/deleting entries)
  func reloadWidget() {
    WidgetCenter.shared.reloadAllTimelines()
  }
}
