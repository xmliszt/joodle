//
//  AppShortcuts.swift
//  Joodle
//
//  App Shortcuts for Siri integration
//

import AppIntents
import SwiftData
import SwiftUI

// MARK: - Shortcut Action State

/// Holds a deferred "open drawing canvas" request that survives cold-launch timing,
/// where the intent posts a notification before ContentView's observer is subscribed.
enum ShortcutActionState {
  @MainActor static var pendingOpenCanvas: Bool = false
}

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

    // Mark the request — ContentView reads this on appear in case it isn't yet listening
    // for the notification (cold-launch race).
    ShortcutActionState.pendingOpenCanvas = true

    // Once the today selection has landed in ContentView, ask it to open the drawing canvas.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      NotificationCenter.default.post(
        name: .openDrawingCanvasFromShortcut,
        object: nil
      )
    }

    return .result()
  }
}

// MARK: - Next Anniversary Finder

enum NextAnniversaryFinder {
  /// Finds the next future entry that has content (text or drawing).
  @MainActor
  static func nextAnniversaryDate() -> Date? {
    let container = ModelContainerManager.shared.container
    let context = ModelContext(container)

    let todayString = CalendarDate.today().dateString

    let predicate = #Predicate<DayEntry> { entry in
      entry.dateString > todayString
    }

    let descriptor = FetchDescriptor<DayEntry>(
      predicate: predicate,
      sortBy: [SortDescriptor(\.dateString, order: .forward)]
    )

    do {
      let futureEntries = try context.fetch(descriptor)
      for entry in futureEntries {
        let hasText = !entry.body.isEmpty
        let hasDrawing = entry.drawingData != nil && !entry.drawingData!.isEmpty
        if hasText || hasDrawing {
          return entry.displayDate
        }
      }
    } catch {
      print("NextAnniversaryFinder: Failed to fetch future entries: \(error)")
    }

    return nil
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
    if let nextAnniversaryDate = NextAnniversaryFinder.nextAnniversaryDate() {
      NotificationCenter.default.post(
        name: .navigateToDateFromShortcut,
        object: nil,
        userInfo: ["date": nextAnniversaryDate]
      )
    }
    return .result()
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
      shortTitle: LocalizedStringResource("Joodle Today"),
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
      shortTitle: LocalizedStringResource("Next Anniversary"),
      systemImageName: "calendar.badge.clock"
    )

    AppShortcut(
      intent: OpenJoodleIntent(),
      phrases: [
        "Open \(.applicationName)",
        "Show \(.applicationName)"
      ],
      shortTitle: LocalizedStringResource("Open Joodle"),
      systemImageName: "scribble.variable"
    )
  }
}
