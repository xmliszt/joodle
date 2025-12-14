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

    private let seededKey = "debug_has_seeded_test_entries_v1"

    private init() {}

    /// Seeds test entries for 2023 and 2024
    /// Always reseeds to ensure data is not corrupted
    /// - Parameter container: The ModelContainer to use for seeding
    func seedTestEntriesIfNeeded(container: ModelContainer) {
        // Always reseed in debug mode to fix any corrupted entries
        Task { @MainActor in
            await seedTestEntries(container: container)
        }
    }

    /// Force seed test entries (ignores the "already seeded" flag)
    /// - Parameter container: The ModelContainer to use for seeding
    func forceSeedTestEntries(container: ModelContainer) {
        Task { @MainActor in
            await seedTestEntries(container: container)
        }
    }

    /// Clears the seeded flag so entries can be seeded again
    func resetSeededFlag() {
        UserDefaults.standard.removeObject(forKey: seededKey)
        print("🌱 DebugDataSeeder: Seeded flag reset")
    }

    /// Deletes all seeded test entries (entries with "[DEBUG]" in body)
    /// - Parameter container: The ModelContainer to use
    func deleteSeededEntries(container: ModelContainer) {
        Task { @MainActor in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<DayEntry>()

            do {
                let allEntries = try context.fetch(descriptor)
                var deletedCount = 0

                for entry in allEntries {
                    if entry.body.contains("[DEBUG]") {
                        context.delete(entry)
                        deletedCount += 1
                    }
                }

                if deletedCount > 0 {
                    try context.save()
                    print("🌱 DebugDataSeeder: Deleted \(deletedCount) debug entries")
                }

                // Reset the flag so we can seed again
                resetSeededFlag()
            } catch {
                print("🌱 DebugDataSeeder: Failed to delete entries - \(error)")
            }
        }
    }

    // MARK: - Private Methods

    private func seedTestEntries(container: ModelContainer) async {
        let context = ModelContext(container)

        print("🌱 DebugDataSeeder: Starting to seed test entries for 2023 and 2024...")

        var seededCount = 0

        // Seed entries for 2023
        let entries2023 = generateTestDates(for: 2023)
        for date in entries2023 {
            if await createEntryIfNeeded(for: date, in: context) {
                seededCount += 1
            }
        }

        // Seed entries for 2024
        let entries2024 = generateTestDates(for: 2024)
        for date in entries2024 {
            if await createEntryIfNeeded(for: date, in: context) {
                seededCount += 1
            }
        }

        // Save all changes
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: seededKey)
            print("🌱 DebugDataSeeder: Successfully seeded \(seededCount) test entries")
        } catch {
            print("🌱 DebugDataSeeder: Failed to save seeded entries - \(error)")
        }
    }

    /// Generates a variety of test dates for a given year
    /// - Parameter year: The year to generate dates for
    /// - Returns: Array of dates spread throughout the year
    private func generateTestDates(for year: Int) -> [Date] {
        var dates: [Date] = []

        // Add some entries for each month (2-3 per month for variety)
        for month in 1...12 {
            // First week
            if let date = createDate(year: year, month: month, day: 5) {
                dates.append(date)
            }

            // Mid month
            if let date = createDate(year: year, month: month, day: 15) {
                dates.append(date)
            }

            // End of month (use day 25 to be safe for all months)
            if let date = createDate(year: year, month: month, day: 25) {
                dates.append(date)
            }
        }

        // Add some special dates
        // New Year's Day
        if let date = createDate(year: year, month: 1, day: 1) {
            dates.append(date)
        }

        // Valentine's Day
        if let date = createDate(year: year, month: 2, day: 14) {
            dates.append(date)
        }

        // Halloween
        if let date = createDate(year: year, month: 10, day: 31) {
            dates.append(date)
        }

        // Christmas
        if let date = createDate(year: year, month: 12, day: 25) {
            dates.append(date)
        }

        // New Year's Eve
        if let date = createDate(year: year, month: 12, day: 31) {
            dates.append(date)
        }

        return dates
    }

    /// Creates a date from year, month, day components
    private func createDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)
    }

    /// Creates or overwrites an entry for the date
    /// - Returns: true if entry was created/updated
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

        // Use createMockDrawingData() from MockDataHelper.swift for sample drawing
        let drawingData = createMockDrawingData()
        entry.drawingData = drawingData

        // Generate thumbnails for the drawing
        let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(from: drawingData)
        entry.drawingThumbnail20 = thumbnails.0
        entry.drawingThumbnail200 = thumbnails.1

        context.insert(entry)
        return true
    }

    /// Generates debug body text for an entry
    private func generateDebugBody(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none

        let moods = ["😊", "😢", "😤", "🥳", "😴", "🤔", "😎", "🥰"]
        let randomMood = moods.randomElement() ?? "😊"

        return "[DEBUG] Test entry for \(formatter.string(from: date)) \(randomMood)"
    }
}

// MARK: - Debug Menu Extension

extension DebugDataSeeder {
    /// Returns debug actions for use in a debug menu
    var debugActions: [(title: String, action: (ModelContainer) -> Void)] {
        return [
            ("Seed Test Entries (2023 & 2024)", { [weak self] container in
                self?.forceSeedTestEntries(container: container)
            }),
            ("Delete Debug Entries", { [weak self] container in
                self?.deleteSeededEntries(container: container)
            }),
            ("Reset Seeded Flag", { [weak self] _ in
                self?.resetSeededFlag()
            })
        ]
    }
}
#endif
