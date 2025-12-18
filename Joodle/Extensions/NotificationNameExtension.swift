//
//  Notifications.swift
//  Joodle
//
//  Created by Li Yuxuan on 14/8/25.
//

import Foundation

extension Notification.Name {
  static let deviceDidShake = Notification.Name("deviceDidShake")
  static let didChangeColorScheme = Notification.Name("didChangeColorScheme")
  static let didChangeAccentColor = Notification.Name("didChangeAccentColor")
  static let navigateToDateFromShortcut = Notification.Name("navigateToDateFromShortcut")
  static let dismissToRootAndNavigate = Notification.Name("dismissToRootAndNavigate")
}
