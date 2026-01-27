//
//  iCloudSyncView.swift
//  Joodle
//
//  Created by AI Assistant
//

import SwiftUI

struct iCloudSyncView: View {
  @Environment(\.userPreferences) private var userPreferences
  @Environment(\.cloudSyncManager) private var syncManager
  @Environment(\.networkMonitor) private var networkMonitor
  @StateObject private var subscriptionManager = SubscriptionManager.shared
  @State private var showEnableAlert = false
  @State private var showEnableWithRestartAlert = false
  @State private var showDisableAlert = false
  @State private var showSystemSettingsAlert = false

  /// Check if restart is needed for sync to work
  /// This happens when user enabled sync during onboarding but chose "Later" for restart
  private var needsRestartForSync: Bool {
    userPreferences.isCloudSyncEnabled && ModelContainerManager.shared.needsRestartForSyncChange
  }

  var body: some View {
    List {
      // MARK: - Restart Required Banner
      if needsRestartForSync {
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundStyle(.appAccentContrast)
                .font(.title2)

              VStack(alignment: .leading, spacing: 4) {
                Text("Restart Required")
                  .font(.headline)
                  .foregroundStyle(.appAccentContrast)

                Text("iCloud Sync is enabled but requires a restart to start working. Your data will sync after you restart the app.")
                  .font(.caption)
                  .foregroundStyle(.appAccentContrast.opacity(0.9))
                  .fixedSize(horizontal: false, vertical: true)
              }
            }

            Button {
              // Close the app to trigger restart
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exit(0)
              }
            } label: {
              Text("Restart Now")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.appAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 32))
            }
          }
          .padding(.vertical, 8)
          .listRowBackground(Color.appAccent)
        }
      }

      // MARK: - System vs App Toggle Warning
      if syncManager.needsSystemSettingsChange {
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.appAccent)
                .font(.title2)

              VStack(alignment: .leading, spacing: 4) {
                Text("iCloud Disabled in System Settings")
                  .font(.headline)
                  .foregroundStyle(.primary)

                Text("To enable sync, you must enable \"Saved to iCloud\" for Joodle in iCloud Settings: Settings → [Your Name] → iCloud → Saved to iCloud → Joodle. ")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }

            Button {
              showSystemSettingsAlert = true
            } label: {
              HStack {
                Image(systemName: "gear")
                Text("Open Settings")
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)
          }
          .padding(.vertical, 8)
        }
      }

      // MARK: - Main Toggle Section
      Section {
        Toggle(isOn: Binding(
          get: { userPreferences.isCloudSyncEnabled },
          set: { newValue in
            if newValue {
              // No subscription verification needed - iCloud Sync is always available (built-in iOS capability)
              if !syncManager.systemCloudEnabled {
                showSystemSettingsAlert = true
              } else if ModelContainerManager.shared.needsRestartForSyncChange {
                // Restart is required - show special alert
                showEnableWithRestartAlert = true
                // Track iCloud sync enabled
                AnalyticsManager.shared.trackICloudSyncEnabled()
              } else {
                showEnableAlert = true
                // Track iCloud sync enabled
                AnalyticsManager.shared.trackICloudSyncEnabled()
              }
            } else {
              // No restart needed to disable - sync just stops on next app launch
              // The CloudKit container stays active but we save the preference
              showDisableAlert = true
              // Track iCloud sync disabled
              AnalyticsManager.shared.trackICloudSyncDisabled()
            }
          }
        )) {
          HStack {
            SettingsIconView(systemName: "icloud.fill", backgroundColor: .cyan)
            Text("iCloud Sync")
              .font(.body)
          }
        }
        .disabled(!syncManager.systemCloudEnabled || !syncManager.isCloudAvailable || !networkMonitor.isConnected)
      } footer: {
        if syncManager.needsSystemSettingsChange {
          Text("Joodle can't sync with iCloud because \"Saved to iCloud\" is disabled in system settings.")
            .font(.caption)
            .foregroundStyle(.appAccent)
        } else if !syncManager.systemCloudEnabled {
          Text("\"Saved to iCloud\" is disabled. Enable it in Settings → [Your Name] → iCloud → Saved to iCloud → Joodle.")
            .font(.caption)
            .foregroundStyle(.red)
        } else if !syncManager.isCloudAvailable {
          Text("No iCloud account found. Please sign in to iCloud in Settings.")
            .font(.caption)
            .foregroundStyle(.red)
        } else if !networkMonitor.isConnected {
          Text("Connect to the internet to enable iCloud sync.")
            .font(.caption)
            .foregroundStyle(.red)
        } else if userPreferences.isCloudSyncEnabled {
          Text("Joodle will automatically sync your journal entries and preferences to iCloud.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("When enabled, Joodle automatically syncs your journal entries and preferences to iCloud.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      // MARK: Status section
      if userPreferences.isCloudSyncEnabled {
        Section {
          // iCloud Status
          HStack {
            SettingsIconView(systemName: needsRestartForSync ? "icloud.slash" : (syncManager.isCloudAvailable ? "icloud.fill" : "icloud.slash"), backgroundColor: .cyan)
            Text("iCloud Account")
              .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
              if needsRestartForSync {
                Text("Restart Required")
                  .foregroundStyle(.orange)
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.orange)
              } else if syncManager.isCloudAvailable {
                Text("Available")
                  .foregroundStyle(.secondary)
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(.green)
              } else {
                Text("Not Available")
                  .foregroundStyle(.secondary)
                Image(systemName: "xmark.circle.fill")
                  .foregroundStyle(.red)
              }
            }
          }

          // Network Status
          HStack {
            SettingsIconView(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash", backgroundColor: .blue)
            Text("Network")
              .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
              Text(networkMonitor.connectionDescription)
                .foregroundStyle(.secondary)
              Image(systemName: networkMonitor.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(networkMonitor.isConnected ? .green : .red)
            }
          }

          // Sync Status
          HStack {
            SettingsIconView(systemName: syncManager.canSync ? "arrow.triangle.2.circlepath" : "exclamationmark.arrow.triangle.2.circlepath", backgroundColor: .green)
            Text("Sync Status")
              .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
              if syncManager.isSyncing {
                Text("Syncing")
                  .foregroundStyle(.secondary)
                ProgressView()
                  .scaleEffect(0.7)
              } else if syncManager.canSync {
                Text("Active")
                  .foregroundStyle(.secondary)
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(.green)
              } else {
                Text("Inactive")
                  .foregroundStyle(.secondary)
                Image(systemName: "pause.circle.fill")
                  .foregroundStyle(.red)
              }
            }
          }
        } header: {
          Text("Status")
        }

        // MARK: - Observed Sync Activity
        if userPreferences.isCloudSyncEnabled {
          Section {
            HStack {
              SettingsIconView(systemName: "clock.fill", backgroundColor: .orange)
              Text("Last synced at")
                .foregroundStyle(.primary)

              Spacer()

              if syncManager.isSyncing {
                HStack(spacing: 6) {
                  Text("Syncing now")
                    .font(.caption)
                    .foregroundStyle(.appAccent)
                  ProgressView()
                    .scaleEffect(0.6)
                }
              } else {
                Text(syncManager.syncActivityDescription)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }


        // MARK: - Advanced
        Section {
          NavigationLink {
            TroubleshootingView()
          } label: {
            HStack {
              SettingsIconView(systemName: "wrench.and.screwdriver", backgroundColor: .gray)
              Text("Troubleshooting Guide").foregroundStyle(.primary)
            }
          }
        }
      }
    }
    .navigationTitle("Sync to iCloud")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Enable iCloud Sync", isPresented: $showEnableAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Enable") {
        _ = syncManager.enableSync()
      }
    } message: {
      Text("This will sync your journal entries and preferences with iCloud, making them available across all your devices.\n\nRequires internet connection and active iCloud account.")
    }
    .alert("Enable iCloud Sync", isPresented: $showEnableWithRestartAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Enable & Restart Joodle") {
        _ = syncManager.enableSync()
        // Auto-close the app after a short delay to allow preference to save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          exit(0)
        }
      }
    } message: {
      Text("To enable iCloud sync, Joodle needs to close and restart.\n\nYour data is safe and will sync to iCloud when you reopen the app.")
    }
    .alert("How to enable iCloud Sync for Joodle?", isPresented: $showSystemSettingsAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Open Settings") {
        syncManager.openSystemSettings()
      }
    } message: {
      Text("\"Saved to iCloud\" is disabled in system settings. To enable sync, go to:\n\nSettings → [Your Name] → iCloud → Saved to iCloud → Joodle\n\nand turn on the toggle.")
    }
    .alert("Disable iCloud Sync", isPresented: $showDisableAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Disable", role: .destructive) {
        userPreferences.isCloudSyncEnabled = false
        syncManager.disableSync()
      }
    } message: {
      Text("Your data will remain on this device and in iCloud, but will stop syncing with other devices.")
    }
    .onAppear {
      syncManager.checkCloudAvailability()
      // Clear the pending restart flag since user can see the banner here
      UserDefaults.standard.removeObject(forKey: "pending_icloud_sync_restart")
    }
    .postHogScreenView("iCloud Sync")
  }
}

