//
//  JoodleApp.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import CloudKit
import SwiftData
import SwiftUI
import UIKit
import Combine

// AppDelegate to enforce portrait orientation
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return .portrait
  }
}

/// Singleton manager for ModelContainer to prevent multiple CloudKit registrations
/// CloudKit can only have ONE active sync handler per store - creating multiple containers
/// causes "BUG IN CLIENT OF CLOUDKIT" errors due to duplicate handler registration
final class ModelContainerManager {
  static let shared = ModelContainerManager()

  /// The single ModelContainer instance for the entire app lifecycle
  let container: ModelContainer

  /// Track whether sync was enabled when container was created
  let wasCloudSyncEnabledAtLaunch: Bool

  /// Track if this is a detected reinstall with cloud data
  let isReinstallWithCloudData: Bool

  private init() {
    let systemCloudEnabled = FileManager.default.ubiquityIdentityToken != nil

    // Check local preference first
    let localSyncPreference = UserPreferences.shared.isCloudSyncEnabled

    // Check iCloud KVS for reinstall detection (survives app deletion)
    // This allows us to restore sync immediately for reinstalling users
    let cloudStore = NSUbiquitousKeyValueStore.default
    cloudStore.synchronize()
    let cloudSyncBackup = cloudStore.bool(forKey: "is_cloud_sync_enabled_backup") ||
                          cloudStore.bool(forKey: "cloud_sync_was_enabled")

    // Determine if this is a reinstall scenario:
    // - Local preference is OFF (fresh install/reinstall clears UserDefaults)
    // - But iCloud KVS says sync WAS enabled (user had sync before)
    // - And system iCloud is available
    let isReinstall = !localSyncPreference && cloudSyncBackup && systemCloudEnabled
    isReinstallWithCloudData = isReinstall

    // Decide whether to enable CloudKit:
    // 1. User's local preference says YES, OR
    // 2. This is a reinstall with previous sync history
    // AND system iCloud must be available
    let shouldUseCloud = (localSyncPreference || isReinstall) && systemCloudEnabled
    wasCloudSyncEnabledAtLaunch = shouldUseCloud

    if isReinstall {
      print("ModelContainerManager: Detected reinstall with iCloud data - enabling CloudKit sync")
      // Restore the local preference to match what we're doing
      UserPreferences.shared.isCloudSyncEnabled = true
    }

    // Create the container once with the determined configuration
    container = Self.createContainer(shouldUseCloud: shouldUseCloud)

    // Backup preference to iCloud if sync is enabled
    if shouldUseCloud {
      cloudStore.set(true, forKey: "is_cloud_sync_enabled_backup")
      cloudStore.synchronize()
    }

    print("ModelContainerManager: Container created with CloudKit=\(shouldUseCloud), isReinstall=\(isReinstall)")
  }

  private static func createContainer(shouldUseCloud: Bool) -> ModelContainer {
    let schema = Schema([DayEntry.self])

    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: shouldUseCloud ? .private("iCloud.dev.liyuxuan.joodle") : .none
    )

    do {
      return try ModelContainer(for: schema, configurations: [config])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }

  /// Check if sync preference has changed since app launch (requires restart)
  var needsRestartForSyncChange: Bool {
    let userWantsCloud = UserPreferences.shared.isCloudSyncEnabled
    let systemCloudEnabled = FileManager.default.ubiquityIdentityToken != nil
    let currentDesiredState = userWantsCloud && systemCloudEnabled
    return currentDesiredState != wasCloudSyncEnabledAtLaunch
  }
}

