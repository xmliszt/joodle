//
//  WidgetHelper.swift
//  Joodle
//
//  Created by Widget Helper
//

import Foundation
import SwiftUI
import WidgetKit
import SwiftData

// NOTE: WidgetSubscriptionStatus is defined in Shared/WidgetSubscriptionStatus.swift
// and compiled into both the main app and widget extension targets.

// Note: WidgetEntryData is defined in Widgets/WidgetDataManager.swift
// This file uses the same model via App Group shared storage

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
  private let themeColorKey = "widgetThemeColor"

  private init() {}

  // MARK: - Subscription Status

  /// Update subscription status for widget extension
  @MainActor func updateSubscriptionStatus() {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget subscription")
      return
    }

    // For lifetime users, use .distantFuture so the widget always has a concrete
    // expiration date to check against, avoiding any nil-expiration edge cases.
    let expirationDate: Date? = SubscriptionManager.shared.isLifetimeUser
      ? .distantFuture
      : SubscriptionManager.shared.subscriptionExpirationDate

    let status = WidgetSubscriptionStatus(
      hasPremiumAccess: SubscriptionManager.shared.hasPremiumAccess,
      expirationDate: expirationDate
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

  // MARK: - Theme Color

  /// Update theme color for widget extension
  @MainActor func updateThemeColor() {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget theme color")
      return
    }

    let colorName = UserPreferences.shared.accentColor.rawValue
    sharedDefaults.set(colorName, forKey: themeColorKey)
    sharedDefaults.synchronize()

    // Reload widgets to reflect theme color change
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// Load theme color for widget extension use
  /// - Parameter sharedDefaults: The shared UserDefaults from App Group
  /// - Returns: The Color to use for accent, defaults to asset catalog accent if not set
  static func loadThemeColor(from sharedDefaults: UserDefaults) -> Color {
    guard let colorName = sharedDefaults.string(forKey: "widgetThemeColor"),
          let themeColor = ThemeColor(rawValue: colorName) else {
      // Fallback to default theme color
      return ThemeColor.defaultColor.color
    }
    return themeColor.color
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

    // Convert DayEntry to widget-compatible dictionaries
    // Include both drawingData (for larger widgets) and thumbnails (for year grid dots)
    // Use dateString which is timezone-agnostic (the SINGLE SOURCE OF TRUTH)
    let widgetEntries: [[String: Any]] = entries.map { entry in
      var dict: [String: Any] = [
        "dateString": entry.dateString,
        "hasText": !entry.body.isEmpty,
        "hasDrawing": entry.drawingData != nil && !(entry.drawingData?.isEmpty ?? true)
      ]
      if let drawingData = entry.drawingData {
        dict["drawingData"] = drawingData
      }
      if let thumbnail = entry.drawingThumbnail20 {
        dict["thumbnail"] = thumbnail
      }
      if !entry.body.isEmpty {
        dict["body"] = entry.body
      }
      return dict
    }

    // Convert to Codable format for storage
    struct WidgetEntryStorage: Codable {
      let dateString: String
      let hasText: Bool
      let hasDrawing: Bool
      let drawingData: Data?
      let thumbnail: Data?
      let body: String?
    }

    let storageEntries = widgetEntries.map { dict in
      WidgetEntryStorage(
        dateString: dict["dateString"] as? String ?? "",
        hasText: dict["hasText"] as? Bool ?? false,
        hasDrawing: dict["hasDrawing"] as? Bool ?? false,
        drawingData: dict["drawingData"] as? Data,
        thumbnail: dict["thumbnail"] as? Data,
        body: dict["body"] as? String
      )
    }

    // Encode and save to shared UserDefaults
    do {
      let data = try JSONEncoder().encode(storageEntries)
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

  /// Update widget data by fetching entries from the provided ModelContext
  /// This avoids the need to pass all entries from the view
  @MainActor func updateWidgetData(in modelContext: ModelContext) {
    let descriptor = FetchDescriptor<DayEntry>(
      sortBy: [SortDescriptor(\.dateString)]
    )

    do {
      let entries = try modelContext.fetch(descriptor)
      updateWidgetData(with: entries)
    } catch {
      print("Failed to fetch entries for widget update: \(error)")
    }
  }
}
