//
//  DeveloperOptionsView.swift
//  Joodle
//
//  Dedicated developer/debug page pushed from Settings. Never visible in
//  App Store builds (or while simulating production).
//

import SwiftUI

struct DeveloperOptionsView: View {
  @Binding var simulateProductionEnvironment: Bool

  @StateObject private var subscriptionManager = SubscriptionManager.shared

  @State private var showAppStats = false
  @State private var showPlaceholderGenerator = false
  @State private var showSubscriptionTesting = false
  @State private var showSimulateFirstLaunchAlert = false
  @State private var userConditionStatusMessage: String?
#if DEBUG
  @State private var showDataSeeder = false
  @State private var showBannerPreview = false
  @State private var simulateCameraDenied = CameraReferenceContext.debugSimulateCameraDenied
#endif

  var body: some View {
    Form {
      if AppEnvironment.isDebug {
        environmentSection
        monetizationSection
      }
      if !AppEnvironment.isAppStore {
        gracePeriodSection
      }
      if AppEnvironment.isDebug {
        userSimulationSection
        toolsSection
        changelogAndAlertsSection
#if DEBUG
        LiquidBackdropDebugSection()
#endif
        dangerZoneSection
      }
    }
    .navigationTitle(Text(verbatim: "Developer"))
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showAppStats) {
      AppStatsView()
    }
    .sheet(isPresented: $showPlaceholderGenerator) {
      PlaceholderGeneratorView()
    }
    .sheet(isPresented: $showSubscriptionTesting) {
      SubscriptionTestingView()
    }
#if DEBUG
    .sheet(isPresented: $showDataSeeder) {
      DebugDataSeederView()
    }
    .sheet(isPresented: $showBannerPreview) {
      MembershipBannerPreviewView()
    }
#endif
    .alert(
      Text(verbatim: "Simulate First-Time User?"),
      isPresented: $showSimulateFirstLaunchAlert
    ) {
      Button(role: .destructive) {
        simulateFirstTimeUser()
      } label: {
        Text(verbatim: "Reset & Restart")
      }
      Button(role: .cancel) {} label: {
        Text(verbatim: "Cancel")
      }
    } message: {
      Text(verbatim: "This resets onboarding and feature-tooltip state and quits the app. Reopen it to go through onboarding as a brand-new user.")
    }
  }

  // MARK: - Environment

  private var environmentSection: some View {
    Section {
      Toggle(isOn: Binding(
        get: { AppEnvironment.simulateProductionEnvironment },
        set: { newValue in
          AppEnvironment.simulateProductionEnvironment = newValue
          simulateProductionEnvironment = newValue
        }
      )) {
        row(icon: "shippingbox.fill", color: .purple, title: "Simulate Production")
      }

#if DEBUG
      Toggle(isOn: Binding(
        get: { CameraReferenceContext.debugSimulateCameraDenied },
        set: { newValue in
          CameraReferenceContext.debugSimulateCameraDenied = newValue
          simulateCameraDenied = newValue
        }
      )) {
        row(icon: "camera.fill", color: .indigo, title: "Simulate Camera Denied")
      }
#endif
    } header: {
      Text(verbatim: "Environment")
    } footer: {
      Text(verbatim: "Simulate Production hides everything here and makes the app behave like an App Store release. Exit from the Settings page.")
    }
  }

  // MARK: - Monetization

  private var monetizationSection: some View {
    Section {
      HStack {
        row(icon: "crown.fill", color: .yellow, title: "App Status")
        Spacer()
        if subscriptionManager.isSubscribed {
          Text(verbatim: "Subscribed ✓")
            .font(.appSubheadline())
            .foregroundColor(.green)
        } else if GracePeriodManager.shared.isInGracePeriod {
          Text(verbatim: "Trial · \(GracePeriodManager.shared.gracePeriodDaysRemaining)d left")
            .font(.appSubheadline())
            .foregroundColor(.orange)
        } else {
          Text(verbatim: "Free")
            .font(.appSubheadline())
            .foregroundColor(.secondary)
        }
      }

      Button {
        showSubscriptionTesting = true
      } label: {
        row(icon: "creditcard.fill", color: .green, title: "Subscription Testing Console")
      }

#if DEBUG
      Button {
        showBannerPreview = true
      } label: {
        row(icon: "rectangle.stack.fill", color: .teal, title: "Preview Membership Banner")
      }
#endif
    } header: {
      Text(verbatim: "Monetization")
    } footer: {
      Text(verbatim: "The console covers StoreKit scenarios and the limited-time offer window.")
    }
  }

  // MARK: - Grace Period

  private var gracePeriodSection: some View {
    Section {
      Button {
        GracePeriodManager.shared.resetGracePeriod()
        GracePeriodManager.shared.startGracePeriodIfNeeded()
        print("🎉 Grace period reset to 7 days from now")
      } label: {
        row(icon: "hourglass", color: .orange, title: "Reset Grace Period (7 Days)")
      }

      Button(role: .destructive) {
        // Set grace period start to 8 days ago so it's already expired
        let expiredDate = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        GracePeriodManager.shared.setGracePeriodStart(expiredDate)
        print("⏰ Grace period force-expired (start set to \(expiredDate))")
      } label: {
        row(icon: "hourglass.bottomhalf.filled", color: .red, title: "Expire Grace Period Now")
      }
    } header: {
      Text(verbatim: "Grace Period")
    }
  }

  // MARK: - User Simulation

  private var userSimulationSection: some View {
    Section {
      Button {
        showSimulateFirstLaunchAlert = true
      } label: {
        row(icon: "person.crop.circle.badge.plus", color: .blue, title: "Simulate First-Time User…")
      }

      Button {
        // Already onboarded, but feature tips have never been seen — so the
        // next time the target screen appears, the tooltip shows.
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "isRevisitFromSettings")
        FeatureTipManager.shared.resetSeenState()
        userConditionStatusMessage = "Existing user simulated — feature tooltips reset. Open a drawing to see them."
        print("DEBUG: Simulated existing user with unseen feature tooltips")
      } label: {
        row(icon: "person.crop.circle.badge.questionmark", color: .cyan, title: "Simulate User w/ Unseen Features")
      }
    } header: {
      Text(verbatim: "User Simulation")
    } footer: {
      if let userConditionStatusMessage {
        Text(verbatim: userConditionStatusMessage)
      }
    }
  }

  // MARK: - Tools

  private var toolsSection: some View {
    Section {
      Button {
        showAppStats = true
      } label: {
        row(icon: "chart.bar.fill", color: .blue, title: "App Stats")
      }

#if DEBUG
      // TEMPORARY: filter-tuning workbench. Remove once the Fujifilm grade
      // is dialed in and the chosen preset is committed to FujifilmFilter.
      NavigationLink {
        FujifilmFilterLab()
          .navigationTitle("Joodle Photo Filter Lab")
          .navigationBarTitleDisplayMode(.inline)
      } label: {
        row(icon: "camera.filters", color: .pink, title: "Photo Filter Lab")
      }

      Button {
        showDataSeeder = true
      } label: {
        row(icon: "tray.and.arrow.down.fill", color: .brown, title: "Data Seeder")
      }
#endif

      Button {
        showPlaceholderGenerator = true
      } label: {
        row(icon: "photo.fill", color: .mint, title: "Generate Placeholder")
      }
    } header: {
      Text(verbatim: "Tools")
    }
  }

  // MARK: - Changelog & Remote Alerts

  private var changelogAndAlertsSection: some View {
    Section {
      NavigationLink {
        ChangelogPreviewDebugView()
      } label: {
        row(icon: "doc.text.fill", color: .indigo, title: "Preview Changelog Sheet")
      }

      Button {
        ChangelogManager.shared.resetChangelogState()
        print("DEBUG: Changelog state reset - will show on next launch")
      } label: {
        row(icon: "arrow.counterclockwise", color: .indigo, title: "Reset Changelog State")
      }

#if DEBUG
      Button {
        RemoteAlertService.shared.showTestAlert()
      } label: {
        row(icon: "bell.badge.fill", color: .orange, title: "Show Test Remote Alert")
      }

      Button {
        Task {
          await RemoteAlertService.shared.checkForAlert()
        }
      } label: {
        row(icon: "arrow.down.circle.fill", color: .orange, title: "Fetch Remote Alert Now")
      }

      Button {
        RemoteAlertService.shared.resetDismissedState()
      } label: {
        row(icon: "arrow.counterclockwise", color: .orange, title: "Reset Remote Alert State")
      }
#endif
    } header: {
      Text(verbatim: "Changelog & Remote Alerts")
    }
  }

  // MARK: - Danger Zone

  private var dangerZoneSection: some View {
    Section {
      Button(role: .destructive) {
        let cloudStore = NSUbiquitousKeyValueStore.default
        cloudStore.removeObject(forKey: "is_cloud_sync_enabled_backup")
        cloudStore.removeObject(forKey: "cloud_sync_was_enabled")
        cloudStore.synchronize()
        print("DEBUG: iCloud KVS sync history cleared!")
      } label: {
        row(icon: "icloud.slash.fill", color: .red, title: "Clear iCloud KVS (Sync History)")
      }
    } header: {
      Text(verbatim: "Danger Zone")
    } footer: {
      Text(verbatim: "Clears the iCloud key-value flags that remember whether sync was ever enabled on this account.")
    }
  }

  // MARK: - Helpers

  private func row(icon: String, color: Color, title: String) -> some View {
    HStack {
      SettingsIconView(systemName: icon, backgroundColor: color)
      Text(verbatim: title)
        .foregroundColor(.primary)
    }
  }

  /// Reset all persisted state so the next launch behaves like a brand-new
  /// install going through onboarding for the first time.
  private func simulateFirstTimeUser() {
    // Trigger onboarding as a genuine first run (not a Settings revisit).
    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    UserDefaults.standard.removeObject(forKey: "isRevisitFromSettings")
    // Clear feature-tip seen state so onboarding completion re-suppresses them
    // exactly as it would for a real new install.
    FeatureTipManager.shared.resetSeenState()
    print("DEBUG: Simulated first-time user — restarting to apply")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      exit(0)
    }
  }
}

