//
//  CalendarGridHelper.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Foundation

// MARK: - Constants

/// Start of week configuration: "sunday" or "monday"
let START_OF_WEEK: String = "sunday"

// MARK: - Calendar Grid Helper

enum CalendarGridHelper {
  /// Calculate the number of empty slots needed at the beginning of the grid
  /// to align the first day of the year with the correct weekday column.
  ///
  /// This is only applicable for calendar week view (7 days per row).
  ///
  /// - Parameters:
  ///   - year: The year to calculate for
  ///   - startOfWeek: The start of week preference ("sunday" or "monday")
  /// - Returns: Number of empty slots needed at the beginning
  ///
  /// Example: For 2025 with Sunday start:
  /// - January 1, 2025 is a Wednesday (weekday = 4)
  /// - Leading empty slots = 4 - 1 = 3 (for Sunday, Monday, Tuesday)
  /// - First row: [empty, empty, empty, Wed Jan 1, Thu Jan 2, Fri Jan 3, Sat Jan 4]
  static func leadingEmptySlots(for year: Int, startOfWeek: String = START_OF_WEEK) -> Int {
    let calendar = Calendar.current
    guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
      return 0
    }

    // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    let weekday = calendar.component(.weekday, from: startOfYear)

    if startOfWeek.lowercased() == "sunday" {
      // Sunday start: Sunday = column 0, Monday = column 1, ..., Saturday = column 6
      // offset = weekday - 1
      return weekday - 1
    } else {
      // Monday start: Monday = column 0, ..., Sunday = column 6
      // If weekday is Sunday (1), offset = 6 (Sunday is last day of week)
      // If weekday is Monday (2), offset = 0
      // Formula: (weekday - 2 + 7) % 7
      return (weekday - 2 + 7) % 7
    }
  }
}
