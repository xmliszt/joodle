//
//  CalendarDate.swift
//  Joodle
//
//  A timezone-agnostic date representation for journal entries.
//

import Foundation

/// A timezone-agnostic date representation containing only year, month, and day.
///
/// This type is intentionally NOT a Swift `Date` - it represents a calendar day that
/// remains constant regardless of the user's timezone. When a user creates a Joodle
/// on "December 25, 2025", that entry should always show as December 25th, even if
/// the user travels to a different timezone.
///
/// ## Usage
/// ```swift
/// // Capture today's date at creation time
/// let today = CalendarDate.today()
///
/// // Parse from stored dateString
/// let date = CalendarDate(dateString: "2025-12-25")
///
/// // Compare dates (timezone-safe)
/// if entryDate > CalendarDate.today() {
///     // This is a future entry (anniversary)
/// }
/// ```
struct CalendarDate: Hashable, Comparable, Codable, Sendable {
  let year: Int
  let month: Int  // 1-12
  let day: Int    // 1-31

  // MARK: - Initialization

  /// Create from year, month, day components
  /// - Parameters:
  ///   - year: The year (e.g., 2025)
  ///   - month: The month (1-12)
  ///   - day: The day (1-31)
  init(year: Int, month: Int, day: Int) {
    self.year = year
    self.month = month
    self.day = day
  }

  /// Create from a dateString in "yyyy-MM-dd" format
  /// - Parameter dateString: A string in "yyyy-MM-dd" format (e.g., "2025-12-25")
  /// - Returns: A CalendarDate if parsing succeeds, nil otherwise
  init?(dateString: String) {
    let components = dateString.split(separator: "-")
    guard components.count == 3,
          let year = Int(components[0]),
          let month = Int(components[1]),
          let day = Int(components[2]),
          (1...12).contains(month),
          (1...31).contains(day)
    else {
      return nil
    }
    self.year = year
    self.month = month
    self.day = day
  }

  /// Capture the current calendar date in the user's current timezone.
  ///
  /// This should be called at the moment of entry creation to lock in the
  /// user's perceived date. Once captured, this date never changes regardless
  /// of timezone changes.
  ///
  /// - Returns: Today's date as a CalendarDate
  static func today() -> CalendarDate {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    return CalendarDate(
      year: components.year ?? 1970,
      month: components.month ?? 1,
      day: components.day ?? 1
    )
  }

  /// Create a CalendarDate from a Swift Date using the current timezone.
  ///
  /// Use this when you need to convert a Date to a CalendarDate. The conversion
  /// uses the current timezone, so call this at the moment of user interaction.
  ///
  /// - Parameter date: The Swift Date to convert
  /// - Returns: A CalendarDate representing the calendar day in the current timezone
  static func from(_ date: Date) -> CalendarDate {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return CalendarDate(
      year: components.year ?? 1970,
      month: components.month ?? 1,
      day: components.day ?? 1
    )
  }

  // MARK: - String Representation

  /// The canonical string representation in "yyyy-MM-dd" format.
  ///
  /// This format is used for storage in SwiftData and comparison operations.
  /// The lexicographic ordering of this format preserves chronological order.
  var dateString: String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }

  // MARK: - Display Conversion

  /// Convert to a Swift Date for display purposes.
  ///
  /// Returns the start of day (00:00:00) in the user's current timezone.
  /// Use this when you need a Date for UI components like DatePicker or
  /// for calculating display-friendly relative times.
  ///
  /// - Note: This conversion IS timezone-dependent by design - it creates
  ///         a Date that will display correctly in the user's current timezone.
  var displayDate: Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 0
    components.minute = 0
    components.second = 0
    return Calendar.current.date(from: components) ?? Date()
  }

  /// Format the date for display using the specified style.
  ///
  /// - Parameter style: The date formatting style (default: .long)
  /// - Returns: A localized date string (e.g., "December 25, 2025" for .long)
  func formatted(style: DateFormatter.Style = .long) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = style
    formatter.timeStyle = .none
    return formatter.string(from: displayDate)
  }

  /// Format as "d MMMM yyyy" (e.g., "25 December 2025")
  ///
  /// This matches the existing display format used throughout Joodle.
  var displayString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "d MMMM yyyy"
    return formatter.string(from: displayDate)
  }
  
  var displayStringWithoutYear: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "d MMMM"
    return formatter.string(from: displayDate)
  }

  /// Get the weekday name for this date (e.g., "Monday")
  var weekdayName: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter.string(from: displayDate)
  }

  // MARK: - Comparison Helpers

  /// Check if this date represents today in the user's current timezone.
  var isToday: Bool {
    self == CalendarDate.today()
  }

  /// Check if this date is in the future relative to today.
  var isFuture: Bool {
    self > CalendarDate.today()
  }

  /// Check if this date is in the past relative to today.
  var isPast: Bool {
    self < CalendarDate.today()
  }

  // MARK: - Comparable

  static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
    // Compare year first, then month, then day
    if lhs.year != rhs.year { return lhs.year < rhs.year }
    if lhs.month != rhs.month { return lhs.month < rhs.month }
    return lhs.day < rhs.day
  }

  // MARK: - Codable

  // Default Codable implementation works for simple structs with Codable properties
}

// MARK: - CustomStringConvertible

extension CalendarDate: CustomStringConvertible {
  var description: String {
    dateString
  }
}

// MARK: - ExpressibleByStringLiteral (for convenience in tests/previews)

extension CalendarDate: ExpressibleByStringLiteral {
  init(stringLiteral value: String) {
    if let date = CalendarDate(dateString: value) {
      self = date
    } else {
      // Fallback to today if parsing fails - this should only happen in development
      self = CalendarDate.today()
      assertionFailure("Invalid CalendarDate string literal: \(value)")
    }
  }
}
