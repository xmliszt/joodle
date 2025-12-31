//
//  CalendarGridHelper.swift
//  Joodle
//
//  Shared utilities for calendar grid layout calculations.
//

import Foundation
import SwiftUI

// MARK: - Constants

/// Start of week configuration: "sunday" or "monday"
/// Dynamically reads from UserPreferences to support user customization
var START_OF_WEEK: String {
    UserPreferences.shared.startOfWeek
}

// MARK: - Calendar Grid Helper

enum CalendarGridHelper {

  // MARK: - Calendar Week Alignment

  /// Calculate the number of empty slots needed at the beginning of the grid
  /// to align the first day of the year with the correct weekday column.
  ///
  /// This is only applicable for calendar week view (7 days per row).
  ///
  /// - Parameters:
  ///   - year: The year to calculate for
  ///   - startOfWeek: The start of week preference ("sunday" or "monday")
  /// - Returns: Number of empty slots needed at the beginning
  ///
  /// Example: For 2025 with Sunday start:
  /// - January 1, 2025 is a Wednesday (weekday = 4)
  /// - Leading empty slots = 4 - 1 = 3 (for Sunday, Monday, Tuesday)
  /// - First row: [empty, empty, empty, Wed Jan 1, Thu Jan 2, Fri Jan 3, Sat Jan 4]
  static func leadingEmptySlots(for year: Int, startOfWeek: String = START_OF_WEEK) -> Int {
    let calendar = Calendar.current
    guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
      return 0
    }

    // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    let weekday = calendar.component(.weekday, from: startOfYear)

