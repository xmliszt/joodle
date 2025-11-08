//
//  WidgetDataManager.swift
//  Widgets
//
//  Created by Widget Extension
//

import Foundation

/// Data model for encoding/decoding entries to share with widget
/// Note: Drawing data is included optionally for widgets that need to display the actual drawing
struct WidgetEntryData: Codable {
  let date: Date
  let hasText: Bool
  let hasDrawing: Bool
  let drawingData: Data?
  let body: String?

  init(date: Date, hasText: Bool, hasDrawing: Bool, drawingData: Data? = nil, body: String? = nil) {
    self.date = date
    self.hasText = hasText
    self.hasDrawing = hasDrawing
    self.drawingData = drawingData
    self.body = body
  }
}

/// Helper class for managing widget data updates
struct WidgetDataManager {
  static let shared = WidgetDataManager()

  private let appGroupIdentifier = "group.dev.liyuxuan.GoodDay"
  private let entriesKey = "widgetEntries"

  private init() {}

  /// Save entries to shared container for widget access
  func saveEntries(_ entries: [WidgetEntryData]) {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults")
      return
    }

    do {
      let data = try JSONEncoder().encode(entries)
      sharedDefaults.set(data, forKey: entriesKey)
      sharedDefaults.synchronize()
    } catch {
      print("Failed to encode widget entries: \(error)")
    }
  }

  /// Load entries from shared container
  func loadEntries() -> [WidgetEntryData] {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults")
      return []
    }

    guard let data = sharedDefaults.data(forKey: entriesKey) else {
      return []
    }

    do {
      let allEntries = try JSONDecoder().decode([WidgetEntryData].self, from: data)

      // Filter to current year only to reduce memory usage
      let calendar = Calendar.current
      let currentYear = calendar.component(.year, from: Date())

      let filteredEntries = allEntries.filter { entry in
        calendar.component(.year, from: entry.date) == currentYear
      }

      return filteredEntries
    } catch {
      print("Failed to decode widget entries: \(error)")
      return []
    }
  }

  /// Load all entries including future dates (for anniversary widget)
  func loadAllEntries() -> [WidgetEntryData] {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults")
      return []
    }

    guard let data = sharedDefaults.data(forKey: entriesKey) else {
      return []
    }

    do {
      return try JSONDecoder().decode([WidgetEntryData].self, from: data)
    } catch {
      print("Failed to decode widget entries: \(error)")
      return []
    }
  }
}
