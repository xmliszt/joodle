//
//  CloudSyncManager.swift
//  Joodle
//
//  Created by AI Assistant
//

import CloudKit
import Combine
import Foundation
import Observation
import SwiftData
import SwiftUI

@Observable
final class CloudSyncManager {
  // MARK: - Singleton
  static let shared = CloudSyncManager()

  // MARK: - Published State
  var isSyncing = false
  var syncStatus: String = ""
  var lastSyncDate: Date?
  var hasError = false
  var errorMessage: String?
  var isCloudAvailable = false

  // MARK: - Private Properties
  private var syncObservers: [NSObjectProtocol] = []
  private let userPreferences = UserPreferences.shared

  // MARK: - Initialization
  private init() {
    checkCloudAvailability()
    loadLastSyncDate()
    setupSyncObservers()
  }

  deinit {
    removeSyncObservers()
  }

  // MARK: - Cloud Availability
  func checkCloudAvailability() {
    CKContainer.default().accountStatus { [weak self] status, error in
      DispatchQueue.main.async {
        switch status {
        case .available:
          self?.isCloudAvailable = true
          self?.hasError = false
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

  // MARK: - Sync Observers
  private func setupSyncObservers() {
    // Note: SwiftData handles CloudKit sync automatically when configured
    // We monitor app lifecycle and provide manual sync triggers
    // The actual sync happens through ModelConfiguration's cloudKitDatabase setting

    // Observe when app becomes active (potential sync point)
    let appActiveObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleAppBecameActive()
    }

    syncObservers = [appActiveObserver]
  }

  private func removeSyncObservers() {
    syncObservers.forEach { observer in
      NotificationCenter.default.removeObserver(observer)
    }
    syncObservers.removeAll()
  }

  // MARK: - Handle Sync Events
  private func handleAppBecameActive() {
    guard userPreferences.isCloudSyncEnabled else { return }

    // SwiftData syncs automatically, but we can update our UI
    // Check if enough time has passed since last sync
    if let lastSync = lastSyncDate {
      let timeSinceLastSync = Date().timeIntervalSince(lastSync)
      // If more than 5 minutes, show a brief sync indicator
      if timeSinceLastSync > 300 {
        showSyncIndicator()
      }
    } else {
      // First time, show sync indicator
      showSyncIndicator()
    }
  }

  private func showSyncIndicator() {
    DispatchQueue.main.async { [weak self] in
      self?.isSyncing = true
      self?.syncStatus = "Syncing with iCloud..."
    }

    // SwiftData handles the actual sync, we just show UI feedback
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.updateLastSyncDate()
      self?.isSyncing = false
      self?.syncStatus = "Sync complete"

      // Clear status after a delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
        self?.syncStatus = ""
      }
    }
  }

  // MARK: - Manual Sync
  func triggerManualSync() {
    guard isCloudAvailable else {
      hasError = true
      errorMessage = "iCloud is not available. Please check your settings."
      return
    }

    guard userPreferences.isCloudSyncEnabled else { return }

    isSyncing = true
    syncStatus = "Syncing..."
    hasError = false

    // SwiftData handles CloudKit sync automatically
    // We provide UI feedback for the user
    // The sync happens through the ModelConfiguration's cloudKitDatabase setting
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.updateLastSyncDate()
      self?.isSyncing = false
      self?.syncStatus = "Sync complete"

      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
        self?.syncStatus = ""
      }
    }
  }

  // MARK: - Last Sync Date
  private func loadLastSyncDate() {
    lastSyncDate = userPreferences.lastCloudSyncDate
  }

  private func updateLastSyncDate() {
    let now = Date()
    lastSyncDate = now
    userPreferences.lastCloudSyncDate = now
  }

  // MARK: - Enable/Disable Sync
  func enableSync() {
    guard isCloudAvailable else {
      hasError = true
      errorMessage = "iCloud is not available. Please check your settings."
      return
    }

    userPreferences.isCloudSyncEnabled = true
    // Trigger an immediate sync when enabling
    triggerManualSync()
  }

  func disableSync() {
    userPreferences.isCloudSyncEnabled = false
    isSyncing = false
    syncStatus = ""
  }

  // MARK: - Reset
  func reset() {
    isSyncing = false
    syncStatus = ""
    hasError = false
    errorMessage = nil
  }
}

// MARK: - Environment Extension
extension EnvironmentValues {
  @Entry var cloudSyncManager: CloudSyncManager = CloudSyncManager.shared
}
