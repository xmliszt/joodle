//
//  MockDataStore.swift
//  Joodle
//
//  Sandboxed data store for tutorial environment.
//  All data lives only during the tutorial lifecycle - nothing is persisted.
//

import SwiftUI
import Combine

// MARK: - Mock Day Entry

/// A mock entry that mimics DayEntry but is not persisted to SwiftData
struct MockDayEntry: Identifiable, Equatable {
    let id: UUID = UUID()
    let dateString: String
    var body: String
    var drawingData: Data?

    var date: Date {
        DayEntry.stringToLocalDate(dateString) ?? Date()
    }

    init(dateString: String, body: String = "", drawingData: Data? = nil) {
        self.dateString = dateString
        self.body = body
        self.drawingData = drawingData
    }

    init(date: Date, body: String = "", drawingData: Data? = nil) {
        self.dateString = DayEntry.dateToString(date)
        self.body = body
        self.drawingData = drawingData
    }

    /// Check if this entry has any content
    var hasContent: Bool {
        !body.isEmpty || (drawingData != nil && !drawingData!.isEmpty)
    }

    /// Check if this entry has a drawing
    var hasDrawing: Bool {
        drawingData != nil && !drawingData!.isEmpty
    }
}

// MARK: - Mock Reminder

struct MockReminder: Identifiable, Equatable {
    let id: UUID = UUID()
    let dateString: String
    let reminderTime: Date
}

// MARK: - Mock Data Store

@MainActor
class MockDataStore: ObservableObject {

    // MARK: - Published State

    /// All mock entries
    @Published var entries: [MockDayEntry] = []

    /// Currently selected year
    @Published var selectedYear: Int

    /// Current view mode
    @Published var viewMode: ViewMode = .now

    /// Currently selected date item (for entry editing)
    @Published var selectedDateItem: DateItem?

    /// Mock reminders (dateString -> reminder)
    @Published var reminders: [String: MockReminder] = [:]

    /// Whether the drawing canvas is showing
    @Published var showDrawingCanvas: Bool = false

    /// Whether the reminder sheet is showing
    @Published var showReminderSheet: Bool = false

    // MARK: - Init

    init(initialYear: Int = Calendar.current.component(.year, from: Date())) {
        self.selectedYear = initialYear
    }

    // MARK: - Entry Management

    /// Add or update an entry
    func addEntry(_ entry: MockDayEntry) {
        // Remove existing entry for same date
        entries.removeAll { $0.dateString == entry.dateString }
        entries.append(entry)
    }

    /// Update an existing entry
    func updateEntry(_ entry: MockDayEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    /// Remove an entry
    func removeEntry(for dateString: String) {
        entries.removeAll { $0.dateString == dateString }
    }

    /// Get entry for a specific date
    func getEntry(for date: Date) -> MockDayEntry? {
        let dateString = DayEntry.dateToString(date)
        return entries.first { $0.dateString == dateString }
    }

    /// Get entry for a specific date string
    func getEntry(for dateString: String) -> MockDayEntry? {
        return entries.first { $0.dateString == dateString }
    }

    /// Check if an entry exists for a date
    func hasEntry(for date: Date) -> Bool {
        getEntry(for: date)?.hasContent ?? false
    }

    // MARK: - Reminder Management

    /// Set a reminder for a date
    func setReminder(for dateString: String, at time: Date) {
        let reminder = MockReminder(dateString: dateString, reminderTime: time)
        reminders[dateString] = reminder
    }

    /// Remove a reminder
    func removeReminder(for dateString: String) {
        reminders.removeValue(forKey: dateString)
    }

    /// Check if a reminder exists for a date
    func hasReminder(for dateString: String) -> Bool {
        reminders[dateString] != nil
    }

    /// Get reminder for a date
    func getReminder(for dateString: String) -> MockReminder? {
        reminders[dateString]
    }

    // MARK: - Selection Management

    /// Select a date
    func selectDate(_ date: Date) {
        selectedDateItem = DateItem(
            id: "\(Int(date.timeIntervalSince1970))",
            date: date
        )
    }

    /// Clear selection
    func clearSelection() {
        selectedDateItem = nil
    }

    // MARK: - Setup Helpers

    /// Populate with the user's first doodle (from onboarding)
    func populateUserDrawing(_ drawingData: Data, for date: Date = Date()) {
        let entry = MockDayEntry(
            date: date,
            body: "",
            drawingData: drawingData
        )
        addEntry(entry)
    }

    /// Populate an anniversary entry for tutorial step 5
    /// Uses the first day of (current year + 1) to ensure it's always in the future
    func populateAnniversaryEntry() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let futureYear = currentYear + 1

        // Use Jan 1 of next year (always in the future)
        guard let anniversaryDate = calendar.date(
            from: DateComponents(year: futureYear, month: 1, day: 1)
        ) else { return }

        // Also update selectedYear to match
        selectedYear = futureYear

        let entry = MockDayEntry(
            date: anniversaryDate,
            body: "🎉 New Year!",
            drawingData: PLACEHOLDER_DATA
        )
        addEntry(entry)

        // Auto-select this entry
        selectDate(anniversaryDate)
    }