    if startOfWeek.lowercased() == "sunday" {
      // Sunday start: Sunday = column 0, Monday = column 1, ..., Saturday = column 6
      // offset = weekday - 1
      return weekday - 1
    } else {
      // Monday start: Monday = column 0, ..., Sunday = column 6
      // If weekday is Sunday (1), offset = 6 (Sunday is last day of week)
      // If weekday is Monday (2), offset = 0
      // Formula: (weekday - 2 + 7) % 7
      return (weekday - 2 + 7) % 7
    }
  }

  // MARK: - Grid Spacing Calculation

  /// Calculate the spacing between dots in the grid based on container width and view mode.
  ///
  /// - Parameters:
  ///   - containerWidth: The total width of the container
  ///   - viewMode: The current view mode (.now or .year)
  /// - Returns: The calculated spacing between dots
  static func calculateSpacing(containerWidth: CGFloat, viewMode: ViewMode) -> CGFloat {
    let gridWidth = containerWidth - (2 * GRID_HORIZONTAL_PADDING)
    let totalDotsWidth = viewMode.dotSize * CGFloat(viewMode.dotsPerRow)
    let availableSpace = gridWidth - totalDotsWidth
    let spacing = availableSpace / CGFloat(viewMode.dotsPerRow - 1)

    // Apply minimum spacing based on view mode
    let minimumSpacing: CGFloat = viewMode == .now ? 4 : 2
    return max(minimumSpacing, spacing)
  }

  // MARK: - Grid Position Calculations

  /// Convert an item index to grid row and column, accounting for leading empty slots.
  ///
  /// - Parameters:
  ///   - itemIndex: The index of the item in the items array (0-based)
  ///   - viewMode: The current view mode
  ///   - year: The year being displayed (for calendar alignment calculation)
  /// - Returns: A tuple of (row, column) in the grid
  static func gridPosition(
    forItemIndex itemIndex: Int,
    viewMode: ViewMode,
    year: Int
  ) -> (row: Int, col: Int) {
    let leadingOffset = viewMode == .now ? leadingEmptySlots(for: year) : 0
    let virtualIndex = itemIndex + leadingOffset
    let row = virtualIndex / viewMode.dotsPerRow
    let col = virtualIndex % viewMode.dotsPerRow
    return (row, col)
  }

  /// Convert a grid position (row, column) to an item index, accounting for leading empty slots.
  ///
  /// - Parameters:
  ///   - row: The row in the grid (0-based)
  ///   - col: The column in the grid (0-based)
  ///   - viewMode: The current view mode
  ///   - year: The year being displayed (for calendar alignment calculation)
  /// - Returns: The item index, or nil if the position is in an empty leading slot
  static func itemIndex(
    forRow row: Int,
    col: Int,
    viewMode: ViewMode,
    year: Int
  ) -> Int? {
    let leadingOffset = viewMode == .now ? leadingEmptySlots(for: year) : 0
    let virtualIndex = row * viewMode.dotsPerRow + col

    // Convert virtual index to actual item index
    let itemIndex = virtualIndex - leadingOffset

    // Return nil if position is in leading empty slots
    guard itemIndex >= 0 else { return nil }
    return itemIndex
  }

  /// Calculate the total number of rows needed for the grid, including leading empty slots.
  ///
  /// - Parameters:
  ///   - itemCount: The number of items in the grid
  ///   - viewMode: The current view mode
  ///   - year: The year being displayed (for calendar alignment calculation)
  /// - Returns: The total number of rows
  static func totalRows(
    forItemCount itemCount: Int,
    viewMode: ViewMode,
    year: Int
  ) -> Int {
    let leadingOffset = viewMode == .now ? leadingEmptySlots(for: year) : 0
    let totalVirtualItems = leadingOffset + itemCount
    return (totalVirtualItems + viewMode.dotsPerRow - 1) / viewMode.dotsPerRow
  }

  // MARK: - Hit Testing

  /// Parameters needed for hit testing calculations
  struct HitTestParameters {
    let containerWidth: CGFloat
    let viewMode: ViewMode
    let year: Int
    let itemCount: Int
    /// Location adjusted for grid coordinate space (x adjusted for padding, y adjusted for dot centering)
    let adjustedLocation: CGPoint
  }

  /// Find the item index at a given location in the grid.
  ///
  /// - Parameter params: The hit test parameters
  /// - Returns: The item index at the location, or nil if outside bounds or in empty slot
  static func itemIndex(at params: HitTestParameters) -> Int? {
    let spacing = calculateSpacing(containerWidth: params.containerWidth, viewMode: params.viewMode)

    let gridWidth = params.containerWidth - (2 * GRID_HORIZONTAL_PADDING)
    let totalSpacingWidth = CGFloat(params.viewMode.dotsPerRow - 1) * spacing
    let totalDotWidth = gridWidth - totalSpacingWidth
    let itemSpacing = totalDotWidth / CGFloat(params.viewMode.dotsPerRow)
    let startX = itemSpacing / 2

    let rowHeight = params.viewMode.dotSize + spacing
    let row = max(0, Int(floor(params.adjustedLocation.y / rowHeight)))

    // Find closest column by distance
    var closestCol = 0
    var minDistance = CGFloat.greatestFiniteMagnitude

    for col in 0..<params.viewMode.dotsPerRow {
      let xPos = startX + CGFloat(col) * (itemSpacing + spacing)
      let distance = abs(params.adjustedLocation.x - xPos)
      if distance < minDistance {
        minDistance = distance
        closestCol = col
      }
    }

    let col = max(0, min(params.viewMode.dotsPerRow - 1, closestCol))

    // Get item index accounting for leading empty slots
    guard let index = itemIndex(forRow: row, col: col, viewMode: params.viewMode, year: params.year),
          index < params.itemCount
    else {
      return nil
    }

    return index
  }

  /// Adjust a touch location to the grid's coordinate space.
  ///
  /// - Parameters:
  ///   - location: The original touch location
  ///   - containerWidth: The container width for spacing calculation
  ///   - viewMode: The current view mode
  ///   - horizontalPaddingAdjustment: Whether to adjust for horizontal padding (depends on coordinate space)
  /// - Returns: The adjusted location suitable for hit testing
  static func adjustLocationForHitTesting(
    _ location: CGPoint,
    containerWidth: CGFloat,
    viewMode: ViewMode,
    horizontalPaddingAdjustment: Bool = true
  ) -> CGPoint {
    let spacing = calculateSpacing(containerWidth: containerWidth, viewMode: viewMode)

    let adjustedX = horizontalPaddingAdjustment ? location.x - GRID_HORIZONTAL_PADDING : location.x
    // Account for dot centering: half spacing + half dot size
    let adjustedY = location.y + (spacing / 2) + (viewMode.dotSize / 2)

    return CGPoint(x: adjustedX, y: adjustedY)
  }

  // MARK: - Convenience Methods

  /// Get the item ID at a location in the grid.
  ///
  /// - Parameters:
  ///   - location: The touch location (in grid coordinate space, before adjustment)
  ///   - containerWidth: The container width
  ///   - viewMode: The current view mode
  ///   - year: The year being displayed
  ///   - items: The array of DateItems
  ///   - horizontalPaddingAdjustment: Whether to adjust for horizontal padding
  /// - Returns: The item ID at the location, or nil if outside bounds
  static func itemId(
    at location: CGPoint,
    containerWidth: CGFloat,
    viewMode: ViewMode,
    year: Int,
    items: [DateItem],
    horizontalPaddingAdjustment: Bool = true
  ) -> String? {
    let adjustedLocation = adjustLocationForHitTesting(
      location,
      containerWidth: containerWidth,
      viewMode: viewMode,
      horizontalPaddingAdjustment: horizontalPaddingAdjustment
    )

    let params = HitTestParameters(
      containerWidth: containerWidth,
      viewMode: viewMode,
      year: year,
      itemCount: items.count,
      adjustedLocation: adjustedLocation
    )

    guard let index = itemIndex(at: params) else { return nil }
    return items[index].id
  }
}
