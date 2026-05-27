//
//  SceneDelegate.swift
//  Joodle
//
//  Handles Home Screen quick actions (long-press app icon).
//

import UIKit

enum QuickActionType: String {
  case today = "dev.liyuxuan.joodle.shortcut.today"
  case nextAnniversary = "dev.liyuxuan.joodle.shortcut.nextAnniversary"
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
  /// Holds a quick action received during cold launch until the SwiftUI tree is ready to receive it.
  static var pendingShortcutItem: UIApplicationShortcutItem?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let item = connectionOptions.shortcutItem {
      // Cold launch: defer until the launch screen finishes so the SwiftUI observers are wired up.
      Self.pendingShortcutItem = item
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
        if let pending = Self.pendingShortcutItem {
          Self.pendingShortcutItem = nil
          Task { @MainActor in Self.dispatch(pending) }
        }
      }
    }
  }

  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    Task { @MainActor in Self.dispatch(shortcutItem) }
    completionHandler(true)
  }

  @MainActor
  private static func dispatch(_ item: UIApplicationShortcutItem) {
    guard let type = QuickActionType(rawValue: item.type) else { return }

    AnalyticsManager.shared.track(.navigatedFromShortcut)

    switch type {
    case .today:
      ShortcutActionState.navigateAndOpenCanvas(date: Date(), source: "quick_action")
    case .nextAnniversary:
      let date = NextAnniversaryFinder.nextAnniversaryDate() ?? Date()
      NotificationCenter.default.post(
        name: .navigateToDateFromShortcut,
        object: nil,
        userInfo: ["date": date, "source": "quick_action"]
      )
    }
  }
}
