//
//  CountdownHelperTests.swift
//  JoodleTests
//

import Foundation
import Testing
@testable import Joodle

struct CountdownHelperTests {

  private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = 0

    return calendar.date(from: components)!
  }

  @Test func countdownTomorrowAtDayBoundary() {
    let now = makeDate(2026, 3, 11, 23, 50)
    let target = makeDate(2026, 3, 12, 0, 10)

    let result = CountdownHelper.countdownText(from: now, to: target)

    #expect(result == String(localized: "Tomorrow"))
  }

  @Test func countdownTwoDaysMatchesRelativeFormatter() {
    let now = makeDate(2026, 3, 11, 9, 0)
    let target = makeDate(2026, 3, 13, 18, 0)

    var calendar = Calendar.autoupdatingCurrent
    calendar.locale = .autoupdatingCurrent
    let startOfToday = calendar.startOfDay(for: now)
    let startOfTarget = calendar.startOfDay(for: target)

    let formatter = RelativeDateTimeFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.calendar = calendar
    formatter.unitsStyle = .full

    let expected = formatter.localizedString(for: startOfTarget, relativeTo: startOfToday)
    let actual = CountdownHelper.countdownText(from: now, to: target)

    #expect(actual == expected)
  }

  @Test func countdownPastDateIsEmpty() {
    let now = makeDate(2026, 3, 11, 9, 0)
    let target = makeDate(2026, 3, 10, 9, 0)

    let result = CountdownHelper.countdownText(from: now, to: target)

    #expect(result.isEmpty)
  }

  @Test func localizedDateTextUsesExpectedTemplate() {
    let date = makeDate(2026, 3, 11, 10, 30)

    var calendar = Calendar.autoupdatingCurrent
    calendar.locale = .autoupdatingCurrent

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("yMMMd")

    let expected = formatter.string(from: date)
    let actual = CountdownHelper.dateText(for: date)

    #expect(actual == expected)
    #expect(!actual.isEmpty)
  }
}