struct TroubleshootingView: View {
  @Environment(\.cloudSyncManager) private var syncManager
  @Environment(\.networkMonitor) private var networkMonitor

  @State private var isRefreshing = false
  @State private var showRefreshSuccess = false

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 16) {
          TroubleshootingStep(
            number: "1",
            title: "Enable System iCloud for Joodle",
            description: "Go to Settings → [Your Name] → iCloud → Apps Using iCloud → Joodle and turn ON the toggle. This is required for sync to work."
          )

          TroubleshootingStep(
            number: "2",
            title: "Check iCloud Account",
            description: "Go to Settings → [Your Name] and ensure you're signed in to iCloud."
          )

          TroubleshootingStep(
            number: "3",
            title: "Verify Internet Connection",
            description: "Make sure you have an active internet connection (Wi-Fi or cellular data). Current status: \(networkMonitor.connectionDescription)"
          )

          TroubleshootingStep(
            number: "4",
            title: "Check iCloud Storage",
            description: "Ensure you have available iCloud storage space. Go to Settings → [Your Name] → iCloud → Manage Storage."
          )

          TroubleshootingStep(
            number: "5",
            title: "Restart the App",
            description: "Close the app completely and reopen it to refresh the sync connection."
          )

          TroubleshootingStep(
            number: "6",
            title: "Toggle Sync Off / On",
            description: "Try disabling iCloud sync, waiting 10 seconds, then re-enabling it. This recreates the sync connection."
          )
        }
        .padding(.bottom, 8)
      }

      Section {
        Button {
          syncManager.openSystemSettings()
        } label: {
          HStack {
            Image(systemName: "gear")
            Text("Open iOS Settings")
            Spacer()
            Image(systemName: "arrow.up.right")
              .font(.caption)
          }
        }

        Button {
          refreshStatus()
        } label: {
          HStack {
            if isRefreshing {
              ProgressView()
                .padding(.trailing, 4)
            } else if showRefreshSuccess {
              if syncManager.isCloudAvailable {
                Image(systemName: "checkmark.icloud.fill")
                  .foregroundStyle(.green)
              } else {
                Image(systemName: "xmark.icloud.fill")
                  .foregroundStyle(.red)
              }
            } else {
              Image(systemName: "arrow.trianglehead.clockwise.icloud.fill")
            }

            Text(isRefreshing ? "Checking..." : (showRefreshSuccess ? syncManager.isCloudAvailable ? "iCloud is Available" : "iCloud Unavailable" : "Refresh iCloud Availability"))
            Spacer()
          }
        }
        .disabled(isRefreshing)
      } header: {
        Text("Manual Actions")
      }
    }
    .navigationTitle("Troubleshooting Guide")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func refreshStatus() {
    isRefreshing = true

    // Simulate a brief delay for UX so the user sees the loading state
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      syncManager.checkCloudAvailability()
      isRefreshing = false
      showRefreshSuccess = true

      // Reset success state after a delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        withAnimation {
          showRefreshSuccess = false
        }
      }
    }
  }
}

// MARK: - Helper View
struct TroubleshootingStep: View {
  let number: String
  let title: String
  let description: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Text(number)
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundStyle(.appAccent)
        .frame(width: 32, height: 32)
        .background(
          Circle()
            .fill(.appAccent.opacity(0.1))
        )

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
