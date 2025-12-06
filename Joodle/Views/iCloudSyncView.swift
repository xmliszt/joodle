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
  @State private var showEnableAlert = false
  @State private var showDisableAlert = false
  @State private var pendingToggleValue = false

  var body: some View {
    List {
      // MARK: - Main Toggle Section
      Section {
        Toggle(isOn: Binding(
          get: { userPreferences.isCloudSyncEnabled },
          set: { newValue in
            pendingToggleValue = newValue
            if newValue {
              showEnableAlert = true
            } else {
              showDisableAlert = true
            }
          }
        )) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Sync to iCloud")
              .font(.body)

            if !syncManager.isCloudAvailable {
              Text("iCloud not available")
                .font(.caption)
                .foregroundStyle(.red)
            }
          }
        }
        .disabled(!syncManager.isCloudAvailable)
      } footer: {
        if !syncManager.isCloudAvailable {
          Text("Please sign in to iCloud in Settings to enable sync.")
            .font(.caption)
            .foregroundStyle(.red)
        } else {
          Text("Sync your journal entries across all your devices using iCloud.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      // MARK: - Sync Status Section
      if userPreferences.isCloudSyncEnabled {
        Section {
          // Syncing indicator
          if syncManager.isSyncing {
            HStack(spacing: 12) {
              ProgressView()
                .scaleEffect(0.8)

              VStack(alignment: .leading, spacing: 2) {
                Text("Syncing...")
                  .font(.body)

                if !syncManager.syncStatus.isEmpty {
                  Text(syncManager.syncStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }

              Spacer()

              Text("Preparing")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
          }

          // Manual sync button
          Button {
            syncManager.triggerManualSync()
          } label: {
            HStack {
              Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.accent)

              Text("Sync Now")
                .foregroundStyle(.primary)

              Spacer()
            }
          }
          .disabled(syncManager.isSyncing)

        } header: {
          Text("Sync Actions")
        } footer: {
          if let lastSync = syncManager.lastSyncDate {
            Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            Text("Never synced")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        // MARK: - Advanced Section
        Section {
          NavigationLink {
            iCloudSyncStatusView()
          } label: {
            Label("iCloud Sync Status", systemImage: "checkmark.icloud")
          }

          NavigationLink {
            iCloudTroubleshootingView()
          } label: {
            Label("Troubleshooting", systemImage: "wrench.and.screwdriver")
          }
        } header: {
          Text("Advanced")
        }

        // MARK: - Complete Re-Sync Section
        Section {
            Button {
              syncManager.triggerManualSync()
            } label: {
              Text("Trigger Complete Re-Sync")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            }
        }
      }
    }
    .navigationTitle("iCloud Sync")
    .navigationBarTitleDisplayMode(.large)
    .alert("Enable iCloud Sync", isPresented: $showEnableAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Turn On") {
        userPreferences.isCloudSyncEnabled = true
        syncManager.enableSync()
        // Notify to recreate container
        NotificationCenter.default.post(name: NSNotification.Name("CloudSyncPreferenceChanged"), object: nil)
      }
    } message: {
      Text("Turning on iCloud synchronization will enable you to store all of your data in your private iCloud storage and sync between devices. The initial sync might take a couple of seconds to finish.")
    }
    .alert("Disable iCloud Sync", isPresented: $showDisableAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Turn Off", role: .destructive) {
        userPreferences.isCloudSyncEnabled = false
        syncManager.disableSync()
        // Notify to recreate container
        NotificationCenter.default.post(name: NSNotification.Name("CloudSyncPreferenceChanged"), object: nil)
      }
    } message: {
      Text("Turning off iCloud sync will keep your local data but stop syncing with other devices. Your data will remain on this device.")
    }
    .onAppear {
      syncManager.checkCloudAvailability()
    }
  }
}

// MARK: - iCloud Sync Status View
struct iCloudSyncStatusView: View {
  @Environment(\.cloudSyncManager) private var syncManager

  var body: some View {
    List {
      Section {
        HStack {
          Text("iCloud Account")
          Spacer()
          Image(systemName: syncManager.isCloudAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(syncManager.isCloudAvailable ? .green : .red)
        }

        HStack {
          Text("Sync Status")
          Spacer()
          Text(syncManager.isSyncing ? "Syncing" : "Idle")
            .foregroundStyle(.secondary)
        }

        if let lastSync = syncManager.lastSyncDate {
          HStack {
            Text("Last Sync")
            Spacer()
            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
              .foregroundStyle(.secondary)
          }
        }
      } header: {
        Text("Status")
      } footer: {
        if syncManager.hasError {
          Text(syncManager.errorMessage ?? "Unknown error")
            .foregroundStyle(.red)
            .font(.footnote)
        }
      }
    }
    .navigationTitle("Sync Status")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - Troubleshooting View
struct iCloudTroubleshootingView: View {
  @Environment(\.cloudSyncManager) private var syncManager

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 4) {
          Text("1. Check iCloud Settings")
          Text("Make sure you're signed in to iCloud and have iCloud Drive enabled.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("2. Check Network Connection")
          Text("Ensure you have a stable internet connection.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("3. Restart the App")
          Text("Close and reopen the app to refresh the sync connection.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("4. Trigger Manual Sync")
          Text("Use the 'Sync Now' button to force a sync attempt.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Experiencing issue? Try these steps.")
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
            Image(systemName: "arrow.clockwise")
            Text("Reset Sync State")
            Spacer()
          }
        }
      } header: {
        Text("Actions")
      }
    }
    .navigationTitle("Troubleshooting")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    iCloudSyncView()
  }
}

#Preview("Sync Status") {
  NavigationStack {
    iCloudSyncStatusView()
  }
}

#Preview("Troubleshooting") {
  NavigationStack {
    iCloudTroubleshootingView()
  }
}
