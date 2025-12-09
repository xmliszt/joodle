//
//  Item.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation
import SwiftData

@Model
final class DayEntry {
  /// The unique identifier for this entry in "yyyy-MM-dd" format
  /// This is timezone-agnostic - once set, it represents that calendar day forever
  /// Note: Uniqueness is enforced in code during creation, not via @Attribute(.unique)
  /// to allow lightweight schema migration from older versions without dateString
  var dateString: String = ""

  var body: String = ""

  /// Legacy timestamp - kept for backward compatibility and sorting
  /// For new entries, this is set to noon UTC of the dateString date
  var createdAt: Date = Date()

  var drawingData: Data?

  // Pre-rendered thumbnails for optimized display
  var drawingThumbnail20: Data?  // 20px for year grid view
  var drawingThumbnail200: Data?  // 200px for detail view
  var drawingThumbnail1080: Data?  // 1080px for sharing

  /// Creates a new DayEntry for a specific date
  /// - Parameters:
  ///   - body: The text content of the entry
  ///   - date: The date this entry represents (will be converted to dateString using local calendar)
  ///   - drawingData: Optional drawing data
  init(body: String, createdAt date: Date, drawingData: Data? = nil) {
    self.body = body
    self.dateString = Self.dateToString(date)
    // Store as noon UTC to avoid any edge-case timezone issues with the legacy Date field
    self.createdAt = Self.stringToDate(self.dateString) ?? date
    self.drawingData = drawingData
    self.drawingThumbnail20 = nil
    self.drawingThumbnail200 = nil
    self.drawingThumbnail1080 = nil
  }

  // MARK: - Date String Conversion Helpers

  /// Shared DateFormatter for consistent date string formatting
  /// Uses a fixed format that's not affected by locale or timezone for storage
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current // Use current timezone when creating entries
    return formatter
  }()

  /// UTC DateFormatter for creating stable Date objects from dateString
  private static let utcDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter
  }()

  /// Converts a Date to a dateString using the current calendar/timezone
  /// - Parameter date: The date to convert
  /// - Returns: A string in "yyyy-MM-dd" format representing the local calendar date
  static func dateToString(_ date: Date) -> String {
    // Create a new formatter each time to ensure we use the CURRENT timezone
    // This is important because timezone can change during app lifetime
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
  }

  /// Converts a dateString back to a Date (at noon UTC for internal storage stability)
  /// - Parameter dateString: A string in "yyyy-MM-dd" format
  /// - Returns: A Date representing noon UTC on that day, or nil if parsing fails
  static func stringToDate(_ dateString: String) -> Date? {
    return utcDateFormatter.date(from: "\(dateString) 12:00:00")
  }

  /// Converts a dateString to a Date at start of day in the user's current timezone
  /// This is appropriate for countdown calculations and display
  /// - Parameter dateString: A string in "yyyy-MM-dd" format
  /// - Returns: A Date representing start of day in current timezone, or nil if parsing fails
  static func stringToLocalDate(_ dateString: String) -> Date? {
    let components = dateString.split(separator: "-")
    guard components.count == 3,
          let year = Int(components[0]),
          let month = Int(components[1]),
          let day = Int(components[2]) else {
      return nil
    }

    var dateComponents = DateComponents()
    dateComponents.year = year
    dateComponents.month = month
    dateComponents.day = day
    dateComponents.hour = 0
    dateComponents.minute = 0
    dateComponents.second = 0

    return Calendar.current.date(from: dateComponents)
  }

  /// Returns a Date representation of this entry's date (at start of day in user's current timezone)
  /// Use this for display purposes, countdown calculations, and when you need a Date object
  var displayDate: Date {
    Self.stringToLocalDate(dateString) ?? createdAt
  }

  /// Returns the year component of this entry
  var year: Int {
    let components = dateString.split(separator: "-")
    return Int(components[0]) ?? Calendar.current.component(.year, from: createdAt)
  }

  /// Returns the month component of this entry (1-12)
  var month: Int {
    let components = dateString.split(separator: "-")
    return Int(components[1]) ?? Calendar.current.component(.month, from: createdAt)
  }

  /// Returns the day component of this entry (1-31)
  var day: Int {
    let components = dateString.split(separator: "-")
    return Int(components[2]) ?? Calendar.current.component(.day, from: createdAt)
  }

  /// Checks if this entry matches a given date (using dateString comparison)
  /// - Parameter date: The date to compare against
  /// - Returns: True if this entry represents the same calendar day
  func matches(date: Date) -> Bool {
    return dateString == Self.dateToString(date)
  }
}
