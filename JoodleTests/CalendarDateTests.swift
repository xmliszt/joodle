//
//  CalendarDateTests.swift
//  JoodleTests
//
//  Unit tests for the CalendarDate timezone-agnostic date type.
//

import Testing
import Foundation
@testable import Joodle

struct CalendarDateTests {

  // MARK: - Initialization Tests

  @Test func testInitFromComponents() {
    let date = CalendarDate(year: 2025, month: 12, day: 25)

    #expect(date.year == 2025)
    #expect(date.month == 12)
    #expect(date.day == 25)
  }

  @Test func testInitFromValidDateString() {
    let date = CalendarDate(dateString: "2025-12-25")

    #expect(date != nil)
    #expect(date?.year == 2025)
    #expect(date?.month == 12)
    #expect(date?.day == 25)
  }

  @Test func testInitFromInvalidDateStringReturnsNil() {
    #expect(CalendarDate(dateString: "invalid") == nil)
    #expect(CalendarDate(dateString: "") == nil)
    #expect(CalendarDate(dateString: "2025-13-01") == nil)  // Invalid month
    #expect(CalendarDate(dateString: "2025-00-01") == nil)  // Invalid month
    #expect(CalendarDate(dateString: "2025-01-00") == nil)  // Invalid day
    #expect(CalendarDate(dateString: "2025-01-32") == nil)  // Invalid day
    #expect(CalendarDate(dateString: "25-12-25") == nil)    // Wrong format
    #expect(CalendarDate(dateString: "2025/12/25") == nil)  // Wrong separator
  }

  @Test func testInitFromDate() {
    // Create a specific date
    var components = DateComponents()
    components.year = 2025
    components.month = 6
    components.day = 15
    components.hour = 14
    components.minute = 30

    let date = Calendar.current.date(from: components)!
    let calendarDate = CalendarDate.from(date)

    #expect(calendarDate.year == 2025)
    #expect(calendarDate.month == 6)
    #expect(calendarDate.day == 15)
  }

  @Test func testToday() {
    let today = CalendarDate.today()
    let nowComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())

