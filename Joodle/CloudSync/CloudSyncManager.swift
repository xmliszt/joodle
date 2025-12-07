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

      // Notify the app to recreate the ModelContainer
      NotificationCenter.default.post(
        name: NSNotification.Name("CloudSyncPreferenceChanged"),
        object: nil
      )

      // Update UI state
      hasError = true
      errorMessage = "iCloud was disabled in Settings. Switched to local storage."
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

    // Only track completed events
    guard event.endDate != nil else {
      return
    }

    // Update our observed sync times based on event type
    switch event.type {
    case .import:
      // Data came down from CloudKit
      lastObservedImport = event.endDate
      isObservingSyncActivity = false

    case .export:
      // Data went up to CloudKit
      lastObservedExport = event.endDate
      isObservingSyncActivity = false

    case .setup:
      // Initial CloudKit setup
      isObservingSyncActivity = false

    @unknown default:
      break
    }
  }

  // MARK: - Enable/Disable Sync
  func enableSync() -> Bool {
    // Check subscription first
    guard SubscriptionManager.shared.hasICloudSync else {
      hasError = true
      errorMessage = "iCloud Sync requires Joodle Super subscription."
      return false
    }

    guard isSystemCloudEnabled else {
      hasError = true
      errorMessage = "iCloud Documents & Data is disabled in Settings. Please enable it first."
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

    // Perform initial sync of preferences
    // Note: SwiftData sync happens automatically, we can't control it
    preferencesSyncManager.performInitialSync()

    // Indicate we're expecting sync activity
    isObservingSyncActivity = true
    return true
  }

  /// Check if user can enable sync (has subscription and system requirements met)
  var canEnableSync: Bool {
    return SubscriptionManager.shared.hasICloudSync &&
           isSystemCloudEnabled &&
           isCloudAvailable &&
           networkMonitor.isConnected
  }

  /// Reason why sync cannot be enabled (for UI display)
  var syncBlockedReason: String? {
    if !SubscriptionManager.shared.hasICloudSync {
      return "Requires Joodle Super"
    }
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

    // Note: We don't remove data from iCloud when disabling,
    // just stop syncing. Data remains in cloud if user re-enables.
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
    return SubscriptionManager.shared.hasICloudSync &&
           isSystemCloudEnabled &&
           isCloudAvailable &&
           networkMonitor.isConnected &&
           userPreferences.isCloudSyncEnabled
  }

  var statusMessage: String {
    if !SubscriptionManager.shared.hasICloudSync {
      return "Requires Joodle Super"
    } else if !isSystemCloudEnabled {
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
    if !SubscriptionManager.shared.hasICloudSync {
      return "iCloud Sync is a Joodle Super feature. Upgrade to sync your doodles across devices."
    } else if needsSystemSettingsChange {
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
    if isObservingSyncActivity {
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
