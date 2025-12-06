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

  deinit {
    removeSyncEventObserver()
    removeUbiquityIdentityObserver()
  }

  // MARK: - System Cloud Availability (iCloud Documents & Data)
  /// Check if iCloud Documents & Data is enabled at the system level
  /// This is separate from CloudKit account status
  private func checkSystemCloudAvailability() {
    // Get the current ubiquity identity token
    currentUbiquityToken = FileManager.default.ubiquityIdentityToken

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      // If token exists, iCloud Documents & Data is enabled
      let wasEnabled = self.isSystemCloudEnabled
      self.isSystemCloudEnabled = self.currentUbiquityToken != nil

      // If system cloud was disabled, sync our app preference
      if wasEnabled && !self.isSystemCloudEnabled {
        self.handleSystemCloudDisabled()
      }
    }
  }

  /// Monitor changes to iCloud Documents & Data availability
  private func setupUbiquityIdentityObserver() {
    ubiquityIdentityObserver = NotificationCenter.default.addObserver(
      forName: NSNotification.Name.NSUbiquityIdentityDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleUbiquityIdentityChange()
    }
  }

  private func removeUbiquityIdentityObserver() {
    if let observer = ubiquityIdentityObserver {
      NotificationCenter.default.removeObserver(observer)
      ubiquityIdentityObserver = nil
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
    print("📱 System iCloud Documents & Data was disabled in Settings")

    // If our app preference still thinks sync is enabled, disable it
    if userPreferences.isCloudSyncEnabled {
      print("📱 Auto-disabling app cloud sync preference to match system")
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
    print("📱 System iCloud Documents & Data was enabled in Settings")

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
      DispatchQueue.main.async {
        switch status {
        case .available:
          self?.isCloudAvailable = true
          // Only clear errors related to account status
          if self?.hasError == true && self?.errorMessage?.contains("iCloud account") == true {
            self?.hasError = false
            self?.errorMessage = nil
          }
        case .noAccount:
          self?.isCloudAvailable = false
          self?.hasError = true
          self?.errorMessage = "No iCloud account found. Please sign in to iCloud in Settings."
        case .restricted:
          self?.isCloudAvailable = false
          self?.hasError = true
          self?.errorMessage = "iCloud is restricted on this device."
        case .couldNotDetermine:
          self?.isCloudAvailable = false
          self?.hasError = true
          self?.errorMessage = "Unable to determine iCloud status."
        case .temporarilyUnavailable:
          self?.isCloudAvailable = false
          self?.hasError = true
          self?.errorMessage = "iCloud is temporarily unavailable."
        @unknown default:
          self?.isCloudAvailable = false
          self?.hasError = true
          self?.errorMessage = "Unknown iCloud status."
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
      self?.handleCloudKitEvent(notification)
    }
  }

  private func removeSyncEventObserver() {
    if let observer = syncEventObserver {
      NotificationCenter.default.removeObserver(observer)
      syncEventObserver = nil
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
  func enableSync() {
    guard isSystemCloudEnabled else {
      hasError = true
      errorMessage = "iCloud Documents & Data is disabled in Settings. Please enable it first."
      return
    }

    guard isCloudAvailable else {
      hasError = true
      errorMessage = "iCloud is not available. Please check your settings."
      return
    }

    guard networkMonitor.isConnected else {
      hasError = true
      errorMessage = "No internet connection. iCloud sync requires an active internet connection."
      return
    }

    userPreferences.isCloudSyncEnabled = true

    // Perform initial sync of preferences
    // Note: SwiftData sync happens automatically, we can't control it
    preferencesSyncManager.performInitialSync()

    // Indicate we're expecting sync activity
    isObservingSyncActivity = true
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
  var canSync: Bool {
    return isSystemCloudEnabled && isCloudAvailable && networkMonitor.isConnected && userPreferences.isCloudSyncEnabled
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
}

// MARK: - Environment Extension
extension EnvironmentValues {
  @Entry var cloudSyncManager: CloudSyncManager = CloudSyncManager.shared
}