@main
struct JoodleApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @State private var colorScheme: ColorScheme? = UserPreferences.shared.preferredColorScheme
  @State private var selectedDateFromWidget: Date?
  @State private var showPaywallFromWidget = false
  @State private var showLaunchScreen = true
  @State private var hasSetupObservers = false

  /// Use the singleton container - never recreate during app lifecycle
  private let modelContainer = ModelContainerManager.shared.container

  init() {
    // Initialize app environment detection (TestFlight vs App Store)
    AppEnvironment.initialize()

    // Run migrations using the singleton container
    let container = ModelContainerManager.shared.container

    // Run dateString migration synchronously for existing entries
    Self.runDateStringMigration(container: container)

    // Run duplicate entry cleanup migration
    Self.runDuplicateEntryCleanup(container: container)

    // Run legacy thumbnail cleanup migration
    Self.runLegacyThumbnailCleanup(container: container)

    // Regenerate thumbnails with dual sizes (runs async in background)
    Self.runDualThumbnailRegeneration(container: container)
  }

  /// Cleans up duplicate entries (same dateString) by merging content and deleting duplicates
  private static func runDuplicateEntryCleanup(container: ModelContainer) {
    Task { @MainActor in
      let context = ModelContext(container)
      let result = DuplicateEntryCleanup.shared.cleanupDuplicates(modelContext: context)
      if result.merged > 0 || result.deleted > 0 {
        print("DuplicateEntryCleanup: Completed - merged \(result.merged), deleted \(result.deleted)")
      }
    }
  }

  /// Runs the dateString migration synchronously to populate dateString for existing entries
  private static func runDateStringMigration(container: ModelContainer) {
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let allEntries = try context.fetch(descriptor)
      var migratedCount = 0

      for entry in allEntries {
        if entry.dateString.isEmpty {
          entry.dateString = DayEntry.dateToString(entry.createdAt)
          migratedCount += 1
        }
      }

      if migratedCount > 0 {
        try context.save()
        print("DateStringMigration: Migrated \(migratedCount) entries on startup")
      }
    } catch {
      print("DateStringMigration: Failed during startup: \(error)")
    }
  }

  /// Cleans up legacy 1080px thumbnail data to reclaim storage
  private static func runLegacyThumbnailCleanup(container: ModelContainer) {
    let context = ModelContext(container)
    let cleanupKey = "hasCleanedLegacy1080Thumbnails_v1"

    // Only run once
    guard !UserDefaults.standard.bool(forKey: cleanupKey) else {
      return
    }

    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let allEntries = try context.fetch(descriptor)
      var cleanedCount = 0

      for entry in allEntries {
        // Only clear legacy 1080px thumbnail
        if entry.drawingThumbnail1080 != nil {
          entry.drawingThumbnail1080 = nil
          cleanedCount += 1
        }
      }

      if cleanedCount > 0 {
        try context.save()
        print("LegacyThumbnailCleanup: Cleaned up \(cleanedCount) entries with 1080px thumbnails on startup")
      }

      UserDefaults.standard.set(true, forKey: cleanupKey)
    } catch {
      print("LegacyThumbnailCleanup: Failed during startup: \(error)")
    }
  }

  /// Regenerates all thumbnails with dual sizes (20px thicker strokes + 200px normal)
  private static func runDualThumbnailRegeneration(container: ModelContainer) {
    let regenerationKey = "hasRegeneratedDualThumbnails_v1"

    // Only run once
    guard !UserDefaults.standard.bool(forKey: regenerationKey) else {
      return
    }

    // Run asynchronously to not block app startup
    Task { @MainActor in
      let context = ModelContext(container)
      let descriptor = FetchDescriptor<DayEntry>()

      do {
        let allEntries = try context.fetch(descriptor)
        var regeneratedCount = 0

        for entry in allEntries {
          if let drawingData = entry.drawingData, !drawingData.isEmpty {
            let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(
              from: drawingData)
            entry.drawingThumbnail20 = thumbnails.0
            entry.drawingThumbnail200 = thumbnails.1
            regeneratedCount += 1

            // Save periodically to avoid memory buildup
            if regeneratedCount % 10 == 0 {
              try? context.save()
            }
          }
        }

        if regeneratedCount > 0 {
          try context.save()
          print("DualThumbnailRegeneration: Regenerated \(regeneratedCount) entries with 20px + 200px thumbnails on startup")
        }

        UserDefaults.standard.set(true, forKey: regenerationKey)
      } catch {
        print("DualThumbnailRegeneration: Failed during startup: \(error)")
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      ZStack {
        if !hasCompletedOnboarding {
          OnboardingFlowView()
            .environment(\.userPreferences, UserPreferences.shared)
            .preferredColorScheme(colorScheme)
            .font(.system(size: 17))
        } else {
          NavigationStack {
            ContentView(selectedDateFromWidget: $selectedDateFromWidget)
              .environment(\.userPreferences, UserPreferences.shared)
              .environment(\.cloudSyncManager, CloudSyncManager.shared)
              .environment(\.networkMonitor, NetworkMonitor.shared)
              .environment(\.preferencesSyncManager, PreferencesSyncManager.shared)
              .preferredColorScheme(colorScheme)
              .font(.system(size: 17))
              .onAppear {
                // Only setup observers once to prevent duplicate notifications
                if !hasSetupObservers {
                  setupColorSchemeObserver()
                  hasSetupObservers = true
                }
              }
              .onOpenURL { url in
                handleWidgetURL(url)
              }
              .sheet(isPresented: $showPaywallFromWidget) {
                StandalonePaywallView()
                  .presentationDetents([.large])
              }
          }
        }

        if showLaunchScreen {
          LaunchScreenView()
            .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showLaunchScreen = false
              }
            }
        }
      }
      .preferredColorScheme(colorScheme)
    }
    .modelContainer(modelContainer)
  }

  private func setupColorSchemeObserver() {
    NotificationCenter.default.addObserver(
      forName: .didChangeColorScheme,
      object: nil,
      queue: .main
    ) { [self] _ in
      colorScheme = UserPreferences.shared.preferredColorScheme
    }
  }

  private func handleWidgetURL(_ url: URL) {
    guard url.scheme == "joodle" else { return }

    // Handle URL scheme: joodle://paywall
    if url.host == "paywall" {
      // Check subscription status before showing paywall
      // The StandalonePaywallView will also verify and dismiss if subscribed,
      // but this prevents unnecessary sheet presentation when possible
      Task {
        await SubscriptionManager.shared.updateSubscriptionStatus()
        await MainActor.run {
          if !SubscriptionManager.shared.isSubscribed {
            showPaywallFromWidget = true
          }
        }
      }
      return
    }

    // Handle URL scheme: joodle://date/{timestamp}
    guard url.host == "date",
          let timestamp = url.pathComponents.last,
          let timeInterval = TimeInterval(timestamp) else {
      return
    }

    let date = Date(timeIntervalSince1970: timeInterval)
    selectedDateFromWidget = date
  }
}
