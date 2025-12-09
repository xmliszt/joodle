//
//  DateStringMigration.swift
//  Joodle
//
//  Migration helper to populate dateString for existing DayEntry records
//

import Foundation
import SwiftData

/// Handles migration of existing DayEntry records to populate the dateString field
/// This is needed for entries created before the timezone-agnostic dateString was introduced
class DateStringMigration {
  static let shared = DateStringMigration()

  private init() {}

  /// Migrates all existing entries that have an empty dateString
  /// - Parameter modelContext: The SwiftData model context
  /// - Returns: The number of entries that were migrated
  @MainActor
  func migrateExistingEntries(modelContext: ModelContext) async -> Int {
    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let allEntries = try modelContext.fetch(descriptor)
      var migratedCount = 0

      for entry in allEntries {
        // Only migrate entries with empty dateString
        if entry.dateString.isEmpty {
          // Generate dateString from the existing createdAt date
          // This uses the current timezone, which should be acceptable for migration
          // since the user's original timezone when creating the entry is unknown
          entry.dateString = DayEntry.dateToString(entry.createdAt)
          migratedCount += 1
        }
      }

      if migratedCount > 0 {
        try modelContext.save()
        print("DateStringMigration: Successfully migrated \(migratedCount) entries")
      }

      return migratedCount
    } catch {
      print("DateStringMigration: Failed to migrate entries: \(error)")
      return 0
    }
  }

  /// Checks how many entries need migration
  /// - Parameter modelContext: The SwiftData model context
  /// - Returns: The number of entries that need dateString migration
  func checkMigrationNeeded(modelContext: ModelContext) -> Int {
    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let allEntries = try modelContext.fetch(descriptor)
      let needsMigration = allEntries.filter { entry in
        entry.dateString.isEmpty
      }
      return needsMigration.count
    } catch {
      print("DateStringMigration: Failed to check migration status: \(error)")
      return 0
    }
  }
}
