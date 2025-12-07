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
  @State private var containerKey = UUID()
  @State private var modelContainer: ModelContainer

  init() {
    _modelContainer = State(initialValue: Self.createModelContainer())
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
            }
            .onOpenURL { url in
              handleWidgetURL(url)
            }
            .id(containerKey)
        }
      }
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
    // Handle URL scheme: joodle://date/{timestamp}
    guard url.scheme == "joodle",
          url.host == "date",
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
