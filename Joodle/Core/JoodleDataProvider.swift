//
//  JoodleDataProvider.swift
//  Joodle
//
//  Protocol for abstracting data source between real app and tutorial sandbox.
//

import SwiftUI
import Combine

// MARK: - Joodle Data Provider Protocol

/// Protocol that abstracts the data source for the Joodle grid view.
/// Both real app data and mock tutorial data conform to this protocol,
/// allowing the same grid interaction component to be reused.
@MainActor
protocol JoodleDataProvider: AnyObject, ObservableObject {
  // MARK: - Required Properties

  /// The currently selected year
  var selectedYear: Int { get set }

  /// The current view mode (.now or .year)
  var viewMode: ViewMode { get set }

  /// The currently selected date item (for entry editing)
  var selectedDateItem: DateItem? { get set }

  /// Items for the current selected year
  var itemsInYear: [DateItem] { get }

  /// All entries as DayEntry (for YearGridView compatibility)
  var entriesAsDayEntries: [DayEntry] { get }

  // MARK: - Required Methods

  /// Select a date
  func selectDate(_ date: Date)

  /// Clear the current selection
  func clearSelection()

  /// Get item from item ID
  func getItem(from itemId: String) -> DateItem?
}

// MARK: - Default Implementations

extension JoodleDataProvider {
  /// Get item from item ID (default implementation)
  func getItem(from itemId: String) -> DateItem? {
    itemsInYear.first { $0.id == itemId }
  }
}

// MARK: - Mock Data Store Conformance

extension MockDataStore: JoodleDataProvider {
  var entriesAsDayEntries: [DayEntry] {
    entries.map { mockEntry in
      DayEntry(
        body: mockEntry.body,
        createdAt: mockEntry.date,
        drawingData: mockEntry.drawingData
      )
    }
  }
}

// MARK: - App Data Provider (for ContentView)

/// Wrapper class that adapts ContentView's data to JoodleDataProvider protocol.
/// This allows ContentView to use the same JoodleGridInteractionView as the tutorial.
///
/// Usage in ContentView:
/// ```swift
/// @StateObject private var dataProvider = AppDataProvider()
/// @Query private var entries: [DayEntry]
///
/// // Sync entries
/// .onChange(of: entries) { dataProvider.updateEntries(entries) }
///
/// // Use in JoodleGridInteractionView
/// JoodleGridInteractionView(
///     dataProvider: dataProvider,
///     additionalEntries: entries,  // Pass entries directly for immediate access
///     ...
/// )
/// ```
@MainActor
class AppDataProvider: ObservableObject, JoodleDataProvider {
  // MARK: - Published State

  @Published var selectedYear: Int {
    didSet {
      if oldValue != selectedYear {
        invalidateCache()
        onYearChanged?(selectedYear)
      }
    }
  }

  @Published var viewMode: ViewMode {
    didSet {
      if oldValue != viewMode {
        onViewModeChanged?(viewMode)
      }
    }
  }

  @Published var selectedDateItem: DateItem? {
    didSet {
      onSelectionChanged?(selectedDateItem)
    }
  }

  // MARK: - Callbacks for Two-Way Binding

  /// Called when year changes (for scroll reset, hit testing grid rebuild)
  var onYearChanged: ((Int) -> Void)?

  /// Called when view mode changes (for animations, hit testing grid rebuild)
  var onViewModeChanged: ((ViewMode) -> Void)?

  /// Called when selection changes (for scroll to item, UI updates)
  var onSelectionChanged: ((DateItem?) -> Void)?

  // MARK: - External Data References

  /// Reference to entries (from @Query in ContentView)
  private var _entries: [DayEntry] = []

  /// Cached items for the year
  private var _cachedItemsInYear: [DateItem] = []
  private var _cachedYear: Int = 0

  // MARK: - Init

  init(
    selectedYear: Int = Calendar.current.component(.year, from: Date()),
    viewMode: ViewMode = .now
  ) {
    self.selectedYear = selectedYear
    self.viewMode = viewMode
  }

  // MARK: - JoodleDataProvider

  var itemsInYear: [DateItem] {
    // Return cached items if year hasn't changed
    if _cachedYear == selectedYear && !_cachedItemsInYear.isEmpty {
      return _cachedItemsInYear
    }

    // Recalculate items for the year
    let calendar = Calendar.current
    guard let startOfYear = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) else {
      return []
    }

    let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count ?? 365

    _cachedItemsInYear = (0..<daysInYear).map { dayOffset in
      let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear)!
      return DateItem(
        id: "\(Int(date.timeIntervalSince1970))",
        date: date
      )
    }
    _cachedYear = selectedYear

    return _cachedItemsInYear
  }

  var entriesAsDayEntries: [DayEntry] {
    _entries
  }

  func selectDate(_ date: Date) {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    selectedDateItem = DateItem(
      id: "\(Int(startOfDay.timeIntervalSince1970))",
      date: startOfDay
    )
  }

  func clearSelection() {
    selectedDateItem = nil
  }

  // MARK: - Update Methods (called by ContentView)

  /// Update entries from @Query results
  func updateEntries(_ entries: [DayEntry]) {
    _entries = entries
  }

  /// Invalidate cached items (call when year changes)
  func invalidateCache() {
    _cachedItemsInYear = []
    _cachedYear = 0
  }

  // MARK: - Convenience Methods

  /// Number of days in the selected year
  var daysInYear: Int {
    let calendar = Calendar.current
    guard let startOfYear = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)),
          let startOfNextYear = calendar.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1))
    else { return 365 }
    return calendar.dateComponents([.day], from: startOfYear, to: startOfNextYear).day ?? 365
  }

  /// Get the item ID for a specific date
  func getItemId(for date: Date) -> String {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    return "\(Int(startOfDay.timeIntervalSince1970))"
  }

  /// Get the item ID for the most relevant date (today if in selected year, otherwise first day)
  func getRelevantDateId(for date: Date = Date()) -> String {
    let calendar = Calendar.current
    let currentYear = calendar.component(.year, from: date)

    if selectedYear == currentYear {
      if let dateItem = itemsInYear.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
        return dateItem.id
      }
    }

    return itemsInYear.first?.id ?? ""
  }

  /// Select a date item and optionally trigger callback
  func selectDateItem(_ item: DateItem) {
    selectedDateItem = item
  }

  /// Toggle view mode with animation
  func toggleViewMode(to newViewMode: ViewMode) {
    viewMode = newViewMode
  }
}
