//
//  WidgetHelper.swift
//  Joodle
//
//  Created by Widget Helper
//

import Foundation
import SwiftUI
import WidgetKit
import SwiftData

// NOTE: WidgetSubscriptionStatus is defined in Shared/WidgetSubscriptionStatus.swift
// and compiled into both the main app and widget extension targets.

// Note: WidgetEntryData is defined in Widgets/WidgetDataManager.swift
// This file uses the same model via App Group shared storage

/// Helper class for updating widget data from the main app
///
/// This class is responsible for syncing data between the main app and the widget.
/// It stores simplified entry data in shared UserDefaults and triggers targeted widget reloads.
///
/// Usage: Call `updateWidgetData(with:)` whenever entries change in the main app.
/// Use `scheduleWidgetDataUpdate(in:)` for debounced updates during rapid edits (e.g., drawing strokes).
/// Pass `reload: false` when batching multiple data writes before a single reload.
class WidgetHelper {
  static let shared = WidgetHelper()

  private let appGroupIdentifier = "group.dev.liyuxuan.joodle"
  private let entriesKey = "widgetEntries"
  private let subscriptionKey = "widgetSubscriptionStatus"
  private let themeColorKey = "widgetThemeColor"
  private let startOfWeekKey = "widgetStartOfWeek"
  private let appLanguageKey = "widgetAppLanguage"

  // MARK: - File-Based Drawing Storage

  /// Directory URL for individual drawing data files in the App Group shared container.
  /// Each entry's drawing data is stored as `drawings/{dateString}.dat` to keep
  /// UserDefaults payload small (metadata + thumbnails only).
  private var drawingsDirectoryURL: URL? {
    guard let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else { return nil }
    return containerURL.appendingPathComponent("drawings", isDirectory: true)
  }

  /// Ensures the drawings directory exists, creating it if needed.
  private func ensureDrawingsDirectory() -> URL? {
    guard let dirURL = drawingsDirectoryURL else { return nil }
    if !FileManager.default.fileExists(atPath: dirURL.path) {
      try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
    }
    return dirURL
  }

  /// Write drawing data to a file for a specific date entry.
  private func writeDrawingFile(dateString: String, data: Data) {
    guard let dirURL = ensureDrawingsDirectory() else { return }
    let fileURL = dirURL.appendingPathComponent("\(dateString).dat")
    try? data.write(to: fileURL, options: .atomic)
  }

  /// Remove the drawing file for a specific date entry.
  private func removeDrawingFile(dateString: String) {
    guard let dirURL = drawingsDirectoryURL else { return }
    let fileURL = dirURL.appendingPathComponent("\(dateString).dat")
    try? FileManager.default.removeItem(at: fileURL)
  }

  /// Remove orphan drawing files that are no longer present in the entries set.
  private func cleanupOrphanDrawingFiles(validDateStrings: Set<String>) {
    guard let dirURL = drawingsDirectoryURL else { return }
    guard let files = try? FileManager.default.contentsOfDirectory(atPath: dirURL.path) else { return }
    for filename in files where filename.hasSuffix(".dat") {
      let dateString = String(filename.dropLast(4)) // remove ".dat"
      if !validDateStrings.contains(dateString) {
        let fileURL = dirURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
      }
    }
  }

  // MARK: - Widget Kind Constants

  /// All 8 widget kind strings — used for full reloads
  private static let allWidgetKinds = [
    "TodayDoodleWidget",
    "WeekGridWidget",
    "MonthGridWidget",
    "RandomJoodleWidget",
    "AnniversaryWidget",
    "YearGridWidget",
    "YearGridJoodleWidget",
    "YearGridJoodleNoEmptyDotsWidget",
  ]

  /// Only widgets that depend on start-of-week preference
  private static let startOfWeekWidgetKinds = [
    "WeekGridWidget",
    "MonthGridWidget",
  ]

  // MARK: - Debounce State

  /// In-flight debounce task for `scheduleWidgetDataUpdate`.
  /// Cancelled and replaced on every new call so only the last update fires.
  private var debounceTask: Task<Void, Never>?

  private init() {}

  // MARK: - Targeted Reload Helpers

