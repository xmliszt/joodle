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
  let hasPremiumAccess: Bool
  let expirationDate: Date?
  let lastUpdated: Date

  init(hasPremiumAccess: Bool, expirationDate: Date? = nil) {
    self.hasPremiumAccess = hasPremiumAccess
    self.expirationDate = expirationDate
    self.lastUpdated = Date()
  }

  private enum CodingKeys: String, CodingKey {
    case hasPremiumAccess = "isSubscribed"
    case expirationDate
    case lastUpdated
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
  /// The calendar date string "yyyy-MM-dd" - timezone agnostic
  /// This is the SINGLE SOURCE OF TRUTH for the entry's date
  let dateString: String
  let hasText: Bool
  let hasDrawing: Bool
  let drawingData: Data?
  let thumbnail: Data?
  let body: String?

  /// Computed property for display purposes - converts dateString to Date in current timezone
  /// Use this when UI components require a Date object
  var date: Date {
    // Parse dateString components and create Date at start of day in current timezone
    let components = dateString.split(separator: "-")
    if components.count == 3,
       let year = Int(components[0]),
       let month = Int(components[1]),
       let day = Int(components[2]) {
      var dateComponents = DateComponents()
      dateComponents.year = year
      dateComponents.month = month
      dateComponents.day = day
      dateComponents.hour = 0
      dateComponents.minute = 0
      dateComponents.second = 0
      return Calendar.current.date(from: dateComponents) ?? Date()
    }
    return Date()
  }

  /// Preferred initializer using dateString for timezone-agnostic storage
  init(dateString: String, hasText: Bool, hasDrawing: Bool, drawingData: Data? = nil, thumbnail: Data? = nil, body: String? = nil) {
    self.dateString = dateString
    self.hasText = hasText
    self.hasDrawing = hasDrawing
    self.drawingData = drawingData
    self.thumbnail = thumbnail
    self.body = body
  }

  /// Legacy initializer for backward compatibility during migration
  /// Converts Date to dateString using current timezone at the moment of creation
  init(date: Date, hasText: Bool, hasDrawing: Bool, drawingData: Data? = nil, thumbnail: Data? = nil, body: String? = nil) {
    // Convert Date to dateString using current timezone
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    self.dateString = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 1, components.day ?? 1)
    self.hasText = hasText
    self.hasDrawing = hasDrawing
    self.drawingData = drawingData
    self.thumbnail = thumbnail
    self.body = body
  }

  // MARK: - Codable Migration Support

  private enum CodingKeys: String, CodingKey {
    case dateString
    case date  // Legacy key for backward compatibility
    case hasText
    case hasDrawing
    case drawingData
    case thumbnail
    case body
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Try to decode dateString first (new format)
    if let dateString = try container.decodeIfPresent(String.self, forKey: .dateString) {
      self.dateString = dateString
    }
    // Fall back to decoding legacy Date and converting to dateString
    else if let legacyDate = try container.decodeIfPresent(Date.self, forKey: .date) {
      let components = Calendar.current.dateComponents([.year, .month, .day], from: legacyDate)
      self.dateString = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 1, components.day ?? 1)
    }
    // Default to today if neither exists (shouldn't happen)
    else {
      let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
      self.dateString = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 1, components.day ?? 1)
    }

    self.hasText = try container.decode(Bool.self, forKey: .hasText)
    self.hasDrawing = try container.decode(Bool.self, forKey: .hasDrawing)
    self.drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData)
    self.thumbnail = try container.decodeIfPresent(Data.self, forKey: .thumbnail)
    self.body = try container.decodeIfPresent(String.self, forKey: .body)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // Only encode dateString (new format) - don't encode legacy date
    try container.encode(dateString, forKey: .dateString)
    try container.encode(hasText, forKey: .hasText)
    try container.encode(hasDrawing, forKey: .hasDrawing)
    try container.encodeIfPresent(drawingData, forKey: .drawingData)
    try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
    try container.encodeIfPresent(body, forKey: .body)
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

  /// Check if user has premium access for widget features
  func hasPremiumAccess() -> Bool {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      return false
    }

    guard let data = sharedDefaults.data(forKey: subscriptionKey) else {
      return false
    }

    do {
      let status = try JSONDecoder().decode(WidgetSubscriptionStatus.self, from: data)

      // If not marked as subscribed, return false immediately
      guard status.hasPremiumAccess else {
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
