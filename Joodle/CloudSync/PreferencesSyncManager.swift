//
//  PreferencesSyncManager.swift
//  Joodle
//
//  Simplified to only handle sync state persistence for reinstall detection.
//  User preferences are intentionally NOT synced - they are device-specific settings.
//

import Foundation
import Observation
import SwiftUI

/// Manages sync state persistence via iCloud KVS for reinstall detection.
///
/// Design Philosophy:
/// - Journal entries sync via SwiftData + CloudKit (automatic)
/// - User preferences stay LOCAL to each device (intentional)
/// - Users may want different settings per device (dark mode on iPhone, light on iPad)
///
/// This manager only persists sync state to detect reinstalls and restore CloudKit configuration.
@Observable
final class PreferencesSyncManager {
  // MARK: - Singleton
  static let shared = PreferencesSyncManager()

  // MARK: - Private Properties
  private let cloudStore = NSUbiquitousKeyValueStore.default

  // Keys for iCloud KVS - ONLY sync state, NOT preferences
  private enum CloudKey {
    // Sync state keys - persist across app reinstalls to detect restore scenario
    // Use two keys for redundancy (same as CloudSyncStatePersistence and JoodleApp)
    static let primarySyncKey = "is_cloud_sync_enabled_backup"
    static let secondarySyncKey = "cloud_sync_was_enabled"
    // Timestamp of when sync was last enabled (for debugging)
    static let cloudSyncEnabledTimestamp = "cloud_sync_enabled_timestamp"
  }

  // Legacy preference keys that were synced in old versions (now removed)
  // These are cleaned up on first launch to prevent any stale data issues
  private static let legacyPreferenceKeys = [
    "default_view_mode",
    "preferred_color_scheme",
    "enable_haptic",
    "start_of_week",
    "accent_color",
    "is_daily_reminder_enabled",
    "daily_reminder_time_seconds",
    "enable_time_backdrop"
  ]

  // MARK: - Initialization
  private init() {
    // Synchronize on init to get latest values from iCloud
    cloudStore.synchronize()
    // Clean up any legacy preference keys from old versions
    cleanupLegacyPreferenceKeys()
  }

  // MARK: - Legacy Cleanup

  /// Remove old preference keys from iCloud KVS that were synced in previous versions.
  /// User preferences are now device-local only - this prevents stale cloud data from causing issues.
  private func cleanupLegacyPreferenceKeys() {
    var didCleanup = false

    for key in Self.legacyPreferenceKeys {
      if cloudStore.object(forKey: key) != nil {
        cloudStore.removeObject(forKey: key)
        didCleanup = true
        print("PreferencesSyncManager: Removing legacy key '\(key)' from iCloud KVS")
      }
    }

    if didCleanup {
      cloudStore.synchronize()
      print("PreferencesSyncManager: Cleaned up legacy preference keys from iCloud KVS")
    }
  }

  // MARK: - Sync State Persistence (Survives App Reinstall)

  /// Save sync enabled state to iCloud KVS - call when user enables sync
  /// Writes to both primary and secondary keys for redundancy
  func saveSyncEnabledToCloud() {
    cloudStore.set(true, forKey: CloudKey.primarySyncKey)
    cloudStore.set(true, forKey: CloudKey.secondarySyncKey)
    cloudStore.set(Date().timeIntervalSince1970, forKey: CloudKey.cloudSyncEnabledTimestamp)
    cloudStore.synchronize()
    print("PreferencesSyncManager: Saved sync enabled state to iCloud KVS")
  }

  /// Clear sync enabled state from iCloud KVS - call when user explicitly disables sync
  /// Clears both primary and secondary keys
  func clearSyncEnabledFromCloud() {
    cloudStore.set(false, forKey: CloudKey.primarySyncKey)
    cloudStore.set(false, forKey: CloudKey.secondarySyncKey)
    cloudStore.removeObject(forKey: CloudKey.cloudSyncEnabledTimestamp)
    cloudStore.synchronize()
    print("PreferencesSyncManager: Cleared sync enabled state from iCloud KVS")
  }

  /// Check if iCloud indicates sync was previously enabled (for reinstall detection)
  /// This is a static method so it can be called before UserPreferences is fully initialized
  /// Checks both primary and secondary keys for redundancy
  static func checkCloudSyncWasEnabled() -> Bool {
    let cloudStore = NSUbiquitousKeyValueStore.default
    // Force sync to get latest values from iCloud
    cloudStore.synchronize()
    let wasEnabled = cloudStore.bool(forKey: CloudKey.primarySyncKey) || cloudStore.bool(forKey: CloudKey.secondarySyncKey)
    print("PreferencesSyncManager: checkCloudSyncWasEnabled = \(wasEnabled)")
    return wasEnabled
  }

  /// Detect reinstall scenario: iCloud says sync was enabled, but local preference says no
  /// Returns true if we should restore cloud sync state
  static func shouldRestoreCloudSync() -> Bool {
    let cloudStore = NSUbiquitousKeyValueStore.default
    cloudStore.synchronize()

    let cloudSaysEnabled = cloudStore.bool(forKey: CloudKey.primarySyncKey) || cloudStore.bool(forKey: CloudKey.secondarySyncKey)
    let localSaysEnabled = UserDefaults.standard.bool(forKey: Pref.isCloudSyncEnabled.key)

    // Reinstall scenario: cloud has sync enabled but local doesn't know about it
    // Also check that system iCloud is available
    let systemCloudEnabled = FileManager.default.ubiquityIdentityToken != nil

    if cloudSaysEnabled && !localSaysEnabled && systemCloudEnabled {
      print("PreferencesSyncManager: Detected reinstall with existing iCloud data - restoring sync state")
      return true
    }

    return false
  }

  /// Restore cloud sync state after reinstall detection
  static func restoreCloudSyncState() {
    // Update local UserDefaults to match iCloud state
    UserDefaults.standard.set(true, forKey: Pref.isCloudSyncEnabled.key)
    // Also update the in-memory UserPreferences singleton
    UserPreferences.shared.isCloudSyncEnabled = true
    print("PreferencesSyncManager: Restored iCloud sync state from cloud")
  }

  // MARK: - Debug Helpers

  /// Get the timestamp when sync was last enabled (for debugging)
  func getLastSyncEnabledTimestamp() -> Date? {
    let timestamp = cloudStore.double(forKey: CloudKey.cloudSyncEnabledTimestamp)
    guard timestamp > 0 else { return nil }
    return Date(timeIntervalSince1970: timestamp)
  }

  /// Print current iCloud KVS state for debugging
  func printDebugState() {
    cloudStore.synchronize()
    print("=== PreferencesSyncManager Debug State ===")
    print("Primary sync key: \(cloudStore.bool(forKey: CloudKey.primarySyncKey))")
    print("Secondary sync key: \(cloudStore.bool(forKey: CloudKey.secondarySyncKey))")
    if let timestamp = getLastSyncEnabledTimestamp() {
      print("Last sync enabled: \(timestamp)")
    } else {
      print("Last sync enabled: never")
    }
    print("==========================================")
  }
}

// MARK: - Environment Extension
extension EnvironmentValues {
  @Entry var preferencesSyncManager: PreferencesSyncManager = PreferencesSyncManager.shared
}