  /// Reload only the specified widget kinds via `WidgetCenter.reloadTimelines(ofKind:)`.
  /// This conserves iOS refresh budget by skipping widgets whose data hasn't changed.
  @MainActor func reloadWidgets(ofKinds kinds: [String]) {
    for kind in kinds {
      WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
  }

  /// Convenience: reload all 8 widgets.
  @MainActor func reloadAllWidgets() {
    reloadWidgets(ofKinds: Self.allWidgetKinds)
  }

  // MARK: - Subscription Status

  /// Update subscription status for widget extension
  /// - Parameter reload: When `true` (default), immediately reloads all widget timelines.
  ///   Pass `false` when batching multiple data writes before a single manual reload.
  @MainActor func updateSubscriptionStatus(reload: Bool = true) {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget subscription")
      return
    }

    // For lifetime users, use .distantFuture so the widget always has a concrete
    // expiration date to check against, avoiding any nil-expiration edge cases.
    let expirationDate: Date? = SubscriptionManager.shared.isLifetimeUser
      ? .distantFuture
      : SubscriptionManager.shared.subscriptionExpirationDate

    let status = WidgetSubscriptionStatus(
      hasPremiumAccess: SubscriptionManager.shared.hasPremiumAccess,
      expirationDate: expirationDate
    )

    do {
      let data = try JSONEncoder().encode(status)
      sharedDefaults.set(data, forKey: subscriptionKey)
      sharedDefaults.synchronize()

      if reload {
        // Subscription affects all widgets (access control overlay)
        reloadAllWidgets()
      }
    } catch {
      print("Failed to encode subscription status: \(error)")
    }
  }

  /// Load subscription status (for widget extension use)
  static func loadSubscriptionStatus(from sharedDefaults: UserDefaults) -> WidgetSubscriptionStatus? {
    guard let data = sharedDefaults.data(forKey: "widgetSubscriptionStatus") else {
      return nil
    }

    do {
      return try JSONDecoder().decode(WidgetSubscriptionStatus.self, from: data)
    } catch {
      print("Failed to decode subscription status: \(error)")
      return nil
    }
  }

  // MARK: - Theme Color

  /// Update theme color for widget extension
  /// - Parameter reload: When `true` (default), immediately reloads all widget timelines.
  ///   Pass `false` when batching multiple data writes before a single manual reload.
  @MainActor func updateThemeColor(reload: Bool = true) {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget theme color")
      return
    }

    let colorName = UserPreferences.shared.accentColor.rawValue
    sharedDefaults.set(colorName, forKey: themeColorKey)
    sharedDefaults.synchronize()

