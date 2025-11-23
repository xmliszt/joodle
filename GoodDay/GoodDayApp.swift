//
//  GoodDayApp.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI
import UIKit

// AppDelegate to enforce portrait orientation
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return .portrait
  }
}

@main
struct GoodDayApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var colorScheme: ColorScheme? = UserPreferences.shared.preferredColorScheme
  @State private var selectedDateFromWidget: Date?

  var sharedModelContainer: ModelContainer = {

    // 1. Define schemas
    let schema = Schema([
      DayEntry.self
    ])

    // 2. Configure for iCloud
    let config = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
    )

    // 3. Create the container
    do {
      return try ModelContainer(for: schema, configurations: [config])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ContentView(selectedDateFromWidget: $selectedDateFromWidget)
          .environment(UserPreferences.shared)
          .preferredColorScheme(colorScheme)
          .font(.mansalva(size: 17))
          .onAppear {
            setupColorSchemeObserver()
          }
          .onOpenURL { url in
            handleWidgetURL(url)
          }
      }
    }
    .modelContainer(sharedModelContainer)
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
    // Handle URL scheme: goodday://date/{timestamp}
    guard url.scheme == "goodday",
          url.host == "date",
          let timestamp = url.pathComponents.last,
          let timeInterval = TimeInterval(timestamp) else {
      return
    }

    let date = Date(timeIntervalSince1970: timeInterval)
    selectedDateFromWidget = date
  }
}