// MARK: - Liquid Backdrop Debug Section

#if DEBUG
/// Debug-only control to simulate any time of day for the liquid backdrop's drain
/// level, or reset back to the device clock. Compiled out of release builds.
private struct LiquidBackdropDebugSection: View {
  private let debug = LiquidBackdropDebug.shared

  var body: some View {
    // Read here so the section re-renders when the override changes.
    let simulatedSeconds = debug.simulatedSecondsSinceMidnight

    Section {
      Toggle(isOn: Binding(
        get: { simulatedSeconds != nil },
        set: { isOn in
          debug.simulatedSecondsSinceMidnight = isOn ? Self.currentSecondsSinceMidnight() : nil
        }
      )) {
        HStack {
          SettingsIconView(systemName: "clock.badge.exclamationmark", backgroundColor: .orange)
          Text("Simulate Time of Day")
            .font(.appBody())
        }
      }

      if let seconds = simulatedSeconds {
        DatePicker(
          "Simulated Time",
          selection: Binding(
            get: { Self.date(fromSecondsSinceMidnight: seconds) },
            set: { debug.simulatedSecondsSinceMidnight = Self.secondsSinceMidnight(of: $0) }
          ),
          displayedComponents: .hourAndMinute
        )

        LabeledContent("Liquid Fill") {
          Text("\(Int((1 - seconds / 86_400) * 100))%")
            .foregroundStyle(.secondary)
        }

        Button(role: .destructive) {
          debug.simulatedSecondsSinceMidnight = nil
        } label: {
          Text("Reset to Device Clock")
        }
      }
    } header: {
      Text(verbatim: "Liquid Backdrop")
    } footer: {
      Text("Overrides the time of day that drains the liquid backdrop. Affects only the backdrop fill level — not the device clock. Debug builds only.")
    }
  }

  private static func currentSecondsSinceMidnight() -> Double {
    let now = Date()
    return now.timeIntervalSince(Calendar.current.startOfDay(for: now))
  }

  private static func secondsSinceMidnight(of date: Date) -> Double {
    date.timeIntervalSince(Calendar.current.startOfDay(for: date))
  }

  private static func date(fromSecondsSinceMidnight seconds: Double) -> Date {
    Calendar.current.startOfDay(for: Date()).addingTimeInterval(seconds)
  }
}
#endif

// MARK: - Preview

#if DEBUG
#Preview {
  NavigationStack {
    DeveloperOptionsView(simulateProductionEnvironment: .constant(false))
  }
}
#endif
