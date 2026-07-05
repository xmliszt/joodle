//
//  ThemeColorManager.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftData
import SwiftUI

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

    /// Changes the theme color. The switch is instant: stored doodle thumbnails
    /// are drawn as template masks recolored at display time (both in the grid
    /// and in widgets), so changing the accent needs no thumbnail regeneration.
    /// - Parameters:
    ///   - newColor: The new theme color to apply
    ///   - modelContext: The SwiftData model context (unused; kept for call-site
    ///     compatibility now that no regeneration pass runs)
    ///   - completion: Optional completion handler called when done
    func changeThemeColor(
        to newColor: ThemeColor,
        modelContext: ModelContext,
        completion: (() -> Void)? = nil
    ) async {
        // Persisting the preference posts `.didChangeAccentColor`, which re-tints
        // the whole view tree immediately.
        UserPreferences.shared.accentColor = newColor

        // Nothing to regenerate — keep the flag false so no loading overlay shows.
        isRegenerating = false
        regenerationProgress = 1.0
        entriesProcessed = 0
        totalEntriesToProcess = 0

        // Point widgets at the new theme and reload their timelines. Thumbnail
        // bytes are unchanged (they're template masks), so no data re-push.
        WidgetHelper.shared.updateThemeColor(reload: true)

        completion?()
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
