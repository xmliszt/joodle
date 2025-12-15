//
//  ThemeColorManager.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftData
import SwiftUI
import WidgetKit

/// Manages theme color changes and handles thumbnail regeneration
@MainActor
@Observable
final class ThemeColorManager {
    static let shared = ThemeColorManager()

    // MARK: - Published State
    var isRegenerating = false
    var regenerationProgress: Double = 0
    var totalEntriesToProcess: Int = 0
    var entriesProcessed: Int = 0

    private init() {}

    // MARK: - Theme Change Handler

    /// Changes the theme color and regenerates all thumbnails
    /// - Parameters:
    ///   - newColor: The new theme color to apply
    ///   - modelContext: The SwiftData model context
    ///   - completion: Optional completion handler called when done
    func changeThemeColor(
        to newColor: ThemeColor,
        modelContext: ModelContext,
        completion: (() -> Void)? = nil
    ) async {
        // Update the preference first
        UserPreferences.shared.accentColor = newColor

        // Reset progress state
        isRegenerating = true
        regenerationProgress = 0
        entriesProcessed = 0

        // Fetch all entries with drawings
        let descriptor = FetchDescriptor<DayEntry>()

        do {
            let allEntries = try modelContext.fetch(descriptor)

            // Filter to only entries with drawing data
            let entriesWithDrawings = allEntries.filter { entry in
                guard let drawingData = entry.drawingData else { return false }
                return !drawingData.isEmpty
            }

            totalEntriesToProcess = entriesWithDrawings.count

            // If no entries to process, we're done
            if entriesWithDrawings.isEmpty {
                isRegenerating = false
                regenerationProgress = 1.0
                completion?()
                return
            }

            // Regenerate thumbnails for each entry
            for (index, entry) in entriesWithDrawings.enumerated() {
                guard let drawingData = entry.drawingData else { continue }

                // Generate new thumbnails with the new accent color
                let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(
                    from: drawingData
                )

                entry.drawingThumbnail20 = thumbnails.0
                entry.drawingThumbnail200 = thumbnails.1

                entriesProcessed = index + 1
                regenerationProgress = Double(entriesProcessed) / Double(totalEntriesToProcess)

                // Save periodically to avoid memory buildup
                if entriesProcessed % 10 == 0 {
                    try? modelContext.save()
                }
            }

            // Final save
            try? modelContext.save()

            // Update widget data with new thumbnails
            updateWidgetData(entries: allEntries)

            // Update widget theme color
            WidgetHelper.shared.updateThemeColor()

            // Reload all widgets to reflect the new theme color
            WidgetCenter.shared.reloadAllTimelines()

        } catch {
            print("ThemeColorManager: Failed to regenerate thumbnails: \(error)")
        }

        // Complete
        isRegenerating = false
        regenerationProgress = 1.0
        completion?()
    }

    /// Update widget data after thumbnail regeneration
    private func updateWidgetData(entries: [DayEntry]) {
        WidgetHelper.shared.updateWidgetData(with: entries)
    }

    /// Get the count of entries that need thumbnail regeneration
    /// - Parameter modelContext: The SwiftData model context
    /// - Returns: Number of entries with drawings
    func countEntriesWithDrawings(modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<DayEntry>()

        do {
            let allEntries = try modelContext.fetch(descriptor)
            return allEntries.filter { entry in
                guard let drawingData = entry.drawingData else { return false }
                return !drawingData.isEmpty
            }.count
        } catch {
            print("ThemeColorManager: Failed to count entries: \(error)")
            return 0
        }
    }
}
