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
  @Environment(\.preferencesSyncManager) private var prefsSync
  @StateObject private var subscriptionManager = SubscriptionManager.shared
  @State private var showEnableAlert = false
  @State private var showDisableAlert = false
  @State private var showSystemSettingsAlert = false
  @State private var showPaywall = false

  var body: some View {
    List {
      // MARK: - Premium Feature Banner
      if !subscriptionManager.hasICloudSync {
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: "crown.fill")
                .foregroundStyle(.accent)
                .font(.title2)

              VStack(alignment: .leading, spacing: 4) {
                Text("iCloud Sync is available with Joodle Super. Upgrade to sync your doodles across all your devices.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }

            Button {
              showPaywall = true
            } label: {
              Text("Upgrade to Joodle Super")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
          }
          .padding(.vertical, 8)
        }
      }

      // MARK: - System vs App Toggle Warning
      if syncManager.needsSystemSettingsChange && subscriptionManager.hasICloudSync {
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.accent)
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
            .tint(.accent)
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
              // Check subscription first
              if !subscriptionManager.hasICloudSync {
                showPaywall = true
              } else if !syncManager.systemCloudEnabled {
                showSystemSettingsAlert = true
              } else {
                showEnableAlert = true
              }
            } else {
              showDisableAlert = true
            }
          }
        )) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("iCloud Sync")
                .font(.body)
            }

            if !subscriptionManager.hasICloudSync {
              Spacer()
              PremiumFeatureBadge()
            }
          }
        }
        .disabled(!subscriptionManager.hasICloudSync || !syncManager.systemCloudEnabled || !syncManager.isCloudAvailable || !networkMonitor.isConnected)
      } footer: {
        if syncManager.needsSystemSettingsChange {
          Text("Joodle can't sync with iCloud because \"Saved to iCloud\" is disabled in system settings.")
            .font(.caption)
            .foregroundStyle(.accent)
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
            Label("iCloud", systemImage: syncManager.isCloudAvailable ? "icloud" : "icloud.slash")
              .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
              if syncManager.isCloudAvailable {
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
            Label("Network", systemImage: networkMonitor.isConnected ? "wifi" : "wifi.slash")
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
            Label("Sync Status", systemImage: syncManager.canSync ? "arrow.trianglehead.2.clockwise.rotate.90" : "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
              .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
              if syncManager.canSync {
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
              Label("Last synced at", systemImage: "clock")
                .foregroundStyle(.primary)

              Spacer()

              Text(syncManager.syncActivityDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }


        // MARK: - Advanced
        Section {
          NavigationLink {
            SyncActivityDetailView()
          } label: {
            Label("Sync Activity Details", systemImage: "chart.line.uptrend.xyaxis").foregroundStyle(.primary)
          }

          NavigationLink {
            TroubleshootingView()
          } label: {
            Label("Troubleshooting Guide", systemImage: "wrench.and.screwdriver").foregroundStyle(.primary)
          }
        } header: {
          Text("Advanced")
        }
      }
    }
    .navigationTitle("Sync to iCloud")
    .sheet(isPresented: $showPaywall) {
      StandalonePaywallView()
    }
    .navigationBarTitleDisplayMode(.inline)
    .alert("Enable iCloud Sync", isPresented: $showEnableAlert) {
      Button("Cancel", role: .cancel) { }
      if #available(iOS 26.0, *) {
        Button("Enable", role: .confirm) {
          if syncManager.enableSync() {
            // Notify to recreate container
            NotificationCenter.default.post(name: NSNotification.Name("CloudSyncPreferenceChanged"), object: nil)
          }
        }
      } else {
        // Fallback on earlier versions
        Button("Enable") {
          if syncManager.enableSync() {
            // Notify to recreate container
            NotificationCenter.default.post(name: NSNotification.Name("CloudSyncPreferenceChanged"), object: nil)
          }
        }
      }
    } message: {
      Text("This will sync your journal entries and preferences with iCloud, making them available across all your devices.\n\nRequires internet connection and active iCloud account.")
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
        // Notify to recreate container
        NotificationCenter.default.post(name: NSNotification.Name("CloudSyncPreferenceChanged"), object: nil)
      }
    } message: {
      Text("Your data will remain on this device and in iCloud, but will stop syncing with other devices.")
    }
    .onAppear {
      syncManager.checkCloudAvailability()
    }
  }
}

// MARK: - Sync Activity Detail View
struct SyncActivityDetailView: View {
  @Environment(\.cloudSyncManager) private var syncManager

  var body: some View {
    List {
      Section("What Gets Synced") {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 8) {
            Image(systemName: "note.text")
              .foregroundStyle(.primary)
              .frame(width: 24)
            VStack(alignment: .leading) {
              Text("Journal Entries")
                .font(.body)
            }
          }

          HStack(spacing: 8) {
            Image(systemName: "gear")
              .foregroundStyle(.primary)
              .frame(width: 24)
            VStack(alignment: .leading) {
              Text("User Preferences")
                .font(.body)
            }
          }
        }
        .padding(.vertical, 4)
      }


      Section("Last sync activities") {
        if let lastImport = syncManager.lastObservedImport {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
              Text("Last download from iCloud")
                .font(.subheadline)
                .fontWeight(.semibold)
              Spacer()
            }

            Text(lastImport.formatted(date: .abbreviated, time: .standard))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        } else {
          HStack {
            Image(systemName: "arrow.down.circle")
              .foregroundStyle(.secondary)
            Text("No download events observed yet")
              .foregroundStyle(.secondary)
          }
        }

        if let lastExport = syncManager.lastObservedExport {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.green)
              Text("Last upload to iCloud")
                .font(.subheadline)
                .fontWeight(.semibold)
              Spacer()
            }

            Text(lastExport.formatted(date: .abbreviated, time: .standard))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        } else {
          HStack {
            Image(systemName: "arrow.up.circle")
              .foregroundStyle(.secondary)
            Text("No upload events observed yet")
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .navigationTitle("Sync Activity Details")
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct TroubleshootingView: View {
  @Environment(\.cloudSyncManager) private var syncManager
  @Environment(\.networkMonitor) private var networkMonitor

  @State private var isRefreshing = false
  @State private var showRefreshSuccess = false

  @State private var isResetting = false
  @State private var showResetSuccess = false

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
            title: "Toggle Sync Off/On",
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
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            } else {
              Image(systemName: "arrow.clockwise")
            }

            Text(isRefreshing ? "Checking..." : (showRefreshSuccess ? "Status Refreshed" : "Refresh iCloud Status"))
            Spacer()
          }
        }
        .disabled(isRefreshing || isResetting)

        Button {
          resetSyncState()
        } label: {
          HStack {
            if isResetting {
              ProgressView()
                .padding(.trailing, 4)
            } else if showResetSuccess {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            } else {
              Image(systemName: "arrow.counterclockwise")
            }

            Text(isResetting ? "Resetting..." : (showResetSuccess ? "State Reset" : "Reset Sync State"))
            Spacer()
          }
        }
        .disabled(isRefreshing || isResetting)
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

  private func resetSyncState() {
    isResetting = true

    // Simulate processing time
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      syncManager.reset()
      isResetting = false
      showResetSuccess = true

      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        withAnimation {
          showResetSuccess = false
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
        .foregroundStyle(.accent)
        .frame(width: 32, height: 32)
        .background(
          Circle()
            .fill(.accent.opacity(0.1))
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