    if reload {
      // Theme color affects all widgets
      reloadAllWidgets()
    }
  }

  /// Load theme color for widget extension use
  /// - Parameter sharedDefaults: The shared UserDefaults from App Group
  /// - Returns: The Color to use for accent, defaults to asset catalog accent if not set
  static func loadThemeColor(from sharedDefaults: UserDefaults) -> Color {
    guard let colorName = sharedDefaults.string(forKey: "widgetThemeColor"),
          let themeColor = ThemeColor(rawValue: colorName) else {
      // Fallback to default theme color
      return ThemeColor.defaultColor.color
    }
    return themeColor.color
  }

  // MARK: - Start of Week

  /// Update start-of-week preference for widget extension
  /// - Parameter reload: When `true` (default), reloads only the WeekGrid and MonthGrid widgets.
  ///   Pass `false` when batching multiple data writes before a single manual reload.
  @MainActor func updateStartOfWeek(reload: Bool = true) {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget start of week")
      return
    }

    let startOfWeek = UserPreferences.shared.startOfWeek
    sharedDefaults.set(startOfWeek, forKey: startOfWeekKey)
    sharedDefaults.synchronize()

    if reload {
      // Only WeekGrid and MonthGrid depend on start-of-week
      reloadWidgets(ofKinds: Self.startOfWeekWidgetKinds)
    }
  }

  // MARK: - App Language

  /// Update app language preference for widget extension
  /// - Parameter reload: When `true` (default), immediately reloads all widget timelines.
  ///   Pass `false` when batching multiple data writes before a single manual reload.
  @MainActor func updateAppLanguage(reload: Bool = true) {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget app language")
      return
    }

    let language = UserPreferences.shared.appLanguage
    sharedDefaults.set(language, forKey: appLanguageKey)
    sharedDefaults.synchronize()

    if reload {
      // Language affects all widgets (date formatting, localized strings)
      reloadAllWidgets()
    }
  }

  // MARK: - Widget Data (Entries)

  /// Update widget data with current entries from SwiftData and reload widget timelines
  ///
  /// This method:
  /// 1. Converts DayEntry objects to WidgetEntryData (excluding 200px thumbnails for memory efficiency)
  /// 2. Saves the data to shared UserDefaults accessible by the widget
  /// 3. Optionally triggers widget timeline reload to display updated data
  ///
  /// - Parameters:
  ///   - entries: Array of DayEntry objects from SwiftData
  ///   - reload: When `true` (default), immediately reloads all widget timelines.
  ///     Pass `false` when batching multiple data writes before a single manual reload.
  @MainActor func updateWidgetData(with entries: [DayEntry], reload: Bool = true) {
    guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("Failed to access shared UserDefaults for widget")
      return
    }

    // Track valid dateStrings to clean up orphan drawing files afterwards
    var validDrawingDateStrings = Set<String>()

    // Convert DayEntry to widget-compatible dictionaries
    // Drawing data is stored as individual files in the App Group container (not in UserDefaults)
    // to keep the payload well under the ~4 MB practical limit.
    // Use dateString which is timezone-agnostic (the SINGLE SOURCE OF TRUTH)
    let widgetEntries: [[String: Any]] = entries.map { entry in
      let hasDrawing = entry.drawingData != nil && !(entry.drawingData?.isEmpty ?? true)
      var dict: [String: Any] = [
        "dateString": entry.dateString,
        "hasText": !entry.body.isEmpty,
        "hasDrawing": hasDrawing,
      ]
      // Write drawing data to file-based storage (not UserDefaults)
      if hasDrawing, let drawingData = entry.drawingData {
        writeDrawingFile(dateString: entry.dateString, data: drawingData)
        validDrawingDateStrings.insert(entry.dateString)
      }
      // Thumbnails stay in UserDefaults — they're only ~3 KB each
      if let thumbnail = entry.drawingThumbnail20 {
        dict["thumbnail"] = thumbnail
      }
      if !entry.body.isEmpty {
        dict["body"] = entry.body
      }
      return dict
    }

    // Clean up orphan drawing files for entries that no longer exist
    cleanupOrphanDrawingFiles(validDateStrings: validDrawingDateStrings)

    // Convert to Codable format for storage (no drawingData — it's in files now)
    struct WidgetEntryStorage: Codable {
      let dateString: String
      let hasText: Bool
      let hasDrawing: Bool
      let thumbnail: Data?
      let body: String?
    }

    let storageEntries = widgetEntries.map { dict in
      WidgetEntryStorage(
        dateString: dict["dateString"] as? String ?? "",
        hasText: dict["hasText"] as? Bool ?? false,
        hasDrawing: dict["hasDrawing"] as? Bool ?? false,
        thumbnail: dict["thumbnail"] as? Data,
        body: dict["body"] as? String
      )
    }

    // Encode and save to shared UserDefaults (metadata + thumbnails only)
    do {
      let data = try JSONEncoder().encode(storageEntries)

      sharedDefaults.set(data, forKey: entriesKey)
      sharedDefaults.synchronize()

      if reload {
        // All widgets depend on entry data
        reloadAllWidgets()
      }
    } catch {
      print("Failed to encode widget entries: \(error)")
    }
  }

  /// Update widget data by fetching entries from the provided ModelContext
  /// This avoids the need to pass all entries from the view
  /// - Parameters:
  ///   - modelContext: The SwiftData model context to fetch entries from
  ///   - reload: When `true` (default), immediately reloads all widget timelines.
  @MainActor func updateWidgetData(in modelContext: ModelContext, reload: Bool = true) {
    let descriptor = FetchDescriptor<DayEntry>(
      sortBy: [SortDescriptor(\.dateString)]
    )

    do {
      let entries = try modelContext.fetch(descriptor)
      updateWidgetData(with: entries, reload: reload)
    } catch {
      print("Failed to fetch entries for widget update: \(error)")
    }
  }

  // MARK: - Debounced Widget Update

  /// Schedule a debounced widget data update.
  ///
  /// Use this during rapid edits (e.g., each drawing stroke triggers `modelContext.save()`).
  /// The actual `updateWidgetData(in:)` call fires only after `debounceInterval` seconds
  /// of inactivity, preventing excessive `WidgetCenter.reloadTimelines` calls.
  ///
  /// - Parameters:
  ///   - modelContext: The SwiftData model context to fetch entries from
  ///   - debounceInterval: Seconds to wait after the last call before firing (default 2s)
  @MainActor func scheduleWidgetDataUpdate(in modelContext: ModelContext, debounceInterval: TimeInterval = 2.0) {
    // Cancel any pending update
    debounceTask?.cancel()

    debounceTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
      guard !Task.isCancelled else { return }
      updateWidgetData(in: modelContext)
    }
  }
}
