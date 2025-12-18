//
//  AppShortcuts.swift
//  Joodle
//
//  App Shortcuts for Siri integration
//

import AppIntents
import SwiftData
import SwiftUI

// MARK: - Create Today's Doodle Intent

/// An App Intent that opens the app to today's doodle entry
struct CreateTodaysDoodleIntent: AppIntent {
  static var title: LocalizedStringResource = "Create Today's Doodle"
  static var description = IntentDescription("Opens Joodle to create or edit today's doodle entry")

  /// This intent opens the app when run
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult & OpensIntent {
    // Post notification to navigate to today's date when app opens
    let today = Date()
    NotificationCenter.default.post(
      name: .navigateToDateFromShortcut,
      object: nil,
      userInfo: ["date": today]
    )

    return .result()
  }
}

// MARK: - Open Next Anniversary Intent

/// An App Intent that opens the app to the next upcoming anniversary (future entry with content)
struct OpenNextAnniversaryIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Next Anniversary"
  static var description = IntentDescription("Opens Joodle to the next upcoming anniversary entry")

  /// This intent opens the app when run
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult & OpensIntent {
    // Find the next anniversary using SwiftData
    if let nextAnniversaryDate = findNextAnniversary() {
      NotificationCenter.default.post(
        name: .navigateToDateFromShortcut,
        object: nil,
        userInfo: ["date": nextAnniversaryDate]
      )
    }
    // If no anniversary found, just open the app normally

    return .result()
  }

  /// Finds the next future entry that has content (text or drawing)
  @MainActor
  private func findNextAnniversary() -> Date? {
    let container = ModelContainerManager.shared.container
    let context = ModelContext(container)

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let todayString = DayEntry.dateToString(today)

    // Fetch all entries with dateString greater than today
    let predicate = #Predicate<DayEntry> { entry in
      entry.dateString > todayString
    }

    let descriptor = FetchDescriptor<DayEntry>(
      predicate: predicate,
      sortBy: [SortDescriptor(\.dateString, order: .forward)]
    )

    do {
      let futureEntries = try context.fetch(descriptor)

      // Find the first entry that has content (text or drawing)
      for entry in futureEntries {
        let hasText = !entry.body.isEmpty
        let hasDrawing = entry.drawingData != nil && !entry.drawingData!.isEmpty

        if hasText || hasDrawing {
          return entry.displayDate
        }
      }
    } catch {
      print("AppShortcuts: Failed to fetch future entries: \(error)")
    }

    return nil
  }
}

// MARK: - Open Joodle Intent

/// A simple intent to just open the Joodle app
struct OpenJoodleIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Joodle"
  static var description = IntentDescription("Opens the Joodle app")

  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    return .result()
  }
}

// MARK: - App Shortcuts Provider
struct JoodleShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: CreateTodaysDoodleIntent(),
      phrases: [
        "Create today's doodle in \(.applicationName)",
        "Start doodling in \(.applicationName)",
        "Open today's \(.applicationName)",
        "Create a \(.applicationName)",
        "New \(.applicationName) entry",
        "Doodle in \(.applicationName)",
        "\(.applicationName) today",
        "Today in \(.applicationName)"
      ],
      shortTitle: "Joodle Today",
      systemImageName: "pencil.tip.crop.circle"
    )

    AppShortcut(
      intent: OpenNextAnniversaryIntent(),
      phrases: [
        "Open next anniversary in \(.applicationName)",
        "Show next anniversary in \(.applicationName)",
        "Next upcoming event in \(.applicationName)",
        "What's coming up in \(.applicationName)",
        "\(.applicationName) anniversary",
        "Next \(.applicationName) event",
        "Next anniversary in \(.applicationName)"
      ],
      shortTitle: "Next Anniversary",
      systemImageName: "calendar.badge.clock"
    )

    AppShortcut(
      intent: OpenJoodleIntent(),
      phrases: [
        "Open \(.applicationName)",
        "Show \(.applicationName)"
      ],
      shortTitle: "Open Joodle",
      systemImageName: "scribble.variable"
    )
  }
}
