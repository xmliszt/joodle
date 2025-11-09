//
//  CountdownHelper.swift
//  GoodDay
//
//  Shared utility for countdown text generation
//

import Foundation

struct CountdownHelper {
  /// Generate countdown text from now to target date
  /// Returns the formatted countdown string (e.g., "in 5h 39m", "in 2 days", etc.)
  static func countdownText(from now: Date, to targetDate: Date) -> String {
    let calendar = Calendar.current
    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: now,
      to: targetDate
    )

    guard let years = components.year,
      let months = components.month,
      let days = components.day,
      let hours = components.hour,
      let minutes = components.minute,
      let seconds = components.second
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

    // More than 1 day: show days only
    if days > 1 {
      return "in \(days) days"
    }

    if days == 1 {
      return "in 1 day"
    }

    // Same day or next day with less than 24 hours: show hours, minutes, seconds
    if days == 0 && (hours > 0 || minutes > 0 || seconds > 0) {
      var parts: [String] = []

      if hours > 0 {
        if hours == 1 {
          parts.append("1h")
        } else {
          parts.append("\(hours)h")
        }
      }

      if minutes > 0 {
        if minutes == 1 {
          parts.append("1m")
        } else {
          parts.append("\(minutes)m")
        }
      }

      // More than 1 hour, only show hours and minutes
      if hours >= 1 {
        return "in " + parts.joined(separator: " ")
      }

      if seconds > 0 {
        if seconds == 1 {
          parts.append("1s")
        } else {
          parts.append("\(seconds)s")
        }
      }

      if parts.isEmpty {
        return "now"
      }

      return "in " + parts.joined(separator: " ")
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
  /// Returns true if within the time range that requires frequent updates
  static func needsRealTimeUpdates(from now: Date, to targetDate: Date) -> Bool {
    let totalSeconds = targetDate.timeIntervalSince(now)
    let totalHours = totalSeconds / 3600

    // Need updates if within 24 hours
    return totalHours > 0 && totalHours <= 24
  }

  /// Calculate the appropriate timer interval based on time remaining
  /// Returns the interval in seconds for how often to update the countdown
  static func timerInterval(from now: Date, to targetDate: Date) -> TimeInterval {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour, .minute], from: now, to: targetDate)

    let hours = components.hour ?? 0
    let minutes = components.minute ?? 0

    // More than 1 hour: update every minute (showing hours + minutes)
    if hours >= 1 {
      return 60.0
    }

    // Less than 1 hour: update every second (showing minutes + seconds)
    if minutes > 0 {
      return 1.0
    }

    // Less than 1 minute: update every second for precise countdown
    return 1.0
  }
}