    /// Ensure we're in a future year (for reminder tutorial)
    func ensureFutureYear() {
        let currentYear = Calendar.current.component(.year, from: Date())
        if selectedYear <= currentYear {
            selectedYear = currentYear + 1
        }
    }

    /// Reset all state
    func reset() {
        entries.removeAll()
        reminders.removeAll()
        selectedDateItem = nil
        viewMode = .now
        showDrawingCanvas = false
        showReminderSheet = false
        selectedYear = Calendar.current.component(.year, from: Date())
    }

    // MARK: - Computed Properties

    /// Items for the current selected year
    var itemsInYear: [DateItem] {
        let calendar = Calendar.current
        guard let startOfYear = calendar.date(
            from: DateComponents(year: selectedYear, month: 1, day: 1)
        ) else { return [] }

        let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count ?? 365

        return (0..<daysInYear).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear) else {
                return nil
            }
            return DateItem(
                id: "\(Int(date.timeIntervalSince1970))",
                date: date
            )
        }
    }

    /// Currently selected entry (if any)
    var selectedEntry: MockDayEntry? {
        guard let date = selectedDateItem?.date else { return nil }
        return getEntry(for: date)
    }
}

// MARK: - Preview Helper

#if DEBUG
extension MockDataStore {
    /// Create a mock store with sample data for previews
    static func previewStore(
        withUserDoodle: Bool = true,
        selectedYear: Int = Calendar.current.component(.year, from: Date()),
        viewMode: ViewMode = .now,
        hasSelectedEntry: Bool = false,
        hasAnniversaryEntry: Bool = false
    ) -> MockDataStore {
        let store = MockDataStore(initialYear: selectedYear)
        store.viewMode = viewMode

        if withUserDoodle {
            store.populateUserDrawing(PLACEHOLDER_DATA)
        }

        if hasAnniversaryEntry {
            store.populateAnniversaryEntry()
        }

        if hasSelectedEntry {
            store.selectDate(Date())
        }

        return store
    }
}
#endif

// MARK: - Previews

#Preview("Mock Data Store Demo") {
    struct PreviewContainer: View {
        @StateObject private var store = MockDataStore.previewStore(
            withUserDoodle: true,
            hasSelectedEntry: true
        )

        var body: some View {
            VStack(spacing: 16) {
                Text("Mock Data Store")
                    .font(.headline)

                Group {
                    Text("Year: \(store.selectedYear)")
                    Text("View Mode: \(store.viewMode == .now ? "Normal" : "Year")")
                    Text("Entries: \(store.entries.count)")
                    Text("Selected: \(store.selectedDateItem?.date.formatted() ?? "None")")
                }
                .font(.caption)

                Divider()

                // Entry list
                ForEach(store.entries) { entry in
                    HStack {
                        Text(entry.dateString)
                        Spacer()
                        if entry.hasDrawing {
                            Image(systemName: "scribble")
                        }
                        if !entry.body.isEmpty {
                            Image(systemName: "text.alignleft")
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal)
                }

                Spacer()

                // Actions
                HStack(spacing: 12) {
                    Button("Add Entry") {
                        let entry = MockDayEntry(
                            date: Date().addingTimeInterval(86400 * Double.random(in: 1...30)),
                            body: "Test entry"
                        )
                        store.addEntry(entry)
                    }

                    Button("Toggle Mode") {
                        store.viewMode = store.viewMode == .now ? .year : .now
                    }

                    Button("Reset") {
                        store.reset()
                    }
                }
                .font(.caption)
            }
            .padding()
        }
    }

    return PreviewContainer()
}
