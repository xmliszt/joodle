//
//  UserPreferences.swift
//  Joodle
//
//  Created by Li Yuxuan on 11/8/25.
//

import Foundation
import Observation
import SwiftUI

enum Pref {
  // MARK: - Step 1: Register Pref key here.
  static let defaultViewMode = Key(key: "default_view_mode", default: ViewMode.now)
  static let preferredColorScheme = Key<ColorScheme?>(key: "preferred_color_scheme", default: nil)
  static let enableHaptic = Key(key: "enable_haptic", default: true)
  static let isCloudSyncEnabled = Key(key: "is_cloud_sync_enabled", default: false)
  static let accentColor = Key(key: "accent_color", default: ThemeColor.defaultColor)
  static let isDailyReminderEnabled = Key(key: "is_daily_reminder_enabled", default: false)
  // Default to 9:00 AM - stored as seconds from midnight
  static let dailyReminderTimeSeconds = Key(key: "daily_reminder_time_seconds", default: 9 * 3600)
  // Start of week: "sunday" or "monday"
  static let startOfWeek = Key(key: "start_of_week", default: "sunday")

  // Experimental features
  static let enableTimeBackdrop = Key(key: "enable_time_backdrop", default: false)

  // Add new preferences here - just specify the default!
  // static let newSetting = Key(default: "defaultValue")

  struct Key<T> {
    let key: String
    let defaultValue: T

    init(key: String, default defaultValue: T) {
      self.key = key
      self.defaultValue = defaultValue
    }
  }

  // Auto-generated list of all keys for reset
  // MARK: - Step 2: Add your key here
  static let allKeys = [
    defaultViewMode.key,
    preferredColorScheme.key,
    enableHaptic.key,
    isCloudSyncEnabled.key,
    accentColor.key,
    isDailyReminderEnabled.key,
    dailyReminderTimeSeconds.key,
    startOfWeek.key,
    enableTimeBackdrop.key,
  ]
}

// MARK: - UserPreferences
@Observable
final class UserPreferences {

  // MARK: - Singleton
  static let shared = UserPreferences()
  private let defaults = UserDefaults.standard

  // MARK: - Helper Methods
  private func get<T>(_ key: Pref.Key<T>) -> T {
    defaults.object(forKey: key.key) as? T ?? key.defaultValue
  }

  private func set<T>(_ key: Pref.Key<T>, _ value: T?) {
    if let value {
      defaults.set(value, forKey: key.key)
    } else {
      defaults.removeObject(forKey: key.key)
    }
  }

  // MARK: - Step 3: Add your property here to be exposed to public
  var defaultViewMode: ViewMode = Pref.defaultViewMode.defaultValue {
    didSet {
      _defaultViewModeWatcher = defaultViewMode
    }
  }
  var preferredColorScheme: ColorScheme? = Pref.preferredColorScheme.defaultValue {
    didSet {
      _preferredColorSchemeWatcher = preferredColorScheme
    }
  }
  var enableHaptic: Bool = Pref.enableHaptic.defaultValue {
    didSet {
      _enableHapticWatcher = enableHaptic
    }
  }
  var isCloudSyncEnabled: Bool = Pref.isCloudSyncEnabled.defaultValue {
    didSet { _isCloudSyncEnabledWatcher = isCloudSyncEnabled }
  }
  var accentColor: ThemeColor = Pref.accentColor.defaultValue {
    didSet {
      _accentColorWatcher = accentColor
      // Notify the app to update the accent color
      NotificationCenter.default.post(name: .didChangeAccentColor, object: nil)
    }
  }
  var isDailyReminderEnabled: Bool = Pref.isDailyReminderEnabled.defaultValue {
    didSet {
      _isDailyReminderEnabledWatcher = isDailyReminderEnabled
    }
  }
  var dailyReminderTimeSeconds: Int = Pref.dailyReminderTimeSeconds.defaultValue {
    didSet {
      _dailyReminderTimeSecondsWatcher = dailyReminderTimeSeconds
    }
  }
  var startOfWeek: String = Pref.startOfWeek.defaultValue {
    didSet {
      _startOfWeekWatcher = startOfWeek
    }
  }

  // Experimental features
  var enableTimeBackdrop: Bool = Pref.enableTimeBackdrop.defaultValue {
    didSet {
      _enableTimeBackdropWatcher = enableTimeBackdrop
    }
  }

