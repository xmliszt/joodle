//
//  ThumbnailMigration.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

/// Utility to migrate existing entries and generate thumbnails for those without them
@MainActor
class ThumbnailMigration {
  static let shared = ThumbnailMigration()

  private static let legacyThumbnailCleanupKey = "hasCleanedLegacy1080Thumbnails_v1"
  private static let dualThumbnailRegenerationKey = "hasRegeneratedDualThumbnails_v1"

  private init() {}

  /// Migrate all entries that have drawing data but no thumbnails
  /// - Parameter modelContext: The SwiftData model context
  /// - Returns: Number of entries migrated
  func migrateExistingEntries(modelContext: ModelContext) async -> Int {
    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let allEntries = try modelContext.fetch(descriptor)
      var migratedCount = 0

      for entry in allEntries {
        // Only process entries with drawing data but missing thumbnails
        if let drawingData = entry.drawingData,
          !drawingData.isEmpty,
          entry.drawingThumbnail20 == nil || entry.drawingThumbnail200 == nil
        {
          // Generate both thumbnails
          let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(
            from: drawingData)

          // Update entry with thumbnails
          entry.drawingThumbnail20 = thumbnails.0
          entry.drawingThumbnail200 = thumbnails.1

          migratedCount += 1

          // Save periodically to avoid memory buildup
          if migratedCount % 10 == 0 {
            try? modelContext.save()
          }
        }
      }

      // Final save
      if migratedCount > 0 {
        try? modelContext.save()
      }

      return migratedCount
    } catch {
      print("Failed to migrate entries: \(error)")
      return 0
    }
  }

  /// Clean up legacy 1080px thumbnail data to reclaim storage
  /// This only runs once per device
  /// - Parameter modelContext: The SwiftData model context
  /// - Returns: Number of entries cleaned up
  func cleanupLegacyThumbnails(modelContext: ModelContext) async -> Int {
    // Only run this cleanup once
    guard !UserDefaults.standard.bool(forKey: Self.legacyThumbnailCleanupKey) else {
      return 0
    }

    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let allEntries = try modelContext.fetch(descriptor)
      var cleanedCount = 0

      for entry in allEntries {
        // Clear legacy 1080px thumbnail only
        if entry.drawingThumbnail1080 != nil {
          entry.drawingThumbnail1080 = nil
          cleanedCount += 1

          // Save periodically to avoid memory buildup
          if cleanedCount % 10 == 0 {
            try? modelContext.save()
          }
        }
      }

      // Final save
      if cleanedCount > 0 {
        try? modelContext.save()
        print("ThumbnailMigration: Cleaned up legacy 1080px thumbnails from \(cleanedCount) entries")
      }

      // Mark cleanup as complete
      UserDefaults.standard.set(true, forKey: Self.legacyThumbnailCleanupKey)

      return cleanedCount
    } catch {
      print("Failed to cleanup legacy thumbnails: \(error)")
      return 0
    }
  }

  /// Check if migration is needed
  /// - Parameter modelContext: The SwiftData model context
  /// - Returns: Number of entries that need migration
  func checkMigrationNeeded(modelContext: ModelContext) -> Int {
    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let allEntries = try modelContext.fetch(descriptor)
      let needsMigration = allEntries.filter { entry in
        if let drawingData = entry.drawingData,
          !drawingData.isEmpty,
          entry.drawingThumbnail20 == nil || entry.drawingThumbnail200 == nil
        {
          return true
        }
        return false
      }
      return needsMigration.count
    } catch {
      print("Failed to check migration: \(error)")
      return 0
    }
  }

  /// Regenerate thumbnails for a specific entry
  /// - Parameters:
  ///   - entry: The entry to regenerate thumbnails for
  ///   - modelContext: The SwiftData model context
  func regenerateThumbnails(for entry: DayEntry, modelContext: ModelContext) async {
    guard let drawingData = entry.drawingData, !drawingData.isEmpty else {
      return
    }

    let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(from: drawingData)

    entry.drawingThumbnail20 = thumbnails.0
    entry.drawingThumbnail200 = thumbnails.1

    try? modelContext.save()
  }

  /// Regenerate all thumbnails with dual sizes (20px with thicker strokes, 200px normal)
  /// This only runs once per device when updating to the dual thumbnail version
  /// - Parameter modelContext: The SwiftData model context
  /// - Returns: Number of entries regenerated
  func regenerateAllThumbnailsWithDualSizes(modelContext: ModelContext) async -> Int {
    // Only run this regeneration once
    guard !UserDefaults.standard.bool(forKey: Self.dualThumbnailRegenerationKey) else {
      return 0
    }

    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let allEntries = try modelContext.fetch(descriptor)
      var regeneratedCount = 0

      for entry in allEntries {
        // Regenerate thumbnails for any entry with drawing data
        if let drawingData = entry.drawingData, !drawingData.isEmpty {
          let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(
            from: drawingData)

          entry.drawingThumbnail20 = thumbnails.0
          entry.drawingThumbnail200 = thumbnails.1
          regeneratedCount += 1

          // Save periodically to avoid memory buildup
          if regeneratedCount % 10 == 0 {
            try? modelContext.save()
          }
        }
      }

      // Final save
      if regeneratedCount > 0 {
        try? modelContext.save()
        print("ThumbnailMigration: Regenerated \(regeneratedCount) entries with dual thumbnails (20px + 200px)")
      }

      // Mark regeneration as complete
      UserDefaults.standard.set(true, forKey: Self.dualThumbnailRegenerationKey)

      return regeneratedCount
    } catch {
      print("Failed to regenerate thumbnails: \(error)")
      return 0
    }
  }
}
