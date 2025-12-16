import Foundation
import SwiftUI

/// Centralized manager for handling deep links, shortcuts, and notifications
@MainActor
class DeepLinkManager: ObservableObject {
  static let shared = DeepLinkManager()

  /// Published property to trigger navigation to a specific date
  /// Views should observe this and navigate when non-nil, then set back to nil
  @Published var pendingNavigationDate: Date?

  /// Published property to trigger paywall presentation
  @Published var shouldShowPaywall = false

  /// Published property to trigger navigation reset (dismiss sheets/pop to root)
  @Published var shouldResetNavigation = false

  private init() {}

  /// Handles incoming URLs (e.g. from Widgets)
  /// Scheme: joodle://
  /// Hosts: paywall, date
  func handle(url: URL) {
    guard url.scheme == "joodle" else {
      return
    }

    switch url.host {
    case "paywall":
      handlePaywallDeepLink()
    case "date":
      handleDateDeepLink(url: url)
    default:
      break
    }
  }

  /// Handles navigation requests from App Shortcuts (Siri/Spotlight)
  func handleShortcut(date: Date) {
    prepareForNavigation()
    pendingNavigationDate = date
  }

  /// Handles navigation requests from User Notifications
  func handleNotification(date: Date) {
    prepareForNavigation()
    pendingNavigationDate = date
  }

  // MARK: - Private Handlers

  private func handlePaywallDeepLink() {
    // Check subscription status before showing paywall
    Task {
      await SubscriptionManager.shared.updateSubscriptionStatus()

      // If not subscribed, show the paywall
      if !SubscriptionManager.shared.isSubscribed {
        self.shouldShowPaywall = true
      }
    }
  }

  private func handleDateDeepLink(url: URL) {
    // Format: joodle://date/{timestamp}
    guard let timestampStr = url.pathComponents.last,
          let timeInterval = TimeInterval(timestampStr) else {
      return
    }

    let date = Date(timeIntervalSince1970: timeInterval)

    prepareForNavigation()
    pendingNavigationDate = date
  }

  /// Prepares the app state for navigation (dismissing sheets, popping to root)
  private func prepareForNavigation() {
    // Trigger navigation reset
    shouldResetNavigation = true

    // Reset flag after a short delay to allow re-triggering
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.shouldResetNavigation = false
    }


  }
}

// MARK: - URL Construction Helpers

extension DeepLinkManager {
  static func makePaywallURL() -> URL? {
    return URL(string: "joodle://paywall")
  }

  static func makeDateURL(for date: Date) -> URL? {
    return URL(string: "joodle://date/\(Int(date.timeIntervalSince1970))")
  }
}