  /// Convenience computed property to get/set daily reminder time as Date
  var dailyReminderTime: Date {
    get {
      let hour = dailyReminderTimeSeconds / 3600
      let minute = (dailyReminderTimeSeconds % 3600) / 60
      var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
      components.hour = hour
      components.minute = minute
      return Calendar.current.date(from: components) ?? Date()
    }
    set {
      let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
      dailyReminderTimeSeconds = (components.hour ?? 9) * 3600 + (components.minute ?? 0) * 60
    }
  }

  // MARK: - Step 4: Add private watchers that update UserDefaults when properties change
  private var _defaultViewModeWatcher: ViewMode {
    get {
      if let rawValue = defaults.string(forKey: Pref.defaultViewMode.key),
         let mode = ViewMode(rawValue: rawValue)
      {
        return mode
      }
      return Pref.defaultViewMode.defaultValue
    }
    set {
      defaults.set(newValue.rawValue, forKey: Pref.defaultViewMode.key)
    }
  }

  private var _preferredColorSchemeWatcher: ColorScheme? {
    get {
      if let rawValue = defaults.string(forKey: Pref.preferredColorScheme.key) {
        return rawValue == "light" ? .light : rawValue == "dark" ? .dark : nil
      }
      return Pref.preferredColorScheme.defaultValue
    }
    set {
      if let scheme = newValue {
        defaults.set(scheme == .light ? "light" : "dark", forKey: Pref.preferredColorScheme.key)
      } else {
        defaults.removeObject(forKey: Pref.preferredColorScheme.key)
      }
    }
  }

  private var _enableHapticWatcher: Bool {
    get { get(Pref.enableHaptic) }
    set { set(Pref.enableHaptic, newValue) }
  }

  private var _isCloudSyncEnabledWatcher: Bool {
    get { get(Pref.isCloudSyncEnabled) }
    set { set(Pref.isCloudSyncEnabled, newValue) }
  }

  private var _accentColorWatcher: ThemeColor {
    get {
      if let rawValue = defaults.string(forKey: Pref.accentColor.key),
         let color = ThemeColor(rawValue: rawValue) {
        return color
      }
      return Pref.accentColor.defaultValue
    }
    set {
      defaults.set(newValue.rawValue, forKey: Pref.accentColor.key)
    }
  }

  private var _isDailyReminderEnabledWatcher: Bool {
    get { get(Pref.isDailyReminderEnabled) }
    set { set(Pref.isDailyReminderEnabled, newValue) }
  }

  private var _dailyReminderTimeSecondsWatcher: Int {
    get { get(Pref.dailyReminderTimeSeconds) }
    set { set(Pref.dailyReminderTimeSeconds, newValue) }
  }

  private var _startOfWeekWatcher: String {
    get { get(Pref.startOfWeek) }
    set { set(Pref.startOfWeek, newValue) }
  }

  private var _enableTimeBackdropWatcher: Bool {
    get { get(Pref.enableTimeBackdrop) }
    set { set(Pref.enableTimeBackdrop, newValue) }
  }

  // MARK: - Step 5: Add your property to load during initialization
  init() {
    // Load initial values from UserDefaults
    defaultViewMode = _defaultViewModeWatcher
    preferredColorScheme = _preferredColorSchemeWatcher
    enableHaptic = _enableHapticWatcher
    isCloudSyncEnabled = _isCloudSyncEnabledWatcher
    accentColor = _accentColorWatcher
    isDailyReminderEnabled = _isDailyReminderEnabledWatcher
    dailyReminderTimeSeconds = _dailyReminderTimeSecondsWatcher
    startOfWeek = _startOfWeekWatcher
    enableTimeBackdrop = _enableTimeBackdropWatcher
  }

  // MARK: - Reset Method (automatically uses all registered keys!)
  func resetToDefaults() {
    Pref.allKeys.forEach { key in
      defaults.removeObject(forKey: key)
    }
    // Reset all the properties
    // MARK: - Step 6: Add your property here to reset
    defaultViewMode = Pref.defaultViewMode.defaultValue
    preferredColorScheme = Pref.preferredColorScheme.defaultValue
    enableHaptic = Pref.enableHaptic.defaultValue
    isCloudSyncEnabled = Pref.isCloudSyncEnabled.defaultValue
    accentColor = Pref.accentColor.defaultValue
    isDailyReminderEnabled = Pref.isDailyReminderEnabled.defaultValue
    dailyReminderTimeSeconds = Pref.dailyReminderTimeSeconds.defaultValue
    startOfWeek = Pref.startOfWeek.defaultValue
    enableTimeBackdrop = Pref.enableTimeBackdrop.defaultValue
  }

}

// MARK: - Environment Extension
extension EnvironmentValues {
  @Entry var userPreferences: UserPreferences = UserPreferences.shared
}
