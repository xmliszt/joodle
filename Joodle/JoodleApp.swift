//
//  JoodleApp.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

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

@main
struct JoodleApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @State private var colorScheme: ColorScheme? = UserPreferences.shared.preferredColorScheme
  @State private var selectedDateFromWidget: Date?
  @State private var showPaywallFromWidget = false
  @State private var containerKey = UUID()
  @State private var modelContainer: ModelContainer
  @State private var showLaunchScreen = true

  init() {
    let container = Self.createModelContainer()
    _modelContainer = State(initialValue: container)

    // Run dateString migration synchronously for existing entries
    Self.runDateStringMigration(container: container)

    // Run legacy thumbnail cleanup migration
    Self.runLegacyThumbnailCleanup(container: container)
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

  /// Cleans up legacy thumbnail data (20px and 1080px) to reclaim storage
  private static func runLegacyThumbnailCleanup(container: ModelContainer) {
    let context = ModelContext(container)
    let cleanupKey = "hasCleanedLegacyThumbnails_v1"

    // Only run once
    guard !UserDefaults.standard.bool(forKey: cleanupKey) else {
      return
    }

    let descriptor = FetchDescriptor<DayEntry>()

    do {
      let allEntries = try context.fetch(descriptor)
      var cleanedCount = 0

      for entry in allEntries {
        var needsSave = false

        if entry.drawingThumbnail20 != nil {
          entry.drawingThumbnail20 = nil
          needsSave = true
        }

        if entry.drawingThumbnail1080 != nil {
          entry.drawingThumbnail1080 = nil
          needsSave = true
        }

        if needsSave {
          cleanedCount += 1
        }
      }

      if cleanedCount > 0 {
        try context.save()
        print("LegacyThumbnailCleanup: Cleaned up \(cleanedCount) entries on startup")
      }

      UserDefaults.standard.set(true, forKey: cleanupKey)
    } catch {
      print("LegacyThumbnailCleanup: Failed during startup: \(error)")
    }
  }

  static func createModelContainer() -> ModelContainer {
    // 1. Define schemas
    let schema = Schema([
      DayEntry.self
    ])

    // 2. Check BOTH user preference AND system availability
    let userWantsCloud = UserPreferences.shared.isCloudSyncEnabled
    let systemCloudEnabled = FileManager.default.ubiquityIdentityToken != nil

    // Only enable cloud if BOTH user wants it AND system allows it
    let shouldUseCloud = userWantsCloud && systemCloudEnabled

    // 3. Configure for iCloud only if both conditions are met
    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: shouldUseCloud ? .private("iCloud.dev.liyuxuan.joodle") : .none
    )

    // 4. Create the container
    do {
      return try ModelContainer(for: schema, configurations: [config])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
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
                setupColorSchemeObserver()
                setupSyncObserver()
                setupUbiquityObserver()
                debugPrint(">>> Screen corner radius: \(UIDevice.screenCornerRadius)")
                debugPrint(">>> Dynamic island size: \(UIDevice.dynamicIslandSize)")
                debugPrint(">>> Dynamic island frame: \(UIDevice.dynamicIslandFrame)")
              }
              .onOpenURL { url in
                handleWidgetURL(url)
              }
              .sheet(isPresented: $showPaywallFromWidget) {
                StandalonePaywallView()
                  .presentationDetents([.large])
              }
              .id(containerKey)
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
      showPaywallFromWidget = true
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

  private func setupSyncObserver() {
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("CloudSyncPreferenceChanged"),
      object: nil,
      queue: .main
    ) { [self] _ in
      // Recreate the model container with new configuration
      modelContainer = Self.createModelContainer()
      containerKey = UUID()
    }
  }

  private func setupUbiquityObserver() {
    // Monitor system-level iCloud Documents & Data changes
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name.NSUbiquityIdentityDidChange,
      object: nil,
      queue: .main
    ) { [self] _ in
      // Check if we need to recreate the container
      let userWantsCloud = UserPreferences.shared.isCloudSyncEnabled
      let systemCloudEnabled = FileManager.default.ubiquityIdentityToken != nil

      // If there's a mismatch between what we're using and what's available, recreate
      if userWantsCloud && !systemCloudEnabled {
        // System cloud was disabled but user preference is still on
        // CloudSyncManager will handle updating the preference
        // We just need to recreate the container after that happens
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
          modelContainer = Self.createModelContainer()
          containerKey = UUID()
        }
      }
    }
  }
}
