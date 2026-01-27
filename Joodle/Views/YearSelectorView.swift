//
//  YearSelectorView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import SwiftData

struct YearSelectorView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var earliestYear: Int = Calendar.current.component(.year, from: Date())

  let highlightedItem: DateItem?
  @Binding var selectedYear: Int

  private var availableYears: [Int] {
    let currentYear = Calendar.current.component(.year, from: Date())
    // Create range from earliest year to current year + 1
    let endYear = currentYear + 1
    // Ensure earliestYear is not in the future relative to currentYear (sanity check)
    let startYear = min(earliestYear, currentYear)
    return Array(startYear...endYear)
  }

  private var headerText: String {
    guard let highlightedItem else { return String(selectedYear) }
    let isHighlightedToday = Calendar.current.isDate(highlightedItem.date, inSameDayAs: Date())
    return isHighlightedToday ? "Today": getFormattedDate(highlightedItem.date)
  }

  private var headerColor: Color {
    guard let highlightedItem else { return .textColor }
    let isHighlightedToday = Calendar.current.isDate(highlightedItem.date, inSameDayAs: Date())
    return isHighlightedToday ? .appAccent: .textColor
  }

  var body: some View {
    Menu {
      ForEach(availableYears, id: \.self) { year in
        Button(String(year)) {
          let previousYear = selectedYear
          withAnimation(.easeInOut(duration: 0.3)) {
            selectedYear = year
          }
          // Track year change
          if year != previousYear {
            AnalyticsManager.shared.trackYearChanged(to: year, from: previousYear)
          }
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text(headerText)
          .font(.title.bold())
          .foregroundColor(headerColor)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
    .menuStyle(.borderlessButton)
    .onAppear {
      fetchEarliestYear()
    }
  }

  // MARK: - Helper Methods
  private func fetchEarliestYear() {
    var descriptor = FetchDescriptor<DayEntry>(
      sortBy: [SortDescriptor(\.createdAt, order: .forward)]
    )
    descriptor.fetchLimit = 1

    do {
      if let firstEntry = try modelContext.fetch(descriptor).first {
        earliestYear = Calendar.current.component(.year, from: firstEntry.createdAt)
      }
    } catch {
      print("Failed to fetch earliest year: \(error)")
    }
  }

  private func getFormattedDate(_ date: Date) -> String {
    let style = Date.FormatStyle().month(.abbreviated).day()
    return date.formatted(style)
  }
}

#Preview("With Sample Data") {
  @Previewable @State var selectedYear = 2024

  let container = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DayEntry.self, configurations: config)

    // Add sample entries spanning multiple years
    container.mainContext.insert(DayEntry(body: "Started my journal in 2022!", createdAt: Calendar.current.date(from: DateComponents(year: 2022, month: 3, day: 15))!))
    container.mainContext.insert(DayEntry(body: "Great day in 2023", createdAt: Calendar.current.date(from: DateComponents(year: 2023, month: 6, day: 20))!))
    container.mainContext.insert(DayEntry(body: "Another entry in 2023", createdAt: Calendar.current.date(from: DateComponents(year: 2023, month: 8, day: 10))!))
    container.mainContext.insert(DayEntry(body: "Current year entry", createdAt: Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 5))!))

    return container
  }()

  YearSelectorView(
    highlightedItem: nil,
    selectedYear: $selectedYear
  )
  .modelContainer(container)
  .padding()
}

#Preview("Empty State") {
  @Previewable @State var selectedYear = 2024

  YearSelectorView(
    highlightedItem: nil,
    selectedYear: $selectedYear
  )
  .modelContainer(for: DayEntry.self, inMemory: true)
  .padding()
}

