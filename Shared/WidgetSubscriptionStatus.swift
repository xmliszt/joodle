//
//  WidgetSubscriptionStatus.swift
//  Joodle
//
//  Shared subscription status model between main app and widget extension
//

import Foundation

/// Subscription status shared between main app and widget extension.
///
/// This struct is encoded by the main app (via `WidgetHelper`) into shared
/// `UserDefaults` (App Group) and decoded by the widget extension (via
/// `WidgetDataManager`) to determine whether premium features should be shown.
struct WidgetSubscriptionStatus: Codable {
  let hasPremiumAccess: Bool
  let expirationDate: Date?
  let lastUpdated: Date

  init(hasPremiumAccess: Bool, expirationDate: Date? = nil) {
    self.hasPremiumAccess = hasPremiumAccess
    self.expirationDate = expirationDate
    self.lastUpdated = Date()
  }

  private enum CodingKeys: String, CodingKey {
    case hasPremiumAccess = "isSubscribed"
    case expirationDate
    case lastUpdated
  }

  /// Check if status was recently updated (within last hour).
  /// Used as a supplementary freshness indicator — not as a gating mechanism
  /// for premium access.
  var isValid: Bool {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    return lastUpdated > oneHourAgo
  }
}
