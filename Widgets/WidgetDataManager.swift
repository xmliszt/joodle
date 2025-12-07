//
//  WidgetDataManager.swift
//  Widgets
//
//  Created by Widget Extension
//

import Foundation

// MARK: - Subscription Status for Widget

/// Subscription status shared between main app and widget extension
struct WidgetSubscriptionStatus: Codable {
  let isSubscribed: Bool
  let expirationDate: Date?
  let lastUpdated: Date

  init(isSubscribed: Bool, expirationDate: Date? = nil) {
    self.isSubscribed = isSubscribed
    self.expirationDate = expirationDate
    self.lastUpdated = Date()
  }

  /// Check if status is still valid (updated within last hour)
  var isValid: Bool {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    return lastUpdated > oneHourAgo
  }
}

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

/// Helper class for managing widget data updates
struct WidgetDataManager {
  static let shared = WidgetDataManager()

  private let appGroupIdentifier = "group.dev.liyuxuan.joodle"
  private let entriesKey = "widgetEntries"
  private let subscriptionKey = "widgetSubscriptionStatus"

  private init() {}

  // MARK: - Subscription Status

  /// Check if user has active subscription for widget features
  func isSubscribed() -> Bool {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      return false
    }

    guard let data = sharedDefaults.data(forKey: subscriptionKey) else {
      return false
    }

    do {
      let status = try JSONDecoder().decode(WidgetSubscriptionStatus.self, from: data)
      // If status is valid and user is subscribed, return true
      // If status is stale (over 1 hour old), default to false for safety
      return status.isValid && status.isSubscribed
    } catch {
      print("Failed to decode subscription status: \(error)")
      return false
    }
  }

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
