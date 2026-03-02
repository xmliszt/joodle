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

    // MARK: - Drawing Data Size Presets

    /// Approximate number of path points to generate per preset
    enum DrawingSize: String, CaseIterable, Identifiable {
        case placeholder = "Placeholder (~1 KB)"
        case small = "Small (~5 KB)"
        case medium = "Medium (~20 KB)"
        case large = "Large (~80 KB)"
        case huge = "Huge (~200 KB)"

        var id: String { rawValue }

        /// Returns the approximate number of strokes to generate
        var strokeCount: Int {
            switch self {
            case .placeholder: return 0  // uses PLACEHOLDER_DATA
            case .small: return 8
            case .medium: return 30
            case .large: return 120
            case .huge: return 300
            }
        }

        /// Points per stroke (simulates natural drawing)
        var pointsPerStroke: Int {
            switch self {
            case .placeholder: return 0
            case .small: return 15
            case .medium: return 20
            case .large: return 20
            case .huge: return 20
            }
        }
    }

    // MARK: - Seed Entries

    /// Seeds entries for a specific year
    /// - Parameters:
    ///   - year: The year to seed
    ///   - count: Number of entries to seed
    ///   - drawingSize: The drawing data size preset to use
    ///   - container: The ModelContainer to use
    func seedEntries(for year: Int, count: Int, drawingSize: DrawingSize, container: ModelContainer) async {
        let context = ModelContext(container)
        print("🌱 DebugDataSeeder: Seeding \(count) entries for \(year) with \(drawingSize.rawValue) drawings...")

        let dates = generateRandomDates(for: year, count: count)
        var seededCount = 0

        for date in dates {
            if await createEntryIfNeeded(for: date, drawingSize: drawingSize, in: context) {
                seededCount += 1
            }

            // Save periodically to avoid memory buildup
            if seededCount % 50 == 0 {
                try? context.save()
            }
        }

        do {
            try context.save()
            print("🌱 DebugDataSeeder: Successfully seeded \(seededCount) entries for \(year)")
        } catch {
            print("🌱 DebugDataSeeder: Failed to save seeded entries - \(error)")
        }
    }

    /// Backward-compatible overload (uses placeholder drawing size)
    func seedEntries(for year: Int, count: Int, container: ModelContainer) async {
        await seedEntries(for: year, count: count, drawingSize: .placeholder, container: container)
    }

    // MARK: - Clear Data

    /// Clears seeded entries for a specific year
    func clearSeededData(for year: Int, container: ModelContainer) async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DayEntry>()

        do {
            let allEntries = try context.fetch(descriptor)
            var deletedCount = 0

            for entry in allEntries {
                // Use dateString to determine entry year (timezone-agnostic)
                let entryYear = Int(entry.dateString.prefix(4)) ?? 0
                if entryYear == year, entry.body.hasPrefix("[DEBUG]") || entry.body.hasPrefix("[STRESS]") {
                    context.delete(entry)
                    deletedCount += 1
                }
            }

            if deletedCount > 0 {
                try context.save()
                print("🌱 DebugDataSeeder: Cleared \(deletedCount) seeded entries for \(year)")
            } else {
                print("🌱 DebugDataSeeder: No seeded entries found for \(year)")
            }
        } catch {
            print("🌱 DebugDataSeeder: Failed to clear data - \(error)")
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

    // MARK: - Counts & Stats

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

    /// Returns (total entries, entries with drawings, seeded entries) for a given year
    func getEntryStats(for year: Int, container: ModelContainer) -> (total: Int, withDrawings: Int, seeded: Int) {
        let context = ModelContext(container)
        let yearPrefix = String(year)
        let descriptor = FetchDescriptor<DayEntry>()

        do {
            let allEntries = try context.fetch(descriptor)
            let yearEntries = allEntries.filter { $0.dateString.hasPrefix(yearPrefix) }
            let withDrawings = yearEntries.filter { $0.drawingData != nil && !($0.drawingData?.isEmpty ?? true) }
            let seeded = yearEntries.filter { $0.body.hasPrefix("[DEBUG]") || $0.body.hasPrefix("[STRESS]") }
            return (yearEntries.count, withDrawings.count, seeded.count)
        } catch {
            return (0, 0, 0)
        }
    }

    /// Estimates the widget payload size for all entries.
    /// After the file-based drawing storage change, UserDefaults only contains
    /// metadata + thumbnails. Drawing data is stored as individual files in the
    /// App Group container and is NOT counted toward the UserDefaults limit.
    func estimateWidgetPayloadSize(container: ModelContainer) -> (userDefaultsBytes: Int, drawingFileBytes: Int, thumbnailBytes: Int, entryCount: Int) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DayEntry>()

        do {
            let entries = try context.fetch(descriptor)
            var totalDrawing = 0
            var totalThumbnails = 0

            for entry in entries {
                totalDrawing += entry.drawingData?.count ?? 0
                totalThumbnails += entry.drawingThumbnail20?.count ?? 0
            }

            // UserDefaults payload: thumbnails + JSON overhead (no drawing data)
            let overhead = entries.count * 100
            let userDefaultsBytes = totalThumbnails + overhead

            return (userDefaultsBytes, totalDrawing, totalThumbnails, entries.count)
        } catch {
            return (0, 0, 0, 0)
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

    private func createEntryIfNeeded(for date: Date, drawingSize: DrawingSize, in context: ModelContext) async -> Bool {
        // Use CalendarDate for timezone-agnostic date string
        let dateString = CalendarDate.from(date).dateString

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
        let entry = DayEntry(body: generateDebugBody(for: date, drawingSize: drawingSize), createdAt: date)

        // Choose drawing data based on size preset
        let drawingData: Data
        if drawingSize == .placeholder {
            drawingData = PLACEHOLDER_DATA
        } else {
            drawingData = generateLargeDrawingData(strokeCount: drawingSize.strokeCount, pointsPerStroke: drawingSize.pointsPerStroke)
        }

        entry.drawingData = drawingData

        // Generate thumbnails for the drawing
        let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(from: drawingData)
        entry.drawingThumbnail20 = thumbnails.0
        entry.drawingThumbnail200 = thumbnails.1

        context.insert(entry)
        return true
    }

    /// Generates realistic-looking drawing data of configurable size.
    /// Produces random curved strokes with many points to simulate complex doodles.
    private func generateLargeDrawingData(strokeCount: Int, pointsPerStroke: Int) -> Data {
        struct PathData: Codable {
            let points: [CGPoint]
            let isDot: Bool
        }

        let canvasMax = DOODLE_CANVAS_SIZE
        var paths: [PathData] = []

        for _ in 0..<strokeCount {
            // Random starting point
            var x = CGFloat.random(in: 10...(canvasMax - 10))
            var y = CGFloat.random(in: 10...(canvasMax - 10))
            var points: [CGPoint] = []

            // Generate a random walk (simulates natural drawing strokes)
            for _ in 0..<pointsPerStroke {
                points.append(CGPoint(x: x, y: y))
                // Random direction change with momentum
                x += CGFloat.random(in: -15...15)
                y += CGFloat.random(in: -15...15)
                // Keep within canvas bounds
                x = max(2, min(canvasMax - 2, x))
                y = max(2, min(canvasMax - 2, y))
            }

            // ~10% chance of being a dot instead
            let isDot = Int.random(in: 0..<10) == 0
            if isDot {
                paths.append(PathData(points: [CGPoint(x: x, y: y)], isDot: true))
            } else {
                paths.append(PathData(points: points, isDot: false))
            }
        }

        return (try? JSONEncoder().encode(paths)) ?? Data()
    }

    private func generateDebugBody(for date: Date, drawingSize: DrawingSize) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none

        let moods = ["😊", "😢", "😤", "🥳", "😴", "🤔", "😎", "🥰"]
        let randomMood = moods.randomElement() ?? "😊"

        let prefix = drawingSize == .placeholder ? "[DEBUG]" : "[STRESS]"
        return "\(prefix) Seeded entry for \(formatter.string(from: date)) \(randomMood)"
    }
}
#endif
