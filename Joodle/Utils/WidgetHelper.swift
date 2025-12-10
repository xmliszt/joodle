//
//  WidgetHelper.swift
//  Joodle
//
//  Created by Widget Helper
//

import Foundation
import WidgetKit

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

/// Helper class for updating widget data from the main app
///
/// This class is responsible for syncing data between the main app and the widget.
/// It stores simplified entry data in shared UserDefaults and triggers widget reloads.
///
/// Usage: Call `updateWidgetData(with:)` whenever entries change in the main app.
/// The widget will automatically update via `@Query` observers in ContentView.
class WidgetHelper {
  static let shared = WidgetHelper()

  private let appGroupIdentifier = "group.dev.liyuxuan.joodle"
  private let entriesKey = "widgetEntries"
  private let subscriptionKey = "widgetSubscriptionStatus"

  private init() {}

  // MARK: - Subscription Status

  /// Update subscription status for widget extension
  @MainActor func updateSubscriptionStatus() {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget subscription")
      return
    }

    let status = WidgetSubscriptionStatus(
      isSubscribed: SubscriptionManager.shared.isSubscribed,
      expirationDate: SubscriptionManager.shared.subscriptionExpirationDate
    )

    do {
      let data = try JSONEncoder().encode(status)
      sharedDefaults.set(data, forKey: subscriptionKey)
      sharedDefaults.synchronize()

      // Reload widgets to reflect subscription change
      WidgetCenter.shared.reloadAllTimelines()
    } catch {
      print("Failed to encode subscription status: \(error)")
    }
  }

  /// Load subscription status (for widget extension use)
  static func loadSubscriptionStatus(from sharedDefaults: UserDefaults) -> WidgetSubscriptionStatus? {
    guard let data = sharedDefaults.data(forKey: "widgetSubscriptionStatus") else {
      return nil
    }

    do {
      return try JSONDecoder().decode(WidgetSubscriptionStatus.self, from: data)
    } catch {
      print("Failed to decode subscription status: \(error)")
      return nil
    }
  }

  /// Update widget data with current entries from SwiftData and reload widget timelines
  ///
  /// This method:
  /// 1. Converts DayEntry objects to WidgetEntryData (excluding drawing data for memory efficiency)
  /// 2. Saves the data to shared UserDefaults accessible by the widget
  /// 3. Triggers widget timeline reload to display updated data
  ///
  /// - Parameter entries: Array of DayEntry objects from SwiftData
  @MainActor func updateWidgetData(with entries: [DayEntry]) {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget")
      return
    }

    // Convert DayEntry to WidgetEntryData
    // Note: Drawing data is included to support widgets that display actual drawings
    // Use displayDate which is timezone-agnostic (stable noon UTC)
    let widgetEntries = entries.map { entry in
      WidgetEntryData(
        date: entry.displayDate,
        hasText: !entry.body.isEmpty,
        hasDrawing: entry.drawingData != nil && !(entry.drawingData?.isEmpty ?? true),
        drawingData: entry.drawingData,
        thumbnail: entry.drawingThumbnail200,
        body: entry.body.isEmpty ? nil : entry.body
      )
    }

    // Encode and save to shared UserDefaults
    do {
      let data = try JSONEncoder().encode(widgetEntries)
      sharedDefaults.set(data, forKey: entriesKey)
      sharedDefaults.synchronize()

      // Also update subscription status
      updateSubscriptionStatus()

      // Reload widget timelines
      WidgetCenter.shared.reloadAllTimelines()
    } catch {
      print("Failed to encode widget entries: \(error)")
    }
  }
}
