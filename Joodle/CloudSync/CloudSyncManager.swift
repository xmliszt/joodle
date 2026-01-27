//
//  CloudSyncManager.swift
//  Joodle
//
//  Created by AI Assistant
//

import CloudKit
import Combine
import CoreData
import Foundation
import Network
import Observation
import SwiftData
import SwiftUI

// MARK: - iCloud Sync State Persistence
/// Helper to persist sync state to iCloud KVS so it survives app deletion/reinstall
/// Uses consistent keys across the app:
/// - "is_cloud_sync_enabled_backup" (primary key)
/// - "cloud_sync_was_enabled" (secondary key for redundancy)
enum CloudSyncStatePersistence {
  private static let cloudStore = NSUbiquitousKeyValueStore.default
  // Use the same keys as JoodleApp and PreferencesSyncManager for consistency
  private static let primaryKey = "is_cloud_sync_enabled_backup"
  private static let secondaryKey = "cloud_sync_was_enabled"
  private static let lastSyncTimestampKey = "cloud_sync_enabled_timestamp"

  /// Check if iCloud previously had sync enabled (survives app reinstall)
  /// Checks both primary and secondary keys for redundancy
  static func wasCloudSyncPreviouslyEnabled() -> Bool {
    // Force a sync to get the latest values from iCloud
    cloudStore.synchronize()
    return cloudStore.bool(forKey: primaryKey) || cloudStore.bool(forKey: secondaryKey)
  }

  /// Check if there's any indication of previous sync activity
  static func hasPreviousSyncHistory() -> Bool {
    cloudStore.synchronize()
    // Check if we have a timestamp from previous sync
    return cloudStore.object(forKey: lastSyncTimestampKey) != nil
  }

  /// Get the timestamp of last sync activity
  static func getLastSyncTimestamp() -> Date? {
    cloudStore.synchronize()
    let timestamp = cloudStore.double(forKey: lastSyncTimestampKey)
    guard timestamp > 0 else { return nil }
    return Date(timeIntervalSince1970: timestamp)
  }

  /// Save sync enabled state to iCloud KVS (writes to both keys for redundancy)
  static func saveSyncEnabled(_ enabled: Bool) {
    cloudStore.set(enabled, forKey: primaryKey)
    cloudStore.set(enabled, forKey: secondaryKey)
    if enabled {
      cloudStore.set(Date().timeIntervalSince1970, forKey: lastSyncTimestampKey)
    }
    cloudStore.synchronize()
  }

  /// Check if this is a fresh install with existing iCloud data
  /// Returns true if iCloud says sync was enabled but local preference is off
  static func isReinstallWithCloudData() -> Bool {
    let localSyncEnabled = UserPreferences.shared.isCloudSyncEnabled
    let cloudSyncWasEnabled = wasCloudSyncPreviouslyEnabled()
    let hasUbiquityToken = FileManager.default.ubiquityIdentityToken != nil

    // Fresh install scenario: local says no, but iCloud says yes
    return !localSyncEnabled && cloudSyncWasEnabled && hasUbiquityToken
  }

  /// Restore sync state from iCloud to local preferences
  /// Call this BEFORE creating ModelContainer on fresh install
  static func restoreSyncStateIfNeeded() -> Bool {
    guard isReinstallWithCloudData() else { return false }

    // iCloud sync is free for all users - no subscription check needed

    print("CloudSyncStatePersistence: Detected reinstall with existing iCloud sync data")
    print("CloudSyncStatePersistence: Restoring sync state from iCloud")

    // Restore the local preference
    UserPreferences.shared.isCloudSyncEnabled = true

    return true
  }
}

@MainActor
@Observable
final class CloudSyncManager {
  // MARK: - Singleton
  static let shared = CloudSyncManager()

  // MARK: - Published State
  var hasError = false
  var errorMessage: String?
  var isCloudAvailable = false

  // System-level iCloud Documents & Data status
  var isSystemCloudEnabled = false

  // Observed sync events (best-effort detection, not guaranteed)
  var lastObservedImport: Date?
  var lastObservedExport: Date?
  var isObservingSyncActivity = false

  // Sync progress tracking for UI indication
  private var _isSyncing = false

  /// Whether sync is actively in progress
  var isSyncing: Bool {
    get { _isSyncing }
    set { _isSyncing = newValue }
  }
  var syncProgress: String = ""
  var isInitialSync = false  // True when syncing for the first time after reinstall
  var initialSyncImportCompleted = false  // True after first import completes during initial sync

  // Timeout for sync status (clear if no events received)
  private var syncTimeoutTask: Task<Void, Never>?
  private let syncTimeoutSeconds: Double = 30.0  // Clear sync indicator after 30 seconds of no activity

