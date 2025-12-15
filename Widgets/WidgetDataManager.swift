//
//  WidgetDataManager.swift
//  Widgets
//
//  Created by Widget Extension
//

import Foundation
import SwiftUI
import UIKit

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
  private let themeColorKey = "widgetThemeColor"

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

      // If not marked as subscribed, return false immediately
      guard status.isSubscribed else {
        return false
      }

      // If we have an expiration date, use it to determine validity
      // This handles the case where user cancelled but still has active trial/subscription
      if let expirationDate = status.expirationDate {
        return Date() < expirationDate
      }

      // No expiration date but marked as subscribed - trust the cached status if recent
      // Fall back to validity check only when there's no expiration date
      return status.isValid
    } catch {
      print("Failed to decode subscription status: \(error)")
      return false
    }
  }

  // MARK: - Theme Color

  /// Load the user's selected theme color for widget display
  /// - Returns: The Color to use for accent in widgets
  func loadThemeColor() -> Color {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      return resolveThemeColor(named: "Themes/Orange")
    }

    guard let colorName = sharedDefaults.string(forKey: themeColorKey) else {
      return resolveThemeColor(named: "Themes/Orange")
    }

    // Return the color from the Themes asset catalog, resolved through UIColor
    return resolveThemeColor(named: "Themes/\(colorName)")
  }

  /// Resolves a named color through UIColor to ensure it works in Canvas
  /// - Parameter named: The color name in the asset catalog
  /// - Returns: A Color that is properly resolved for use in Canvas
  private func resolveThemeColor(named: String) -> Color {
    // Use UIColor to resolve the color from the asset catalog
    // This ensures the color is concrete and works in Canvas drawing contexts
    if let uiColor = UIColor(named: named) {
      return Color(uiColor)
    }
    // Fallback to a default orange color if asset not found
    return Color(UIColor(red: 1.0, green: 0.36, blue: 0.1, alpha: 1.0))
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
