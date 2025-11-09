//
//  ThumbnailMigration.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

/// Utility to migrate existing entries and generate thumbnails for those without them
@MainActor
class ThumbnailMigration {
  static let shared = ThumbnailMigration()

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
          entry.drawingThumbnail20 == nil
        {
          // Generate thumbnails
          let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(
            from: drawingData)

          // Update entry with thumbnails
          entry.drawingThumbnail20 = thumbnails.0
          entry.drawingThumbnail200 = thumbnails.1
          entry.drawingThumbnail1080 = thumbnails.2

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
          entry.drawingThumbnail20 == nil
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
    entry.drawingThumbnail1080 = thumbnails.2

    try? modelContext.save()
  }
}