  // MARK: - Private Properties
  private let userPreferences = UserPreferences.shared
  private let networkMonitor = NetworkMonitor.shared
  private let preferencesSyncManager = PreferencesSyncManager.shared
  private var syncEventObserver: NSObjectProtocol?
  private var ubiquityIdentityObserver: NSObjectProtocol?

  // Track the ubiquity identity token to detect iCloud Documents & Data changes
  private var currentUbiquityToken: (any NSCoding & NSCopying & NSObjectProtocol)?

  // MARK: - Initialization
  private init() {
    checkSystemCloudAvailability()
    checkCloudAvailability()
    setupCloudKitEventObserver()
    setupUbiquityIdentityObserver()
  }

  // MARK: - System Cloud Availability (iCloud Documents & Data)
  /// Check if iCloud Documents & Data is enabled at the system level
  /// This is separate from CloudKit account status
  private func checkSystemCloudAvailability() {
    // Get the current ubiquity identity token
    currentUbiquityToken = FileManager.default.ubiquityIdentityToken

    // If token exists, iCloud Documents & Data is enabled
    let wasEnabled = self.isSystemCloudEnabled
    self.isSystemCloudEnabled = self.currentUbiquityToken != nil

    // If system cloud was disabled, sync our app preference
    if wasEnabled && !self.isSystemCloudEnabled {
      self.handleSystemCloudDisabled()
    }
  }

