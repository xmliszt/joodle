//
//  CanvasSizeMigration.swift
//  Joodle
//
//  Created by Li Yuxuan on 2/8/26.
//

import SwiftData
import SwiftUI

/// One-time migration to center existing drawings after canvas size increase from 300 → 342.
///
/// Old drawings have path points in the range 0–300. With the new 342px canvas, these drawings
/// would appear pinned to the top-left corner. This migration translates all points by
/// `(+21, +21)` — half the size difference — so old doodles appear centered within the larger canvas.
/// Thumbnails are regenerated after the coordinate shift.
class CanvasSizeMigration {
  static let shared = CanvasSizeMigration()

  private static let migrationKey = "hasRunCanvasSizeMigration_300_to_342_v1"

  /// The offset to center old drawings: (342 - 300) / 2 = 21
  private static let offset: CGFloat = (CANVAS_SIZE - LEGACY_CANVAS_SIZE) / 2

  private init() {}

  /// Migrate all existing drawing data by centering path points and regenerating thumbnails.
  /// This runs once per device, gated by a UserDefaults flag.
  /// - Parameter container: The shared ModelContainer
  static func runIfNeeded(container: ModelContainer) {
    guard !UserDefaults.standard.bool(forKey: migrationKey) else {
      return
    }

    Task.detached {
      let context = ModelContext(container)
      let descriptor = FetchDescriptor<DayEntry>()

      do {
        let allEntries = try context.fetch(descriptor)
        var migratedCount = 0

        for entry in allEntries {
          guard let drawingData = entry.drawingData, !drawingData.isEmpty else {
            continue
          }

          // Decode existing path data
          guard let pathsData = try? JSONDecoder().decode([PathData].self, from: drawingData) else {
            continue
          }

          // Translate all points by the offset to center within the new canvas
          let migratedPaths = pathsData.map { pathData in
            let translatedPoints = pathData.points.map { point in
              CGPoint(x: point.x + offset, y: point.y + offset)
            }
            return PathData(points: translatedPoints, isDot: pathData.isDot)
          }

          // Re-encode the migrated path data
          guard let newDrawingData = try? JSONEncoder().encode(migratedPaths) else {
            continue
          }

          entry.drawingData = newDrawingData

          // Regenerate thumbnails with the updated coordinates
          let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(
            from: newDrawingData)
          entry.drawingThumbnail20 = thumbnails.0
          entry.drawingThumbnail200 = thumbnails.1

          migratedCount += 1

          // Save periodically to avoid memory buildup
          if migratedCount % 10 == 0 {
            try? context.save()
          }
        }

        if migratedCount > 0 {
          try context.save()
          print("CanvasSizeMigration: Centered \(migratedCount) drawings from 300px → 342px canvas")
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
      } catch {
        print("CanvasSizeMigration: Failed - \(error)")
      }
    }
  }
}