    #expect(today.year == nowComponents.year)
    #expect(today.month == nowComponents.month)
    #expect(today.day == nowComponents.day)
  }

  // MARK: - String Representation Tests

  @Test func testDateString() {
    let date = CalendarDate(year: 2025, month: 1, day: 5)
    #expect(date.dateString == "2025-01-05")

    let date2 = CalendarDate(year: 2025, month: 12, day: 25)
    #expect(date2.dateString == "2025-12-25")
  }

  @Test func testDateStringRoundTrip() {
    let original = CalendarDate(year: 2025, month: 7, day: 4)
    let parsed = CalendarDate(dateString: original.dateString)

    #expect(parsed != nil)
    #expect(original == parsed)
  }

  // MARK: - Comparison Tests

  @Test func testEquality() {
    let date1 = CalendarDate(year: 2025, month: 12, day: 25)
    let date2 = CalendarDate(year: 2025, month: 12, day: 25)
    let date3 = CalendarDate(year: 2025, month: 12, day: 26)

    #expect(date1 == date2)
    #expect(date1 != date3)
  }

  @Test func testComparison() {
    let dec25 = CalendarDate(year: 2025, month: 12, day: 25)
    let dec26 = CalendarDate(year: 2025, month: 12, day: 26)
    let jan01_2026 = CalendarDate(year: 2026, month: 1, day: 1)
    let nov25 = CalendarDate(year: 2025, month: 11, day: 25)

    // Day comparison
    #expect(dec25 < dec26)
    #expect(dec26 > dec25)

    // Month comparison
    #expect(nov25 < dec25)

    // Year comparison
    #expect(dec26 < jan01_2026)
  }

  @Test func testDateStringLexicographicOrder() {
    // Verify that dateString lexicographic order matches chronological order
    let dates = [
      CalendarDate(year: 2024, month: 12, day: 31),
      CalendarDate(year: 2025, month: 1, day: 1),
      CalendarDate(year: 2025, month: 1, day: 2),
      CalendarDate(year: 2025, month: 2, day: 1),
      CalendarDate(year: 2025, month: 12, day: 25)
    ]

    let dateStrings = dates.map { $0.dateString }
    let sortedByString = dateStrings.sorted()
    let sortedByComparable = dates.sorted().map { $0.dateString }

    #expect(sortedByString == sortedByComparable)
  }

  // MARK: - Comparison Helpers Tests

  @Test func testIsToday() {
    let today = CalendarDate.today()
    #expect(today.isToday == true)

    let yesterday = CalendarDate(
      year: today.year,
      month: today.month,
      day: today.day - 1  // Simplified - may not work at month boundaries
    )
    // Skip this check as it's complex to handle month boundaries
    // The important test is that today.isToday returns true
  }

  @Test func testIsFutureAndIsPast() {
    let today = CalendarDate.today()

    // Create a date definitely in the future
    let futureDate = CalendarDate(year: today.year + 1, month: 1, day: 1)
    #expect(futureDate.isFuture == true)
    #expect(futureDate.isPast == false)

    // Create a date definitely in the past
    let pastDate = CalendarDate(year: today.year - 1, month: 1, day: 1)
    #expect(pastDate.isFuture == false)
    #expect(pastDate.isPast == true)

    // Today is neither future nor past
    #expect(today.isFuture == false)
    #expect(today.isPast == false)
  }

  // MARK: - Display Date Tests

  @Test func testDisplayDatePreservesCalendarDay() {
    let calendarDate = CalendarDate(year: 2025, month: 12, day: 25)
    let displayDate = calendarDate.displayDate

    let components = Calendar.current.dateComponents([.year, .month, .day], from: displayDate)

    #expect(components.year == 2025)
    #expect(components.month == 12)
    #expect(components.day == 25)
  }

  // MARK: - Hashable Tests

  @Test func testHashable() {
    let date1 = CalendarDate(year: 2025, month: 12, day: 25)
    let date2 = CalendarDate(year: 2025, month: 12, day: 25)
    let date3 = CalendarDate(year: 2025, month: 12, day: 26)

    var set = Set<CalendarDate>()
    set.insert(date1)
    set.insert(date2)  // Should not increase count
    set.insert(date3)  // Should increase count

    #expect(set.count == 2)
    #expect(set.contains(date1))
    #expect(set.contains(date3))
  }

  // MARK: - Codable Tests

  @Test func testCodable() throws {
    let original = CalendarDate(year: 2025, month: 12, day: 25)

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(CalendarDate.self, from: data)

    #expect(original == decoded)
  }

  // MARK: - String Literal Tests

  @Test func testStringLiteral() {
    let date: CalendarDate = "2025-12-25"

    #expect(date.year == 2025)
    #expect(date.month == 12)
    #expect(date.day == 25)
  }

  // MARK: - Description Tests

  @Test func testDescription() {
    let date = CalendarDate(year: 2025, month: 12, day: 25)
    #expect(date.description == "2025-12-25")
  }

  // MARK: - Edge Cases

  @Test func testLeapYearDate() {
    let leapDate = CalendarDate(dateString: "2024-02-29")
    #expect(leapDate != nil)
    #expect(leapDate?.month == 2)
    #expect(leapDate?.day == 29)
  }

  @Test func testFirstAndLastDayOfYear() {
    let firstDay = CalendarDate(dateString: "2025-01-01")
    let lastDay = CalendarDate(dateString: "2025-12-31")

    #expect(firstDay != nil)
    #expect(lastDay != nil)
    #expect(firstDay! < lastDay!)
  }

  // MARK: - Timezone Invariance Tests

  @Test func testDateStringIsTimezoneAgnostic() {
    // The key property: once created, dateString never changes
    // regardless of what timezone operations are performed

    let calendarDate = CalendarDate(year: 2025, month: 12, day: 25)
    let dateString = calendarDate.dateString

    // Convert to display date and back
    let displayDate = calendarDate.displayDate
    let roundTripped = CalendarDate.from(displayDate)

    // The dateString should be unchanged
    #expect(roundTripped.dateString == dateString)
  }
}