  /// Monitor changes to iCloud Documents & Data availability
  private func setupUbiquityIdentityObserver() {
    ubiquityIdentityObserver = NotificationCenter.default.addObserver(
      forName: NSNotification.Name.NSUbiquityIdentityDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.handleUbiquityIdentityChange()
      }
    }
  }

  private nonisolated func removeUbiquityIdentityObserver() {
    // Access observer in a thread-safe way
    MainActor.assumeIsolated {
      if let observer = ubiquityIdentityObserver {
        NotificationCenter.default.removeObserver(observer)
        ubiquityIdentityObserver = nil
      }
    }
  }

  /// Handle changes to ubiquity identity (iCloud Documents & Data toggle in Settings)
  private func handleUbiquityIdentityChange() {
    let newToken = FileManager.default.ubiquityIdentityToken
    let oldToken = currentUbiquityToken

    // Update our token
    currentUbiquityToken = newToken

    // Determine if it changed from enabled to disabled or vice versa
    let wasEnabled = oldToken != nil
    let isNowEnabled = newToken != nil

    isSystemCloudEnabled = isNowEnabled

    if wasEnabled && !isNowEnabled {
      // User disabled iCloud Documents & Data in iOS Settings
      handleSystemCloudDisabled()
    } else if !wasEnabled && isNowEnabled {
      // User enabled iCloud Documents & Data in iOS Settings
      handleSystemCloudEnabled()
    }
  }

  /// Called when system-level iCloud Documents & Data is disabled
  private func handleSystemCloudDisabled() {
    // If our app preference still thinks sync is enabled, disable it
    if userPreferences.isCloudSyncEnabled {
      userPreferences.isCloudSyncEnabled = false

      // Update UI state - restart will be needed
      hasError = true
      errorMessage = "iCloud was disabled in Settings. Please restart the app."
    }
  }

  /// Called when system-level iCloud Documents & Data is enabled
  private func handleSystemCloudEnabled() {
    // Don't automatically enable app sync - let user choose
    // Just clear any error messages
    if errorMessage == "iCloud was disabled in Settings. Switched to local storage." {
      hasError = false
      errorMessage = nil
    }
  }

  // MARK: - Cloud Availability (CloudKit Account Status)
  func checkCloudAvailability() {
    CKContainer.default().accountStatus { [weak self] status, error in
      Task { @MainActor in
        guard let self = self else { return }
        switch status {
        case .available:
          self.isCloudAvailable = true
          // Only clear errors related to account status
          if self.hasError == true && self.errorMessage?.contains("iCloud account") == true {
            self.hasError = false
            self.errorMessage = nil
          }
        case .noAccount:
          self.isCloudAvailable = false
          self.hasError = true
          self.errorMessage = "No iCloud account found. Please sign in to iCloud in Settings."
        case .restricted:
          self.isCloudAvailable = false
          self.hasError = true
          self.errorMessage = "iCloud is restricted on this device."
        case .couldNotDetermine:
          self.isCloudAvailable = false
          self.hasError = true
          self.errorMessage = "Unable to determine iCloud status."
        case .temporarilyUnavailable:
          self.isCloudAvailable = false
          self.hasError = true
          self.errorMessage = "iCloud is temporarily unavailable."
        @unknown default:
          self.isCloudAvailable = false
          self.hasError = true
          self.errorMessage = "Unknown iCloud status."
        }
      }
    }
  }

  // MARK: - CloudKit Event Observation
  private func setupCloudKitEventObserver() {
    // Observe NSPersistentCloudKitContainer events
    // Note: SwiftData uses CoreData/NSPersistentCloudKitContainer under the hood
    // This is best-effort detection - not officially documented for SwiftData
    syncEventObserver = NotificationCenter.default.addObserver(
      forName: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      Task { @MainActor in
        self?.handleCloudKitEvent(notification)
      }
    }
  }

  private nonisolated func removeSyncEventObserver() {
    MainActor.assumeIsolated {
      if let observer = syncEventObserver {
        NotificationCenter.default.removeObserver(observer)
        syncEventObserver = nil
      }
    }
  }

  private func handleCloudKitEvent(_ notification: Notification) {
    // Only process if sync is enabled
    guard userPreferences.isCloudSyncEnabled else { return }

    // Extract the event from notification
    guard let userInfo = notification.userInfo,
          let event = userInfo["event"] as? NSPersistentCloudKitContainer.Event else {
      return
    }

    // Track in-progress events
    if event.endDate == nil {
      // Event is in progress
      isSyncing = true
      switch event.type {
      case .import:
        syncProgress = isInitialSync ? "Restoring data from iCloud..." : "Downloading from iCloud..."
      case .export:
        syncProgress = "Uploading to iCloud..."
      case .setup:
        syncProgress = "Setting up iCloud sync..."
      @unknown default:
        syncProgress = "Syncing..."
      }
      // Reset timeout when we receive an in-progress event
      resetSyncTimeout()
      return
    }

    // Update our observed sync times based on event type
    switch event.type {
    case .import:
      // Data came down from CloudKit
      lastObservedImport = event.endDate
      isObservingSyncActivity = false
      isSyncing = false
      syncProgress = "Import complete"

      // Handle initial sync completion
      if isInitialSync {
        initialSyncImportCompleted = true
        syncProgress = "Data restored from iCloud"
        isInitialSync = false
      }

    case .export:
      // Data went up to CloudKit
      lastObservedExport = event.endDate
      isObservingSyncActivity = false
      isSyncing = false
      syncProgress = "Export complete"

    case .setup:
      // Initial CloudKit setup
      isObservingSyncActivity = false
      isSyncing = false
      syncProgress = "Setup complete"

    @unknown default:
      break
    }
  }

  // MARK: - Enable/Disable Sync
  func enableSync() -> Bool {
    // Check system requirements (subscription is no longer needed)
    guard isSystemCloudEnabled else {
      hasError = true
      errorMessage = "iCloud is disabled in Settings. Enable it in 'Settings → [Your Name] → iCloud → Saved to iCloud → Joodle'."
      return false
    }

    guard isCloudAvailable else {
      hasError = true
      errorMessage = "iCloud is not available. Please check your settings."
      return false
    }

    guard networkMonitor.isConnected else {
      hasError = true
      errorMessage = "No internet connection. iCloud sync requires an active internet connection."
      return false
    }

    userPreferences.isCloudSyncEnabled = true

    // Persist sync state to iCloud KVS (survives app reinstall)
    CloudSyncStatePersistence.saveSyncEnabled(true)
    preferencesSyncManager.saveSyncEnabledToCloud()

    // Note: SwiftData sync happens automatically for journal entries
    // User preferences are intentionally NOT synced - they are device-specific

    // Check if container was created with different sync state
    // CloudKit can only have ONE active sync handler per store
    if ModelContainerManager.shared.needsRestartForSyncChange {
      // Container needs restart but preference is saved
      hasError = false
      errorMessage = nil
      return true
    }

    // Indicate we're expecting sync activity
    isObservingSyncActivity = true
    isSyncing = true
    syncProgress = "Starting sync..."
    return true
  }

  /// Check if user can enable sync (system requirements met)
  var canEnableSync: Bool {
    return isSystemCloudEnabled &&
           isCloudAvailable &&
           networkMonitor.isConnected
  }

  /// Reason why sync cannot be enabled (for UI display)
  var syncBlockedReason: String? {
    if !isSystemCloudEnabled {
      return "iCloud disabled in Settings"
    }
    if !isCloudAvailable {
      return "No iCloud account"
    }
    if !networkMonitor.isConnected {
      return "No internet connection"
    }
    return nil
  }

  func disableSync() {
    userPreferences.isCloudSyncEnabled = false

    // Persist sync state to iCloud KVS (so reinstall knows sync is disabled)
    CloudSyncStatePersistence.saveSyncEnabled(false)
    preferencesSyncManager.clearSyncEnabledFromCloud()

    // Reset sync status
    isSyncing = false
    syncProgress = ""
    isInitialSync = false

    // Note: We don't remove data from iCloud when disabling,
    // just stop syncing. Data remains in cloud if user re-enables.
  }



  /// Reset the sync timeout timer - called when sync activity is detected
  private func resetSyncTimeout() {
    // Cancel existing timeout
    syncTimeoutTask?.cancel()

    // Start new timeout
    syncTimeoutTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(syncTimeoutSeconds))

      // If we're still marked as syncing after timeout, clear it
      // This handles cases where we miss the completion event
      if !Task.isCancelled && isSyncing {
        isSyncing = false
        isInitialSync = false
        syncProgress = ""
        print("CloudSyncManager: Sync timeout - clearing sync indicator")
      }
    }
  }

  /// Clear the sync status immediately (e.g., when user navigates away)
  func clearSyncStatus() {
    syncTimeoutTask?.cancel()
    isSyncing = false
    syncProgress = ""
    // Don't clear isInitialSync here - it should persist until actual sync completes
  }

  // MARK: - Reset
  func reset() {
    hasError = false
    errorMessage = nil
  }

  // MARK: - Computed Properties

  /// App-level preference (controlled by the app)
  var appCloudEnabled: Bool {
    return userPreferences.isCloudSyncEnabled
  }

  /// System-level iCloud Documents & Data status (controlled by iOS Settings)
  var systemCloudEnabled: Bool {
    return isSystemCloudEnabled
  }

  /// Whether the toggles are out of sync (app wants cloud but system has it disabled)
  var needsSystemSettingsChange: Bool {
    return appCloudEnabled && !systemCloudEnabled
  }

  var canSync: Bool {
    return isSystemCloudEnabled &&
           isCloudAvailable &&
           networkMonitor.isConnected &&
           userPreferences.isCloudSyncEnabled
  }

  var statusMessage: String {
    if !isSystemCloudEnabled {
      return "iCloud Documents disabled in Settings"
    } else if !isCloudAvailable {
      return "iCloud not available"
    } else if !networkMonitor.isConnected {
      return "No internet connection"
    } else if userPreferences.isCloudSyncEnabled {
      return "Sync enabled"
    } else {
      return "Sync disabled"
    }
  }

  /// Detailed sync status message for UI display
  var syncStatusMessage: String {
    if needsSystemSettingsChange {
      return "iCloud is disabled in iOS Settings. Enable it in \"Settings → [Your Name] → iCloud → Saved to iCloud -> Joodle\" to sync."
    } else if systemCloudEnabled && !appCloudEnabled {
      return "Sync is disabled in app. Enable it to sync with iCloud."
    } else if systemCloudEnabled && appCloudEnabled && isCloudAvailable && networkMonitor.isConnected {
      return "Sync to iCloud is enabled"
    } else if !isCloudAvailable {
      return "No iCloud available. Sign in to iCloud in Settings."
    } else if !networkMonitor.isConnected {
      return "No internet connection"
    } else {
      return "Sync disabled"
    }
  }

  // Most recent observed sync event (import or export)
  var lastObservedSync: Date? {
    guard let importDate = lastObservedImport,
          let exportDate = lastObservedExport else {
      return lastObservedImport ?? lastObservedExport
    }
    return max(importDate, exportDate)
  }

  var syncActivityDescription: String {
    if isSyncing {
      return syncProgress.isEmpty ? "Syncing..." : syncProgress
    } else if isObservingSyncActivity {
      return "Sync may be in progress"
    } else if let lastSync = lastObservedSync {
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .abbreviated
      return "Last observed: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
    } else {
      return "No sync observed yet"
    }
  }

  // MARK: - System Settings

  /// Opens iOS Settings app
  func openSystemSettings() {
    if let url = URL(string: "App-prefs:") {
      Task { @MainActor in
        await UIApplication.shared.open(url)
      }
    }
  }

  // MARK: - Cleanup

  func cleanup() {
    if let observer = syncEventObserver {
      NotificationCenter.default.removeObserver(observer)
      syncEventObserver = nil
    }
    if let observer = ubiquityIdentityObserver {
      NotificationCenter.default.removeObserver(observer)
      ubiquityIdentityObserver = nil
    }
  }
}

// MARK: - Environment Extension
extension EnvironmentValues {
  @Entry var cloudSyncManager: CloudSyncManager = MainActor.assumeIsolated { CloudSyncManager.shared }
}
