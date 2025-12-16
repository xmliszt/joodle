//
//  YearContent.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

/// A view that encapsulates the data fetching and display logic for a specific year.
/// This isolates the @Query to just the relevant year's entries, improving performance
/// by avoiding fetching the entire database.
struct YearContent: View {
  // MARK: - Parameters
  let year: Int
  let viewMode: ViewMode
  let itemsSpacing: CGFloat
  let itemsInYear: [DateItem]

  // MARK: - Bindings
  @Binding var isScrubbing: Bool
  @Binding var highlightedId: String?
  @Binding var selectedDateItem: DateItem?

  // MARK: - Output Bindings
  /// The entry corresponding to the selected date
  @Binding var selectedEntry: DayEntry?
  /// The entry corresponding to the highlighted date (during scrubbing)
  @Binding var highlightedEntry: DayEntry?

  // MARK: - Environment & Data
  @Environment(\.modelContext) private var modelContext

  /// Efficient query filtered by year
  @Query private var entries: [DayEntry]

  init(
    year: Int,
    viewMode: ViewMode,
    itemsSpacing: CGFloat,
    itemsInYear: [DateItem],
    isScrubbing: Binding<Bool>,
    highlightedId: Binding<String?>,
    selectedDateItem: Binding<DateItem?>,
    selectedEntry: Binding<DayEntry?>,
    highlightedEntry: Binding<DayEntry?>
  ) {
    self.year = year
    self.viewMode = viewMode
    self.itemsSpacing = itemsSpacing
    self.itemsInYear = itemsInYear
    self._isScrubbing = isScrubbing
    self._highlightedId = highlightedId
    self._selectedDateItem = selectedDateItem
    self._selectedEntry = selectedEntry
    self._highlightedEntry = highlightedEntry

    // Construct query for specific year
    let yearString = String(format: "%04d", year)
    let start = "\(yearString)-01-01"
    let end = "\(yearString)-12-31"

    self._entries = Query(
      filter: #Predicate<DayEntry> {
        $0.dateString >= start && $0.dateString <= end
      },
      sort: \.dateString
    )
  }

  var body: some View {
    YearGridView(
      year: year,
      viewMode: viewMode,
      dotsSpacing: itemsSpacing,
      items: itemsInYear,
      entries: entries,
      highlightedItemId: isScrubbing ? highlightedId : nil,
      selectedItemId: selectedDateItem?.id
    )
    .onChange(of: selectedDateItem) { _, _ in updateSelectedEntry() }
    .onChange(of: entries) { _, _ in
      updateSelectedEntry()
      updateHighlightedEntry()

      // Sync widget data when entries change
      // We use the helper to fetch all needed entries efficiently
      WidgetHelper.shared.updateWidgetData(in: modelContext)
    }
    .onChange(of: highlightedId) { _, _ in updateHighlightedEntry() }
    .onAppear {
      updateSelectedEntry()
      updateHighlightedEntry()
    }
  }

  // MARK: - Helper Functions

  private func updateSelectedEntry() {
    guard let date = selectedDateItem?.date else {
      selectedEntry = nil
      return
    }

    // Find entry matching the selected date
    // Prioritize entries with content if duplicates exist (though model handles merging)
    let candidates = entries.filter { $0.matches(date: date) }
    selectedEntry = candidates.first(where: { ($0.drawingData?.isEmpty == false) || !$0.body.isEmpty }) ?? candidates.first
  }

  private func updateHighlightedEntry() {
    guard let id = highlightedId,
          let item = itemsInYear.first(where: { $0.id == id }) else {
      highlightedEntry = nil
      return
    }

    highlightedEntry = entries.first(where: { $0.matches(date: item.date) })
  }
}
