//
//  CountdownHelper.swift
//  Joodle
//
//  Shared utility for countdown text generation
//

import Foundation

struct CountdownHelper {
  /// Generate countdown text from now to target date
  /// Returns the formatted countdown string (e.g., "Tomorrow", "in 2 days", etc.)
  /// For entries 1 calendar day away, shows "Tomorrow" since Joodle tracks days, not timestamps
  static func countdownText(from now: Date, to targetDate: Date) -> String {
    let calendar = Calendar.current

    // Calculate calendar day difference (ignoring time of day)
    let startOfToday = calendar.startOfDay(for: now)
    let startOfTarget = calendar.startOfDay(for: targetDate)
    let calendarDayDiff = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0

    // Use time-based components for months and years display
    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: now,
      to: targetDate
    )

    guard let years = components.year,
      let months = components.month,
      let days = components.day
    else { return "" }

    // More than a year: show year + month + day
    if years > 0 {
      var parts: [String] = []

      if years == 1 {
        parts.append("1 year")
      } else {
        parts.append("\(years) years")
      }

      if months > 0 {
        if months == 1 {
          parts.append("1 month")
        } else {
          parts.append("\(months) months")
        }
      }

      if days > 0 {
        if days == 1 {
          parts.append("1 day")
        } else {
          parts.append("\(days) days")
        }
      }

      return "in " + parts.joined(separator: ", ")
    }

    // More than a month but less than a year: show month + day
    if months > 0 {
      var parts: [String] = []

      if months == 1 {
        parts.append("1 month")
      } else {
        parts.append("\(months) months")
      }

      if days > 0 {
        if days == 1 {
          parts.append("1 day")
        } else {
          parts.append("\(days) days")
        }
      }

      return "in " + parts.joined(separator: ", ")
    }

    // Less than a month: use calendar day difference for accuracy
    // This ensures D+1 shows "Tomorrow" and D+2 shows "in 2 days"
    // regardless of the current time of day
    if calendarDayDiff > 1 {
      return "in \(calendarDayDiff) days"
    }

    // 1 calendar day away: show "Tomorrow"
    // This is because Joodle tracks entries by day, not by exact timestamp
    if calendarDayDiff == 1 {
      return "Tomorrow"
    }

    return ""
  }

  /// Format date as "MMM d, yyyy" (e.g., "Jan 15, 2025")
  static func dateText(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: date)
  }

  /// Check if we need real-time updates for countdown
  /// Returns false since we only show "Tomorrow" for sub-day countdowns,
  /// which doesn't require frequent updates
  static func needsRealTimeUpdates(from now: Date, to targetDate: Date) -> Bool {
    // No need for real-time updates since we show "Tomorrow" for <= 1 day
    // and day-based countdown for > 1 day
    return false
  }

  /// Calculate the appropriate timer interval based on time remaining
  /// Returns the interval in seconds for how often to update the countdown
  /// Since we only track days (not hours/minutes/seconds), we update less frequently
  static func timerInterval(from now: Date, to targetDate: Date) -> TimeInterval {
    // Update once per hour is sufficient since we only show day-level precision
    // or "Tomorrow" for sub-day countdowns
    return 3600.0
  }
}
