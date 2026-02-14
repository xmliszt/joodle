//
//  WeekPickerSheet.swift
//  Joodle
//
//  Created by Li Yuxuan on 14/2/26.
//

import SwiftUI

struct WeekPickerSheet: View {
  let year: Int
  let startOfWeek: String
  @Binding var selectedWeekStart: Date
  var onSelect: () -> Void

  @Environment(\.dismiss) private var dismiss

  /// All week start dates within the given year
  private var weekStartDates: [Date] {
    let calendar = Calendar.current
    guard let firstOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
          let lastOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
    else { return [] }

    // Find the first week start on or before Jan 1
    var current = computeWeekStart(for: firstOfYear)
    var dates: [Date] = []

    while current <= lastOfYear {
      let weekEnd = calendar.date(byAdding: .day, value: 6, to: current) ?? current
      // Include this week if any day overlaps with the year
      let weekEndYear = calendar.component(.year, from: weekEnd)
      let weekStartYear = calendar.component(.year, from: current)
      if weekEndYear >= year && weekStartYear <= year {
        dates.append(current)
      }
      guard let next = calendar.date(byAdding: .day, value: 7, to: current) else { break }
      current = next
    }

    return dates
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        Picker("Week", selection: $selectedWeekStart) {
          ForEach(weekStartDates, id: \.self) { weekStart in
            Text(weekRangeLabel(for: weekStart))
              .tag(weekStart)
          }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
      }
      .navigationTitle("Jump to Week")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            onSelect()
            dismiss()
          }
          .font(.appFont(size: 16, weight: .semibold))
        }
      }
    }
  }

  /// Format a week range label, e.g. "Feb 9 - Feb 15"
  private func weekRangeLabel(for weekStart: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    let calendar = Calendar.current
    let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
  }

  /// Compute the start of the week containing the given date
  private func computeWeekStart(for date: Date) -> Date {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: date)
    let weekday = calendar.component(.weekday, from: day)
    let offset: Int
    if startOfWeek.lowercased() == "monday" {
      offset = (weekday - 2 + 7) % 7
    } else {
      offset = weekday - 1
    }
    return calendar.date(byAdding: .day, value: -offset, to: day)!
  }
}
