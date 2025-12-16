//
//  DebugDataSeeder.swift
//  Joodle
//
//  Created for debugging and testing purposes
//

import Foundation
import SwiftData
import SwiftUI

#if DEBUG
/// Debug utility to seed test data for development and testing
/// Only available in DEBUG builds
@MainActor
final class DebugDataSeeder {
    static let shared = DebugDataSeeder()

    private init() {}

    /// No-op for app launch as we now seed on demand from Settings
    /// Kept for compatibility with existing calls in JoodleApp.swift
    func seedTestEntriesIfNeeded(container: ModelContainer) {
        // Intentionally left empty - seeding is now manual via Settings
    }

    /// Seeds entries for a specific year
    /// - Parameters:
    ///   - year: The year to seed (must be 2024 or earlier)
    ///   - count: Number of entries to seed
    ///   - container: The ModelContainer to use
    func seedEntries(for year: Int, count: Int, container: ModelContainer) async {
        guard year <= 2024 else {
            print("🌱 DebugDataSeeder: Can only seed for 2024 and before")
            return
        }

        let context = ModelContext(container)
        print("🌱 DebugDataSeeder: Seeding \(count) entries for \(year)...")

        let dates = generateRandomDates(for: year, count: count)
        var seededCount = 0

        for date in dates {
            if await createEntryIfNeeded(for: date, in: context) {
                seededCount += 1
            }
        }

        do {
            try context.save()
            print("🌱 DebugDataSeeder: Successfully seeded \(seededCount) entries for \(year)")
        } catch {
            print("🌱 DebugDataSeeder: Failed to save seeded entries - \(error)")
        }
    }

    /// Clears all entries from 2024 and before
    func clearAllDebugData(container: ModelContainer) async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DayEntry>()

        do {
            let allEntries = try context.fetch(descriptor)
            var deletedCount = 0
            let calendar = Calendar.current

            for entry in allEntries {
                let year = calendar.component(.year, from: entry.createdAt)
                if year <= 2024 {
                    context.delete(entry)
                    deletedCount += 1
                }
            }

            if deletedCount > 0 {
                try context.save()
                print("🌱 DebugDataSeeder: Cleared \(deletedCount) entries from 2024 and before")
            } else {
                print("🌱 DebugDataSeeder: No entries found to clear")
            }
        } catch {
            print("🌱 DebugDataSeeder: Failed to clear data - \(error)")
        }
    }

    /// Returns the count of entries from 2024 and before
    func getDebugEntryCount(container: ModelContainer) -> Int {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DayEntry>()

        do {
            let allEntries = try context.fetch(descriptor)
            let calendar = Calendar.current
            let count = allEntries.filter { entry in
                let year = calendar.component(.year, from: entry.createdAt)
                return year <= 2024
            }.count
            return count
        } catch {
            print("🌱 DebugDataSeeder: Failed to count entries - \(error)")
            return 0
        }
    }

    /// Returns the number of days in a given year
    func daysInYear(_ year: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .year, for: date) else {
            return 365
        }
        return range.count
    }

    // MARK: - Private Methods

    private func generateRandomDates(for year: Int, count: Int) -> [Date] {
        let calendar = Calendar.current

        // Create start date (Jan 1st)
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = 1
        startComponents.day = 1
        startComponents.hour = 12

        guard let startDate = calendar.date(from: startComponents) else { return [] }

        // Generate all possible dates for the year
        var allDates: [Date] = []
        var currentDate = startDate

        // Loop until we reach next year
        while calendar.component(.year, from: currentDate) == year {
            allDates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        // Shuffle and take required count
        // If count >= allDates.count, we return all dates (filling the year)
        let shuffledDates = allDates.shuffled()
        let limit = min(count, shuffledDates.count)

        return Array(shuffledDates.prefix(limit))
    }

    private func createEntryIfNeeded(for date: Date, in context: ModelContext) async -> Bool {
        let dateString = DayEntry.dateToString(date)

        // Delete any existing entry for this date first
        let predicate = #Predicate<DayEntry> { entry in
            entry.dateString == dateString
        }
        let descriptor = FetchDescriptor<DayEntry>(predicate: predicate)

        do {
            let existingEntries = try context.fetch(descriptor)
            for entry in existingEntries {
                context.delete(entry)
            }
        } catch {
            print("🌱 DebugDataSeeder: Failed to check existing entry for \(dateString) - \(error)")
        }

        // Create new entry with debug content
        let entry = DayEntry(body: generateDebugBody(for: date), createdAt: date)

        // Use PLACEHOLDER_DATA from PlaceholderDoodle.swift
        entry.drawingData = PLACEHOLDER_DATA

        // Generate thumbnails for the drawing
        let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(from: PLACEHOLDER_DATA)
        entry.drawingThumbnail20 = thumbnails.0
        entry.drawingThumbnail200 = thumbnails.1

        context.insert(entry)
        return true
    }

    private func generateDebugBody(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none

        let moods = ["😊", "😢", "😤", "🥳", "😴", "🤔", "😎", "🥰"]
        let randomMood = moods.randomElement() ?? "😊"

        return "[DEBUG] Seeded entry for \(formatter.string(from: date)) \(randomMood)"
    }
}
#endif
