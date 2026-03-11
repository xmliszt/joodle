//
//  CountdownHelper.swift
//  Joodle
//
//  Shared utility for countdown text generation
//

import Foundation

struct CountdownHelper {
  private static var resolvedLanguageCode: String {
    if let resolved = Bundle.main.preferredLocalizations.first, !resolved.isEmpty {
      return resolved
    }

    if let fallback = Locale.current.language.languageCode?.identifier, !fallback.isEmpty {
      return fallback
    }

    return "en"
  }

  private static var isChineseLocale: Bool {
    resolvedLanguageCode.hasPrefix("zh")
  }

  private static func yearPart(_ years: Int) -> String {
    if isChineseLocale {
      return "\(years)年"
    }
    return years == 1 ? "1 year" : "\(years) years"
  }

  private static func monthPart(_ months: Int) -> String {
    if isChineseLocale {
      return "\(months)个月"
    }
    return months == 1 ? "1 month" : "\(months) months"
  }

  private static func dayPart(_ days: Int) -> String {
    if isChineseLocale {
      return "\(days)天"
    }
    return days == 1 ? "1 day" : "\(days) days"
  }

  private static func inPrefix(_ text: String) -> String {
    if isChineseLocale {
      return "还有\(text)"
    }
    return "in " + text
  }

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

      parts.append(yearPart(years))

      if months > 0 {
        parts.append(monthPart(months))
      }

      if days > 0 {
        parts.append(dayPart(days))
      }

      let separator = isChineseLocale ? "" : ", "
      return inPrefix(parts.joined(separator: separator))
    }

    // More than a month but less than a year: show month + day
    if months > 0 {
      var parts: [String] = []

      parts.append(monthPart(months))

      if days > 0 {
        parts.append(dayPart(days))
      }

      let separator = isChineseLocale ? "" : ", "
      return inPrefix(parts.joined(separator: separator))
    }

    // Less than a month: use calendar day difference for accuracy
    // This ensures D+1 shows "Tomorrow" and D+2 shows "in 2 days"
    // regardless of the current time of day
    if calendarDayDiff > 1 {
      return inPrefix(dayPart(calendarDayDiff))
    }

    // 1 calendar day away: show "Tomorrow"
    // This is because Joodle tracks entries by day, not by exact timestamp
    if calendarDayDiff == 1 {
      return isChineseLocale ? "明天" : "Tomorrow"
    }

    return ""
  }

  /// Format date as "MMM d, yyyy" (e.g., "Jan 15, 2025")
  static func dateText(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("yMMMd")
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
