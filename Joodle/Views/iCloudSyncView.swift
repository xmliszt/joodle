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
  @State private var showEnableAlert = false
  @State private var showDisableAlert = false

  var body: some View {
    List {
      // MARK: - Main Toggle Section
      Section {
        Toggle(isOn: Binding(
          get: { userPreferences.isCloudSyncEnabled },
          set: { newValue in
            if newValue {
              showEnableAlert = true
            } else {
              showDisableAlert = true
            }
          }
        )) {
          VStack(alignment: .leading, spacing: 4) {
            Text("iCloud Sync")
              .font(.body)

            if !syncManager.isCloudAvailable {
              Text("iCloud not available")
                .font(.caption)
                .foregroundStyle(.red)
            } else if !networkMonitor.isConnected {
              Text("No internet connection")
                .font(.caption)
                .foregroundStyle(.orange)
            }
          }
        }
        .disabled(!syncManager.isCloudAvailable || !networkMonitor.isConnected)
      } footer: {
        if !syncManager.isCloudAvailable {
          Text("Please sign in to iCloud in Settings to enable sync.")
            .font(.caption)
            .foregroundStyle(.red)
        } else if !networkMonitor.isConnected {
          Text("Connect to the internet to enable iCloud sync.")
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
          Text("When enabled, SwiftData automatically syncs your journal entries to iCloud in the background. Your preferences are synced using iCloud Key-Value Store.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      // MARK: - Status Section
      if userPreferences.isCloudSyncEnabled {
        Section {
          // iCloud Account Status
          HStack {
            Label("iCloud Account", systemImage: "icloud")
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
            Label("Sync Status", systemImage: "arrow.triangle.2.circlepath")
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
                  .foregroundStyle(.orange)
              }
            }
          }
        } header: {
          Text("Status")
        } footer: {
          if syncManager.canSync {
            Text("iCloud sync is active. SwiftData automatically syncs your journal entries in the background when changes occur.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if !networkMonitor.isConnected {
            Text("Sync paused - no internet connection. Sync will resume automatically when you're back online.")
              .font(.caption)
              .foregroundStyle(.orange)
          } else {
            Text("Sync is currently inactive. Check the status above for details.")
              .font(.caption)
              .foregroundStyle(.orange)
          }
        }

        // MARK: - Observed Sync Activity
        if userPreferences.isCloudSyncEnabled {
          Section {
            HStack {
              Label("Sync Activity", systemImage: "clock")
                .foregroundStyle(.primary)

              Spacer()

              Text(syncManager.syncActivityDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          } footer: {
            Text("Note: We observe CloudKit sync events but cannot control when they occur. Times shown are when we detected sync activity, not guaranteed complete sync timestamps.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        // MARK: - What Gets Synced
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
              Image(systemName: "note.text")
                .foregroundStyle(.blue)
                .frame(width: 24)
              VStack(alignment: .leading, spacing: 2) {
                Text("Journal Entries")
                  .font(.body)
                Text("All your daily journal entries and drawings")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }

            HStack(spacing: 8) {
              Image(systemName: "gear")
                .foregroundStyle(.blue)
                .frame(width: 24)
              VStack(alignment: .leading, spacing: 2) {
                Text("Preferences")
                  .font(.body)
                Text("View mode, color scheme, and haptic feedback")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
          .padding(.vertical, 4)
        } header: {
          Text("What Gets Synced")
        } footer: {
          Text("Journal entries sync automatically via SwiftData. Preferences sync via iCloud Key-Value Store.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        // MARK: - Preferences Sync Actions
        Section {
          Button {
            prefsSync.performFullSync()
          } label: {
            HStack {
              Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)

              Text("Sync Preferences Now")
                .foregroundStyle(.primary)

              Spacer()

              if prefsSync.isSyncing {
                ProgressView()
                  .scaleEffect(0.8)
              }
            }
          }
          .disabled(!syncManager.canSync || prefsSync.isSyncing)

          if let error = prefsSync.lastSyncError {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
              Text(error)
                .font(.caption)
                .foregroundStyle(.orange)
            }
          }
        } header: {
          Text("Preferences Sync")
        } footer: {
          Text("Note: Journal entries sync automatically via SwiftData - we cannot manually trigger their sync. The button above only syncs your app preferences. We can observe when CloudKit sync events occur, but not control them.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        // MARK: - How It Works
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "1.circle.fill")
                .foregroundStyle(.blue)
              VStack(alignment: .leading, spacing: 2) {
                Text("Automatic Background Sync")
                  .font(.subheadline)
                  .fontWeight(.medium)
                Text("SwiftData syncs journal entries to CloudKit automatically when changes occur. No manual action needed.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }

            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "2.circle.fill")
                .foregroundStyle(.blue)
              VStack(alignment: .leading, spacing: 2) {
                Text("Requirements")
                  .font(.subheadline)
                  .fontWeight(.medium)
                Text("Sync requires an active internet connection and a signed-in iCloud account.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }

            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "3.circle.fill")
                .foregroundStyle(.blue)
              VStack(alignment: .leading, spacing: 2) {
                Text("Timing")
                  .font(.subheadline)
                  .fontWeight(.medium)
                Text("Sync timing is controlled by SwiftData and CloudKit. We can observe when sync events occur but cannot control them. Initial sync may take a few minutes. Subsequent syncs happen within seconds of changes.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
          .padding(.vertical, 4)
        } header: {
          Text("How Sync Works")
        }

        // MARK: - Advanced
        Section {
          NavigationLink {
            SyncActivityDetailView()
          } label: {
            Label("Sync Activity Details", systemImage: "chart.line.uptrend.xyaxis")
          }

          NavigationLink {
            TroubleshootingView()
          } label: {
            Label("Troubleshooting Guide", systemImage: "wrench.and.screwdriver")
          }
        } header: {
          Text("Advanced")
        }
      }
    }
    .navigationTitle("iCloud Sync")
    .navigationBarTitleDisplayMode(.large)
    .alert("Enable iCloud Sync", isPresented: $showEnableAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Enable") {
        userPreferences.isCloudSyncEnabled = true
        syncManager.enableSync()
        // Notify to recreate container
        NotificationCenter.default.post(name: NSNotification.Name("CloudSyncPreferenceChanged"), object: nil)
      }
    } message: {
      Text("Enable automatic iCloud synchronization?\n\nThis will sync your journal entries (via SwiftData) and preferences (via iCloud Key-Value Store) across all your devices.\n\nRequires internet connection and active iCloud account.")
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
      Text("Disable iCloud sync?\n\nYour data will remain on this device and in iCloud, but will stop syncing with other devices.")
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
      Section {
        if let lastImport = syncManager.lastObservedImport {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
              Text("Last Import")
                .font(.subheadline)
                .fontWeight(.semibold)
              Spacer()
            }

            Text(lastImport.formatted(date: .abbreviated, time: .standard))
              .font(.caption)
              .foregroundStyle(.secondary)

            Text("Data downloaded from CloudKit")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
          .padding(.vertical, 4)
        } else {
          HStack {
            Image(systemName: "arrow.down.circle")
              .foregroundStyle(.secondary)
            Text("No import events observed yet")
              .foregroundStyle(.secondary)
          }
        }

        if let lastExport = syncManager.lastObservedExport {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.green)
              Text("Last Export")
                .font(.subheadline)
                .fontWeight(.semibold)
              Spacer()
            }

            Text(lastExport.formatted(date: .abbreviated, time: .standard))
              .font(.caption)
              .foregroundStyle(.secondary)

            Text("Data uploaded to CloudKit")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
          .padding(.vertical, 4)
        } else {
          HStack {
            Image(systemName: "arrow.up.circle")
              .foregroundStyle(.secondary)
            Text("No export events observed yet")
              .foregroundStyle(.secondary)
          }
        }
      } header: {
        Text("Observed CloudKit Events")
      } footer: {
        Text("These are CloudKit sync events we've detected. Import means data came down from iCloud, export means data went up to iCloud.")
          .font(.caption)
      }

      Section {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
              .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
              Text("About These Timestamps")
                .font(.subheadline)
                .fontWeight(.semibold)

              Text("These times show when we observed CloudKit sync events. They are best-effort detection and not guaranteed to capture every sync operation.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
              Text("Limitations")
                .font(.subheadline)
                .fontWeight(.semibold)

              VStack(alignment: .leading, spacing: 2) {
                Text("• Events may occur without us detecting them")
                Text("• We cannot trigger these events manually")
                Text("• SwiftData controls all sync timing")
                Text("• These are observations, not guarantees")
              }
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.vertical, 4)
      } header: {
        Text("Understanding Sync Events")
      }
    }
    .navigationTitle("Sync Activity")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - Troubleshooting View
struct TroubleshootingView: View {
  @Environment(\.cloudSyncManager) private var syncManager
  @Environment(\.networkMonitor) private var networkMonitor

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 16) {
          TroubleshootingStep(
            number: "1",
            title: "Check iCloud Account",
            description: "Go to Settings → [Your Name] and ensure you're signed in to iCloud with iCloud Drive enabled."
          )

          TroubleshootingStep(
            number: "2",
            title: "Verify Internet Connection",
            description: "Make sure you have an active internet connection (Wi-Fi or cellular data). Current status: \(networkMonitor.connectionDescription)"
          )

          TroubleshootingStep(
            number: "3",
            title: "Check iCloud Storage",
            description: "Ensure you have available iCloud storage space. Go to Settings → [Your Name] → iCloud → Manage Storage."
          )

          TroubleshootingStep(
            number: "4",
            title: "Wait for Sync",
            description: "SwiftData syncs automatically but may take a few minutes, especially for initial sync or large amounts of data. Be patient."
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
        .padding(.vertical, 8)
      } header: {
        Text("Common Solutions")
      }

      Section {
        Button {
          syncManager.checkCloudAvailability()
        } label: {
          HStack {
            Image(systemName: "arrow.clockwise")
            Text("Refresh iCloud Status")
            Spacer()
          }
        }

        Button {
          syncManager.reset()
        } label: {
          HStack {
            Image(systemName: "arrow.counterclockwise")
            Text("Reset Sync State")
            Spacer()
          }
        }
      } header: {
        Text("Actions")
      }

      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("Important Notes")
            .font(.subheadline)
            .fontWeight(.semibold)

          VStack(alignment: .leading, spacing: 4) {
            Text("• SwiftData controls sync timing - we cannot force immediate sync")
            Text("• We can observe CloudKit sync events but not control when they happen")
            Text("• Initial sync may take several minutes")
            Text("• Sync works best on real devices, not simulators")
            Text("• Changes may take 10-30 seconds to appear on other devices")
            Text("• Large attachments (drawings) may take longer to sync")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      } header: {
        Text("Understanding Sync")
      }
    }
    .navigationTitle("Troubleshooting")
    .navigationBarTitleDisplayMode(.inline)
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
        .fontWeight(.bold)
        .foregroundStyle(.blue)
        .frame(width: 32, height: 32)
        .background(
          Circle()
            .fill(.blue.opacity(0.1))
        )

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  NavigationStack {
    iCloudSyncView()
      .environment(\.userPreferences, UserPreferences.shared)
      .environment(\.cloudSyncManager, CloudSyncManager.shared)
      .environment(\.networkMonitor, NetworkMonitor.shared)
      .environment(\.preferencesSyncManager, PreferencesSyncManager.shared)
  }
}

#Preview("Sync Activity") {
  NavigationStack {
    SyncActivityDetailView()
      .environment(\.cloudSyncManager, CloudSyncManager.shared)
  }
}

#Preview("Troubleshooting") {
  NavigationStack {
    TroubleshootingView()
      .environment(\.cloudSyncManager, CloudSyncManager.shared)
      .environment(\.networkMonitor, NetworkMonitor.shared)
  }
}
