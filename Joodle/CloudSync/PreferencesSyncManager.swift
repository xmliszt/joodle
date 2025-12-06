//
//  PreferencesSyncManager.swift
//  Joodle
//
//  Created by AI Assistant
//

import Foundation
import Observation
import SwiftUI

@Observable
final class PreferencesSyncManager {
  // MARK: - Singleton
  static let shared = PreferencesSyncManager()

  // MARK: - Published State
  var isSyncing = false
  var lastSyncError: String?

  // MARK: - Private Properties
  private let cloudStore = NSUbiquitousKeyValueStore.default
  private let userPreferences = UserPreferences.shared
  private var changeObserver: NSObjectProtocol?

  // Keys for iCloud KVS (match UserPreferences keys)
  private enum CloudKey {
    static let defaultViewMode = "default_view_mode"
    static let preferredColorScheme = "preferred_color_scheme"
    static let enableHaptic = "enable_haptic"
    // Note: isCloudSyncEnabled and lastCloudSyncDate are device-specific, don't sync
  }

  // MARK: - Initialization
  private init() {
    setupObserver()
  }

  deinit {
    removeObserver()
  }

  // MARK: - Observer Setup
  private func setupObserver() {
    // Observe changes from other devices
    changeObserver = NotificationCenter.default.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: cloudStore,
      queue: .main
    ) { [weak self] notification in
      self?.handleExternalChange(notification)
    }

    // Start observing iCloud KVS
    cloudStore.synchronize()
  }

  private func removeObserver() {
    if let observer = changeObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  // MARK: - Handle External Changes
  private func handleExternalChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonForChange = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
      return
    }

    // Handle different change reasons
    switch reasonForChange {
    case NSUbiquitousKeyValueStoreServerChange,
         NSUbiquitousKeyValueStoreInitialSyncChange:
      // Pull changes from iCloud to local preferences
      pullFromCloud()

    case NSUbiquitousKeyValueStoreQuotaViolationChange:
      lastSyncError = "iCloud storage quota exceeded"

    case NSUbiquitousKeyValueStoreAccountChange:
      lastSyncError = "iCloud account changed"

    default:
      break
    }
  }

  // MARK: - Sync Operations

  /// Push local preferences to iCloud
  func pushToCloud() {
    isSyncing = true
    lastSyncError = nil

    // Sync view mode
    if let viewModeRaw = userPreferences.defaultViewMode.rawValue as String? {
      cloudStore.set(viewModeRaw, forKey: CloudKey.defaultViewMode)
    }

    // Sync color scheme
    if let scheme = userPreferences.preferredColorScheme {
      let schemeString = scheme == .light ? "light" : "dark"
      cloudStore.set(schemeString, forKey: CloudKey.preferredColorScheme)
    } else {
      cloudStore.removeObject(forKey: CloudKey.preferredColorScheme)
    }

    // Sync haptic preference
    cloudStore.set(userPreferences.enableHaptic, forKey: CloudKey.enableHaptic)

    // Force synchronize
    let success = cloudStore.synchronize()

    if !success {
      lastSyncError = "Failed to sync preferences to iCloud"
    }

    isSyncing = false
  }

  /// Pull preferences from iCloud to local
  func pullFromCloud() {
    isSyncing = true
    lastSyncError = nil

    // Sync view mode
    if let viewModeRaw = cloudStore.string(forKey: CloudKey.defaultViewMode),
       let viewMode = ViewMode(rawValue: viewModeRaw) {
      userPreferences.defaultViewMode = viewMode
    }

    // Sync color scheme
    if let schemeString = cloudStore.string(forKey: CloudKey.preferredColorScheme) {
      userPreferences.preferredColorScheme = schemeString == "light" ? .light : .dark
    } else if cloudStore.object(forKey: CloudKey.preferredColorScheme) == nil {
      // Key doesn't exist in cloud, keep local value or set to nil
      // This handles the case where preference was explicitly removed
    }

    // Sync haptic preference
    if cloudStore.object(forKey: CloudKey.enableHaptic) != nil {
      userPreferences.enableHaptic = cloudStore.bool(forKey: CloudKey.enableHaptic)
    }

    isSyncing = false
  }

  /// Perform a full two-way sync (push local changes, then pull any remote changes)
  func performFullSync() {
    pushToCloud()
    // Pull is automatically triggered by the change notification if there are remote changes
  }

  /// Reset cloud preferences (remove all from iCloud)
  func resetCloudPreferences() {
    cloudStore.removeObject(forKey: CloudKey.defaultViewMode)
    cloudStore.removeObject(forKey: CloudKey.preferredColorScheme)
    cloudStore.removeObject(forKey: CloudKey.enableHaptic)
    cloudStore.synchronize()
  }

  // MARK: - Initial Sync

  /// Call this when enabling iCloud sync for the first time
  func performInitialSync() {
    // First, try to pull from cloud (in case data exists from another device)
    cloudStore.synchronize()
    pullFromCloud()

    // Then push current local preferences to ensure they're backed up
    pushToCloud()
  }
}

// MARK: - Environment Extension
extension EnvironmentValues {
  @Entry var preferencesSyncManager: PreferencesSyncManager = PreferencesSyncManager.shared
}
