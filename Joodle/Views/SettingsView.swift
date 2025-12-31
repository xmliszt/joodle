import CoreHaptics
import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Navigation Coordinator for Swipe Back Gesture
struct NavigationGestureEnabler: UIViewControllerRepresentable {
  var isEnabled: Bool = true

  func makeUIViewController(context: Context) -> UIViewController {
    let controller = UIViewController()
    return controller
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    DispatchQueue.main.async {
      if let navigationController = uiViewController.navigationController {
        navigationController.interactivePopGestureRecognizer?.isEnabled = isEnabled
        navigationController.interactivePopGestureRecognizer?.delegate = context.coordinator
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
      return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return false
    }
  }
}

struct SettingsView: View {
  @Environment(\.userPreferences) private var userPreferences
  @Environment(\.cloudSyncManager) private var cloudSyncManager
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext
  @StateObject private var subscriptionManager = SubscriptionManager.shared
  @StateObject private var storeKitManager = StoreKitManager.shared
  @StateObject private var reminderManager = ReminderManager.shared
  @State private var showOnboarding = false
  @State private var showNotificationDeniedAlert = false
  @State private var showPlaceholderGenerator = false
  @State private var showPaywall = false
  @State private var showSubscriptions = false
  @State private var showAppStats = false
  @State private var showDataSeeder = false
  @State private var currentJoodleCount: Int = 0

  @State private var showSubscriptionTesting = false
  @State private var showRedeemCode = false
  @State private var showFaq = false
  @State private var showShareSheet = false
  @State private var showDeviceIdentifierAlert = false

  // Theme color change state
  @State private var pendingThemeColor: ThemeColor?
  @State private var showThemeOverlay = false
  private var themeColorManager = ThemeColorManager.shared

  /// Check if restart is needed for sync to work
  private var needsRestartForSync: Bool {
    userPreferences.isCloudSyncEnabled && ModelContainerManager.shared.needsRestartForSyncChange
  }

  // Import/Export State
  @State private var showFileExporter = false
  @State private var showFileImporter = false
  @State private var exportDocument: JSONDocument?
  @State private var importMessage = ""
  @State private var showImportAlert = false

  // Debug: Simulate production environment - bound to AppEnvironment
  @State private var simulateProductionEnvironment = AppEnvironment.simulateProductionEnvironment

  // MARK: - Computed Bindings
  private var viewModeBinding: Binding<ViewMode> {
    Binding(
      get: { userPreferences.defaultViewMode },
      set: { userPreferences.defaultViewMode = $0 }
    )
  }

  private var colorSchemeBinding: Binding<ColorScheme?> {
    Binding(
      get: { userPreferences.preferredColorScheme },
      set: { newValue in
        userPreferences.preferredColorScheme = newValue
        // Force UI update immediately
        NotificationCenter.default.post(name: .didChangeColorScheme, object: nil)
      }
    )
  }

  private var hapticBinding: Binding<Bool> {
    Binding(
      get: { userPreferences.enableHaptic },
      set: { userPreferences.enableHaptic = $0 }
    )
  }

  private var dailyReminderTimeBinding: Binding<Date> {
    Binding(
      get: { userPreferences.dailyReminderTime },
      set: { newTime in
        userPreferences.dailyReminderTime = newTime
        reminderManager.updateDailyReminderTime(newTime)
      }
    )
  }

  private var startOfWeekBinding: Binding<String> {
    Binding(
      get: { userPreferences.startOfWeek },
      set: { userPreferences.startOfWeek = $0 }
    )
  }

  var body: some View {
    Form {
      defaultViewSection
      startOfWeekSection
      appearanceSection
      themeColorSection
      interactionSection
      dailyReminderSection
      dataManagementSection
      freePlanLimitsSection
      onboardingSection
      labSection
      subscriptionSection
      systemSettingsSection
      needHelpSection
      feedbackSection
      developerOptionsSection
    }
    .background(NavigationGestureEnabler(isEnabled: !showThemeOverlay))
    .navigationDestination(isPresented: $showExperimentalFeatures) {
      ExperimentalFeaturesView()
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(userPreferences.preferredColorScheme)
    .navigationBarBackButtonHidden(showThemeOverlay)
    .interactiveDismissDisabled(showThemeOverlay)
    .overlay {
      if showThemeOverlay, let color = pendingThemeColor {
        ThemeColorLoadingOverlay(
          themeColorManager: themeColorManager,
          selectedColor: color,
          onDismiss: {
            withAnimation {
              showThemeOverlay = false
              pendingThemeColor = nil
            }
          }
        )
        .id(color) // Force fresh view instance for each color change
      }
    }

    .onChange(of: userPreferences.preferredColorScheme) { _, _ in
      // Force view refresh when color scheme changes
      NotificationCenter.default.post(name: .didChangeColorScheme, object: nil)
    }
    .fullScreenCover(isPresented: $showOnboarding) {
      OnboardingFlowView()
    }

    .sheet(isPresented: $showPlaceholderGenerator) {
      PlaceholderGeneratorView()
    }
    .sheet(isPresented: $showAppStats) {
      AppStatsView()
    }
#if DEBUG
    .sheet(isPresented: $showDataSeeder) {
      DebugDataSeederView()
    }
#endif
    .sheet(isPresented: $showPaywall) {
      StandalonePaywallView()
    }
    .navigationDestination(isPresented: $showSubscriptions) {
      SubscriptionsView()
    }
    .fileExporter(
      isPresented: $showFileExporter,
      document: exportDocument,
      contentType: .json,
      defaultFilename: "Joodle_Data_Backup_\(Date().timeIntervalSince1970)"
    ) { result in
      if case .failure(let error) = result {
        print("Backup failed: \(error.localizedDescription)")
      }
    }
    .fileImporter(
      isPresented: $showFileImporter,
      allowedContentTypes: [.json],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          importData(from: url)
        }
      case .failure(let error):
        print("Import failed: \(error.localizedDescription)")
      }
    }
    .alert("Import Result", isPresented: $showImportAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(importMessage)
    }
    .onAppear {
      // Check subscription status when view appears
      Task {
        await StoreKitManager.shared.updatePurchasedProducts()
        await subscriptionManager.updateSubscriptionStatus()
        if !subscriptionManager.isSubscribed {
          currentJoodleCount = subscriptionManager.fetchTotalJoodleCount(in: modelContext)
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidExpire)) { _ in
      // Refresh UI when subscription expires
      Task {
        await subscriptionManager.updateSubscriptionStatus()
      }
    }
  }

  // MARK: - Extracted Sections

  @ViewBuilder
  private var defaultViewSection: some View {
    Section {
      VStack(spacing: 0) {
        // Preview image with morph transition
        ZStack {
          Image("Others/MinimizedView")
            .resizable()
            .scaledToFit()
            .offset(y: userPreferences.defaultViewMode == .now ? 300 : 10)

          Image("Others/NormalView")
            .resizable()
            .scaledToFit()
            .offset(y: userPreferences.defaultViewMode == .now ? 10 : 300)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: userPreferences.defaultViewMode)

        // Picker
        if #available(iOS 26.0, *) {
          Picker("View Mode", selection: viewModeBinding) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          .pickerStyle(.palette)
          .glassEffect(.regular.interactive())
        } else {
          Picker("View Mode", selection: viewModeBinding) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          .pickerStyle(.palette)
        }

        // Explanation
        VStack {
          if userPreferences.defaultViewMode == .now {
            Text("\"Normal\" view mode gives you a more focused view with 7 days per row representing the 7 days of a week. Layout is shifted to match the weekday.")
              .font(.caption)
              .foregroundColor(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else if userPreferences.defaultViewMode == .year {
            Text("\"Minimized\" view mode gives you an overview of your entire year. Additional sharing is available in this view mode to share your entire year.")
              .font(.caption)
              .foregroundColor(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }.padding(.top, 12)
      }
    } header: {
      Text("Default View Mode")
    }
  }

  @ViewBuilder
  private var startOfWeekSection: some View {
    Section {
      VStack(spacing: 12) {
        // Picker
        if #available(iOS 26.0, *) {
          Picker("Start of Week", selection: startOfWeekBinding) {
            Text("Sunday").tag("sunday")
            Text("Monday").tag("monday")
          }
          .pickerStyle(.palette)
          .glassEffect(.regular.interactive())
        } else {
          Picker("Start of Week", selection: startOfWeekBinding) {
            Text("Sunday").tag("sunday")
            Text("Monday").tag("monday")
          }
          .pickerStyle(.palette)
        }
        
        // Explanation
        Text("Start of Week affects the layout in \"Normal\" view mode.")
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    } header: {
      Text("Start of Week")
    }
  }

  @ViewBuilder
  private var appearanceSection: some View {
    Section {
      if #available(iOS 26.0, *) {
        Picker("Color Scheme", selection: colorSchemeBinding) {
          Text("System").tag(nil as ColorScheme?)
          Text("Light").tag(ColorScheme.light as ColorScheme?)
          Text("Dark").tag(ColorScheme.dark as ColorScheme?)
        }
        .pickerStyle(.palette)
        .glassEffect(.regular.interactive())
      } else {
        Picker("Color Scheme", selection: colorSchemeBinding) {
          Text("System").tag(nil as ColorScheme?)
          Text("Light").tag(ColorScheme.light as ColorScheme?)
          Text("Dark").tag(ColorScheme.dark as ColorScheme?)
        }
        .pickerStyle(.palette)
      }
    } header: {
      Text("Appearance")
    }
  }

  @ViewBuilder
  private var themeColorSection: some View {
    Section {
      ThemeColorPaletteView(
        subscriptionManager: subscriptionManager,
        onLockedColorTapped: {
          showPaywall = true
        },
        onColorChangeStarted: { color in
          pendingThemeColor = color
          showThemeOverlay = true
        },
        onColorChangeCompleted: {
          // Don't dismiss here - let the overlay handle the completion screen and dismissal
        }
      )
      .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    } header: {
      Text("Theme Color")
    }
  }

  @ViewBuilder
  private var interactionSection: some View {
    if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
      Section {
        Toggle(isOn: hapticBinding) {
          Text("Haptic Feedback")
        }
      } header: {
        Text("Interactions")
      } footer: {
        Text("Haptic feedback also depends on your device's vibration setting in Settings > Accessibility > Touch > Vibration")
      }
    }
  }

  @ViewBuilder
  private var dailyReminderSection: some View {
    Section {
      // First row: Label and Toggle
      Toggle(isOn: Binding(
        get: { userPreferences.isDailyReminderEnabled },
        set: { newValue in
          if newValue {
            // Enabling - check permission
            Task {
              let success = await reminderManager.enableDailyReminder(at: userPreferences.dailyReminderTime)
              await MainActor.run {
                if success {
                  userPreferences.isDailyReminderEnabled = true
                } else {
                  // Permission denied - show alert
                  showNotificationDeniedAlert = true
                }
              }
            }
          } else {
            // Disabling
            userPreferences.isDailyReminderEnabled = false
            reminderManager.disableDailyReminder()
          }
        }
      )) {
        DatePicker(
          "",
          selection: dailyReminderTimeBinding,
          displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.compact)
      }
    } header: {
      Text("Daily Reminder")
    } footer: {
      Text("Get a daily notification to capture your moment")
    }
    .alert("Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
      Button("Open Settings") {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Please enable notifications in Settings to receive daily reminders.")
    }
  }

  @ViewBuilder
  private var systemSettingsSection: some View {
    Section {
      Button {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
          UIApplication.shared.open(url)
        }
      } label: {
        HStack {
          Image(systemName: "bell.badge.fill")
            .foregroundColor(.primary)
            .frame(width: 24)
          Text("Notifications")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Button {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      } label: {
        HStack {
          Image(systemName: "gear")
            .foregroundColor(.primary)
            .frame(width: 24)
          Text("App Settings")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    } header: {
      Text("Settings")
    } footer: {
      Text("In the Joodle app settings, you can manage photos permission, manage Siri and search, and customize notification appearance.")
    }
  }

  @ViewBuilder
  private var freePlanLimitsSection: some View {
    if !subscriptionManager.isSubscribed {
      Section {
        Button {
          showPaywall = true
        } label: {
          HStack {
            Text("Joodle Entries")
            Spacer()
            Text("\(currentJoodleCount) / \(SubscriptionManager.freeJoodlesAllowed)")
              .foregroundStyle(
                currentJoodleCount >= SubscriptionManager.freeJoodlesAllowed ? .red :
                    .secondary
              )
              .font(.system(size: 14))
          }
        }
        .foregroundStyle(.primary)

        Button {
          showPaywall = true
        } label: {
          HStack {
            Text("Anniversary Reminders")
            Spacer()
            Text("\(reminderManager.reminders.count) / 5")
              .foregroundStyle(
                reminderManager.hasReachedFreeLimit ? .red : .secondary
              )
              .font(.system(size: 14))
          }
        }
        .foregroundStyle(.primary)
      } header: {
        Text("Free Plan Limits")
      } footer: {
        HStack (spacing: 8) {
          Text("Unlock unlimited access with Joodle Pro")
          PremiumFeatureBadge()
        }
      }
    }
  }

  @State private var showExperimentalFeatures = false

  @ViewBuilder
  private var labSection: some View {
    Section {
      Button {
        showExperimentalFeatures = true
      } label: {
        HStack {
          Label {
            Text("Experimental Features")
          } icon: {
            Image(systemName: "flask.fill")
              .foregroundStyle(.primary)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .foregroundColor(.primary)
    } header: {
      Text("Labs")
    }
  }

  @ViewBuilder
  private var subscriptionSection: some View {
    Section {
      if subscriptionManager.isSubscribed {
        // Detailed subscription status card
        Button {
          showSubscriptions = true
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                  .foregroundStyle(.appAccent)
                  .font(.body)
                Text("Joodle Pro")
                  .font(.headline)
                  .foregroundColor(.primary)
              }
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if let statusMessage = subscriptionManager.subscriptionStatusMessage {
              // Trial or cancellation status
              Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
              // Active subscription with no issues
              Text("You have full access to all features")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .padding(.vertical, 4)
        }
      } else {
        // No subscription - show simple upgrade button
        Button {
          showPaywall = true
        } label: {
          HStack {
            HStack {
              HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                  .foregroundStyle(.appAccent)
                  .font(.body)
                Text("Unlock Joodle Pro")
              }
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .foregroundColor(.primary)
      }

      // Redeem Promo Code - available for all users
      Button {
        showRedeemCode = true
      } label: {
        HStack {
          HStack {
            HStack(spacing: 4) {
              Image(systemName: "ticket.fill")
                .foregroundStyle(.primary)
                .font(.body)
              Text("Redeem Promo Code")
            }
          }
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .foregroundColor(.primary)
    } header: {
      Text("Membership")
    }
    .offerCodeRedemption(isPresented: $showRedeemCode) {_ in
      // Refresh subscription status after redemption
      Task {
        await storeKitManager.updatePurchasedProducts()
        await subscriptionManager.updateSubscriptionStatus()
      }
    }
  }

  @ViewBuilder
  private var dataManagementSection: some View {
    Section {
      NavigationLink {
        iCloudSyncView()
      } label: {
        HStack {
          Text("Sync to iCloud")
          Spacer()

          // Show premium badge if not subscribed
          if !subscriptionManager.hasICloudSync {
            PremiumFeatureBadge()
          } else if needsRestartForSync {
            // Show restart required warning
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
              .font(.caption)
          } else if cloudSyncManager.isSyncing && subscriptionManager.hasICloudSync {
            // Show syncing indicator
            HStack(spacing: 6) {
              Text("Syncing")
                .font(.caption)
                .foregroundStyle(.secondary)
              ProgressView()
                .scaleEffect(0.6)
            }
          } else if !cloudSyncManager.canSync {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.red)
              .font(.caption)
          } else if userPreferences.isCloudSyncEnabled && CloudSyncManager.shared.isCloudAvailable {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .font(.caption)
          }
        }
      }
      Button(action: { exportData() }) {
        Text("Backup Locally")
      }

      Button(action: { showFileImporter = true }) {
        Text("Restore From Local Backup")
      }
    } header: {
      Text("Data Management")
    }
  }

  /// Returns true if the app is running in a non-production environment (Debug or TestFlight)
  /// Uses AppEnvironment for consistency across the app
  private var isNonProductionEnvironment: Bool {
    !AppEnvironment.isAppStore
  }

  /// Returns true if the app is running in a production App Store environment
  private var isProductionEnvironment: Bool {
    AppEnvironment.isAppStore
  }

  /// Returns true if we're simulating production but not actually in production
  private var isSimulatingProduction: Bool {
    AppEnvironment.isSimulatingProduction
  }

  @ViewBuilder
  private var contactUsMailURL: URL? {
    let email = "joodle@liyuxuan.dev"
    let subject = "Feedback on Joodle"
    let iOSVersion = UIDevice.current.systemVersion
    let body = "\n\n\n\n\nJoodle \(AppEnvironment.fullVersionString) - iOS \(iOSVersion)\nID: \(deviceIdentifier)"

    let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    return URL(string: "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)")
  }


  private var needHelpSection: some View {
    Section {
      NavigationLink {
        ChangelogListView()
      } label: {
        HStack {
          Image(systemName: "sparkles")
            .foregroundColor(.primary)
            .frame(width: 24)
          Text("What's New")
            .foregroundColor(.primary)
        }
      }

      NavigationLink {
        LearnCoreFeaturesView()
      } label: {
        HStack {
          Image(systemName: "book.fill")
            .foregroundColor(.primary)
            .frame(width: 24)
          Text("Learn Core Features")
            .foregroundColor(.primary)
        }
      }

      NavigationLink {
        FaqView()
      } label: {
        HStack {
          Image(systemName: "questionmark.circle.fill")
            .foregroundColor(.primary)
            .frame(width: 24)
          Text("Frequently Asked Questions")
            .foregroundColor(.primary)
        }
      }

      if let mailURL = contactUsMailURL {
        Link(destination: mailURL) {
          HStack {
            Image(systemName: "envelope.fill")
              .foregroundColor(.primary)
              .frame(width: 24)
            Text("Contact Us")
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "arrow.up.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    } header: {
      Text("Need Help?")
    }
  }

  @ViewBuilder
  private var onboardingSection: some View {
    if isNonProductionEnvironment {
      Section {
        Button("Revisit Onboarding") {
          showOnboarding = true
        }
      } header: {
        Text("Onboarding")
      } footer: {
        Text("Revisit Onboarding is only available in beta builds.")
      }
    }
  }

  @ViewBuilder
  private var feedbackSection: some View {
    // Community & Social Section
    Section {
      Link(destination: URL(string: "https://discord.gg/WnQSdZqBjk")!) {
        HStack {
          Image("Social/discord")
            .resizable()
            .scaledToFit()
            .frame(width: 24)
          Text("Join Discord Community")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Link(destination: URL(string: "https://x.com/xmliszt")!) {
        HStack {
          Image("Social/twitter")
            .resizable()
            .scaledToFit()
            .frame(width: 24)
          Text("Follow on X")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Link(destination: URL(string: "https://liyuxuan.dev/apps/joodle")!) {
        HStack {
          Image(systemName: "globe.americas.fill")
            .foregroundColor(.primary)
            .frame(width: 24)
          Text("Visit Developer Website")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      /// Sandbox: TestFlight feedback
      /// Production: Submit a review
      Button {
        openFeedback()
      } label: {
        HStack {
          Image(systemName: AppEnvironment.feedbackButtonIcon)
            .foregroundColor(.primary)
            .frame(width: 24)
          Text(AppEnvironment.feedbackButtonTitle)
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      /// External notion form to collection production feedback
      if isProductionEnvironment {
        Link(destination: URL(string: "https://tinyurl.com/joodle-feedback")!) {
          HStack {
            Image(systemName: "bubble.left.and.bubble.right.fill")
              .foregroundColor(.primary)
              .frame(width: 24)
            Text("Submit Your Feedback")
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "arrow.up.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      /// Recommend Joodle
      Button {
        showShareSheet = true
      } label: {
        HStack {
          Image(systemName: "heart.fill")
            .foregroundColor(.primary)
            .frame(width: 24)
          Text("Recommend Joodle")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "square.and.arrow.up")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .sheet(isPresented: $showShareSheet) {
        let shareText = "Hey! I've found a gem journaling app that allows you to draw your days! Joodle, that's what it's called, is made for people like you and I. Check it out here:"
        let shareURL = URL(string: "https://liyuxuan.dev/apps/joodle")!
        ShareSheet(items: [shareText, shareURL])
      }

    } header: {
      Text("Get Involved")
    }

    // Legal Section
    Section {
      Link(destination: URL(string: "https://liyuxuan.dev/apps/joodle/privacy-policy")!) {
        HStack {
          Image(systemName: "hand.raised.fill")
            .foregroundColor(.primary)
            .frame(width: 24)
          Text("Privacy Policy")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Link(destination: URL(string: "https://liyuxuan.dev/apps/joodle/terms-of-service")!) {
        HStack {
          Image(systemName: "text.document.fill")
            .foregroundColor(.primary)
            .frame(width: 24)
          Text("Terms of Service")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    } header: {
      Text("Legal")
    }

    // App Branding Footer
    Section {
      EmptyView()
    } footer: {
      VStack(spacing: 8) {
        // Logo and App Name
        HStack(spacing: 8) {
          Image("LaunchIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          Text("Joodle")
            .font(.title2)
            .fontWeight(.semibold)
          + Text("®")
            .font(.caption)
            .fontWeight(.semibold)
            .baselineOffset(10)
        }

        // Version
        Text("VERSION \(AppEnvironment.fullVersionString)")
          .font(.caption)
          .foregroundStyle(.secondary)

        // Copyright
        Text("© \(currentYear) Li Yuxuan. All Rights Reserved.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 16)
      .onLongPressGesture {
        showDeviceIdentifierAlert = true
      }
      .alert("Share identifier with joodle@liyuxuan.dev to help debug purchase issues:", isPresented: $showDeviceIdentifierAlert) {
        Button("Copy to Clipboard") {
          UIPasteboard.general.string = deviceIdentifier
        }
        Button("Cancel", role: .cancel) { }
      } message: {
        Text(deviceIdentifier)
      }
    }
  }

  private var currentYear: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return formatter.string(from: Date())
  }

  private var deviceIdentifier: String {
    let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    let appId = Bundle.main.bundleIdentifier ?? "Unknown"
    return "\(vendorId):\(appId)"
  }

  @ViewBuilder
  private var developerOptionsSection: some View {
    if AppEnvironment.isDebug && !simulateProductionEnvironment {
      Section {
        Button("App Stats") {
          showAppStats = true
        }
        Button("Data Seeder") {
          showDataSeeder = true
        }
        Button("Generate Placeholder") {
          showPlaceholderGenerator = true
        }
        Button("Clear iCloud KVS (Sync History)", role: .destructive) {
          let cloudStore = NSUbiquitousKeyValueStore.default
          cloudStore.removeObject(forKey: "is_cloud_sync_enabled_backup")
          cloudStore.removeObject(forKey: "cloud_sync_was_enabled")
          cloudStore.synchronize()
          print("DEBUG: iCloud KVS sync history cleared!")
        }

        Button("Reset Changelog State") {
          ChangelogManager.shared.resetChangelogState()
          print("DEBUG: Changelog state reset - will show on next launch")
        }

        Toggle("Simulate Production Environment", isOn: Binding(
          get: { AppEnvironment.simulateProductionEnvironment },
          set: { newValue in
            AppEnvironment.simulateProductionEnvironment = newValue
            simulateProductionEnvironment = newValue
          }
        ))
      } header: {
        Text("Developer Options")
      } footer: {
        Text("When enabled, the app will behave as if it's running in production (App Store release).")
      }

      Section("Subscription Testing") {
        HStack {
          Text("App Status")
          Spacer()
          Text(subscriptionManager.isSubscribed ? "Subscribed ✓" : "Free")
            .foregroundColor(subscriptionManager.isSubscribed ? .green : .secondary)
        }

        Button("Subscription Testing Console") {
          showSubscriptionTesting = true
        }
      }
      .sheet(isPresented: $showSubscriptionTesting) {
        SubscriptionTestingView()
      }
    }

    // Exit simulation button - only shows when simulating production in a non-production environment
    if isSimulatingProduction {
      Section {
        Button("Exit Production Simulation") {
          AppEnvironment.simulateProductionEnvironment = false
          simulateProductionEnvironment = false
        }
        .foregroundColor(.orange)
      } footer: {
        Text("You are currently simulating production environment. Tap to return to development mode.")
      }
    }
  }

  // MARK: - Feedback Helper

  private func openFeedback() {
    guard let url = AppEnvironment.feedbackURL else { return }

    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url)
    } else {
      // Fallback: If TestFlight URL doesn't work, try opening App Store
      if let appStoreURL = AppEnvironment.appStoreReviewURL {
        UIApplication.shared.open(appStoreURL)
      }
    }
  }

  private func exportData() {
    let container = modelContext.container
    Task.detached {
      do {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DayEntry>()
        let entries = try context.fetch(descriptor)
        let dtos = entries.map { entry in
          DayEntryDTO(
            body: entry.body,
            createdAt: entry.createdAt,
            dateString: entry.dateString,
            drawingData: entry.drawingData,
            drawingThumbnail20: entry.drawingThumbnail20,
            drawingThumbnail200: entry.drawingThumbnail200
          )
        }
        let data = try JSONEncoder().encode(dtos)

        await MainActor.run {
          exportDocument = JSONDocument(data: data)
          showFileExporter = true
        }
      } catch {
        print("Failed to prepare export: \(error)")
      }
    }
  }

  private func importData(from url: URL) {
    let container = modelContext.container
    Task.detached {
      guard url.startAccessingSecurityScopedResource() else { return }
      defer { url.stopAccessingSecurityScopedResource() }

      do {
        let data = try Data(contentsOf: url)
        let dtos = try JSONDecoder().decode([DayEntryDTO].self, from: data)
        let context = ModelContext(container)

        var importedCount = 0
        var mergedCount = 0
        var skippedCount = 0
        for dto in dtos {
          // Skip empty entries (no text and no drawing)
          let dtoHasContent = !dto.body.isEmpty || (dto.drawingData != nil && !dto.drawingData!.isEmpty)
          if !dtoHasContent {
            skippedCount += 1
            continue
          }

          // Use findOrCreate to get or create the single entry for this date
          let entry = DayEntry.findOrCreate(for: dto.createdAt, in: context)

          let hadContent = !entry.body.isEmpty || (entry.drawingData != nil && !entry.drawingData!.isEmpty)

          // Merge imported data into existing entry
          if entry.body.isEmpty && !dto.body.isEmpty {
            entry.body = dto.body
          } else if !entry.body.isEmpty && !dto.body.isEmpty && entry.body != dto.body {
            // Both have text - append imported text
            entry.body = entry.body + "\n\n---\n\n" + dto.body
          }

          // Import drawing if entry doesn't have one
          if (entry.drawingData == nil || entry.drawingData?.isEmpty == true) && dto.drawingData != nil {
            entry.drawingData = dto.drawingData
            entry.drawingThumbnail20 = dto.drawingThumbnail20
            entry.drawingThumbnail200 = dto.drawingThumbnail200
          }

          if hadContent {
            mergedCount += 1
          } else {
            importedCount += 1
          }
        }

        try context.save()
        await MainActor.run {
          importMessage = "Imported \(importedCount) new entries, merged \(mergedCount) existing entries. Skipped \(skippedCount) empty entries."
          showImportAlert = true
        }
      } catch {
        await MainActor.run {
          importMessage = "Import failed: \(error.localizedDescription)"
          showImportAlert = true
        }
      }
    }
  }
}

struct DayEntryDTO: Codable {
  let body: String
  let createdAt: Date
  let dateString: String?  // Optional for backward compatibility with old exports
  let drawingData: Data?
  let drawingThumbnail20: Data?
  let drawingThumbnail200: Data?

  // Support importing old exports that had all three thumbnail sizes
  enum CodingKeys: String, CodingKey {
    case body, createdAt, dateString, drawingData
    case drawingThumbnail20
    case drawingThumbnail200
    case drawingThumbnail1080  // Legacy, ignored on import
  }

  init(body: String, createdAt: Date, dateString: String?, drawingData: Data?, drawingThumbnail20: Data?, drawingThumbnail200: Data?) {
    self.body = body
    self.createdAt = createdAt
    self.dateString = dateString
    self.drawingData = drawingData
    self.drawingThumbnail20 = drawingThumbnail20
    self.drawingThumbnail200 = drawingThumbnail200
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    body = try container.decode(String.self, forKey: .body)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    dateString = try container.decodeIfPresent(String.self, forKey: .dateString)
    drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData)
    drawingThumbnail20 = try container.decodeIfPresent(Data.self, forKey: .drawingThumbnail20)
    drawingThumbnail200 = try container.decodeIfPresent(Data.self, forKey: .drawingThumbnail200)
    // Legacy 1080 field is decoded but ignored
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(body, forKey: .body)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encodeIfPresent(dateString, forKey: .dateString)
    try container.encodeIfPresent(drawingData, forKey: .drawingData)
    try container.encodeIfPresent(drawingThumbnail20, forKey: .drawingThumbnail20)
    try container.encodeIfPresent(drawingThumbnail200, forKey: .drawingThumbnail200)
  }
}

// MARK: - App Stats View (Developer Tool)
struct AppStatsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.cloudSyncManager) private var cloudSyncManager
  @Environment(\.dismiss) private var dismiss
  @StateObject private var subscriptionManager = SubscriptionManager.shared

  @State private var totalEntries: Int = 0
  @State private var uniqueDateCount: Int = 0
  @State private var duplicateCount: Int = 0
  @State private var duplicateDetails: [String: Int] = [:]
  @State private var isCleaningDuplicates = false
  @State private var isCleaningEmpty = false
  @State private var cleanupResult: String?

  // Debug info
  @State private var entriesByYear: [Int: Int] = [:]
  @State private var entriesWithDrawing: Int = 0
  @State private var entriesWithText: Int = 0
  @State private var entriesEmpty: Int = 0
  @State private var entriesWithEmptyDateString: Int = 0

  var body: some View {
    NavigationStack {
      List {
        // MARK: - Entry Stats
        Section("Entry Statistics") {
          HStack {
            Text("Total Entries")
            Spacer()
            Text("\(totalEntries)")
              .foregroundStyle(.secondary)
          }

          HStack {
            Text("Unique Dates")
            Spacer()
            Text("\(uniqueDateCount)")
              .foregroundStyle(.secondary)
          }

          HStack {
            Text("Dates with Duplicates")
            Spacer()
            Text("\(duplicateCount)")
              .foregroundStyle(duplicateCount > 0 ? .red : .green)
          }

          if totalEntries != uniqueDateCount {
            Text("⚠️ Entry count (\(totalEntries)) differs from unique dates (\(uniqueDateCount)) - duplicates exist!")
              .font(.caption)
              .foregroundStyle(.orange)
          }

          if !duplicateDetails.isEmpty {
            DisclosureGroup("Duplicate Details") {
              ForEach(duplicateDetails.sorted(by: { $0.key > $1.key }), id: \.key) { dateString, count in
                HStack {
                  Text(dateString)
                    .font(.caption)
                  Spacer()
                  Text("\(count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }

          if duplicateCount > 0 {
            Button(role: .destructive) {
              clearDuplicates()
            } label: {
              HStack {
                if isCleaningDuplicates {
                  ProgressView()
                    .scaleEffect(0.8)
                }
                Text("Clear Duplicate Entries")
              }
            }
            .disabled(isCleaningDuplicates)
          }

          if let result = cleanupResult {
            Text(result)
              .font(.caption)
              .foregroundStyle(.green)
          }

          Button("Print Debug Info to Console") {
            printDetailedDebugInfo()
          }
        }

        // MARK: - Debug Breakdown
        Section("Entry Breakdown") {
          HStack {
            Text("With Drawing")
            Spacer()
            Text("\(entriesWithDrawing)")
              .foregroundStyle(.secondary)
          }

          HStack {
            Text("With Text Only")
            Spacer()
            Text("\(entriesWithText)")
              .foregroundStyle(.secondary)
          }

          HStack {
            Text("Empty (no content)")
            Spacer()
            Text("\(entriesEmpty)")
              .foregroundStyle(entriesEmpty > 0 ? .orange : .secondary)
          }

          if entriesEmpty > 0 {
            Button(role: .destructive) {
              deleteEmptyEntries()
            } label: {
              HStack {
                if isCleaningEmpty {
                  ProgressView()
                    .scaleEffect(0.8)
                }
                Text("Delete \(entriesEmpty) Empty Entries")
              }
            }
            .disabled(isCleaningEmpty)
          }

          HStack {
            Text("Empty dateString")
            Spacer()
            Text("\(entriesWithEmptyDateString)")
              .foregroundStyle(entriesWithEmptyDateString > 0 ? .red : .secondary)
          }

          if !entriesByYear.isEmpty {
            DisclosureGroup("Entries by Year") {
              ForEach(entriesByYear.sorted(by: { $0.key > $1.key }), id: \.key) { year, count in
                HStack {
                  Text("\(year)")
                    .font(.caption)
                  Spacer()
                  Text("\(count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
        }

        // MARK: - Subscription Status
        Section("Subscription Status") {
          HStack {
            Text("Is Subscribed")
            Spacer()
            Text(subscriptionManager.isSubscribed ? "Yes" : "No")
              .foregroundStyle(subscriptionManager.isSubscribed ? .green : .secondary)
          }

          HStack {
            Text("In Trial Period")
            Spacer()
            Text(subscriptionManager.isInTrialPeriod ? "Yes" : "No")
              .foregroundStyle(subscriptionManager.isInTrialPeriod ? .blue : .secondary)
          }

          HStack {
            Text("Will Auto Renew")
            Spacer()
            Text(subscriptionManager.willAutoRenew ? "Yes" : "No")
              .foregroundStyle(.secondary)
          }

          if let expirationDate = subscriptionManager.subscriptionExpirationDate {
            HStack {
              Text("Expiration Date")
              Spacer()
              Text(expirationDate, style: .date)
                .foregroundStyle(.secondary)
            }
          }

          HStack {
            Text("Has iCloud Sync Feature")
            Spacer()
            Text(subscriptionManager.hasICloudSync ? "Yes" : "No")
              .foregroundStyle(subscriptionManager.hasICloudSync ? .green : .secondary)
          }
        }

        // MARK: - iCloud Sync Status
        Section("iCloud Sync Status") {
          HStack {
            Text("System iCloud Enabled")
            Spacer()
            Text(cloudSyncManager.isSystemCloudEnabled ? "Yes" : "No")
              .foregroundStyle(cloudSyncManager.isSystemCloudEnabled ? .green : .red)
          }

          HStack {
            Text("CloudKit Available")
            Spacer()
            Text(cloudSyncManager.isCloudAvailable ? "Yes" : "No")
              .foregroundStyle(cloudSyncManager.isCloudAvailable ? .green : .red)
          }

          HStack {
            Text("Is Currently Syncing")
            Spacer()
            if cloudSyncManager.isSyncing {
              HStack(spacing: 4) {
                ProgressView()
                  .scaleEffect(0.7)
                Text("Yes")
                  .foregroundStyle(.blue)
              }
            } else {
              Text("No")
                .foregroundStyle(.secondary)
            }
          }

          if !cloudSyncManager.syncProgress.isEmpty {
            HStack {
              Text("Sync Progress")
              Spacer()
              Text(cloudSyncManager.syncProgress)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          HStack {
            Text("Has Sync Error")
            Spacer()
            Text(cloudSyncManager.hasError ? "Yes" : "No")
              .foregroundStyle(cloudSyncManager.hasError ? .red : .green)
          }

          if let errorMessage = cloudSyncManager.errorMessage {
            VStack(alignment: .leading, spacing: 4) {
              Text("Error Message")
                .font(.caption)
              Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
            }
          }

          if let lastImport = cloudSyncManager.lastObservedImport {
            HStack {
              Text("Last Import")
              Spacer()
              Text(lastImport, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          if let lastExport = cloudSyncManager.lastObservedExport {
            HStack {
              Text("Last Export")
              Spacer()
              Text(lastExport, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .navigationTitle("App Stats")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
      .onAppear {
        loadStats()
      }
    }
  }

  private func loadStats() {
    // Fetch total entries and unique date count
    totalEntries = DuplicateEntryCleanup.shared.getTotalEntryCount(modelContext: modelContext)
    uniqueDateCount = DuplicateEntryCleanup.shared.getUniqueDateCount(modelContext: modelContext)

    // Check for duplicates
    duplicateCount = DuplicateEntryCleanup.shared.checkDuplicateCount(modelContext: modelContext)
    duplicateDetails = DuplicateEntryCleanup.shared.getDuplicateDetails(modelContext: modelContext)

    // Load debug breakdown
    loadDebugBreakdown()
  }

  private func loadDebugBreakdown() {
    let descriptor = FetchDescriptor<DayEntry>()
    do {
      let allEntries = try modelContext.fetch(descriptor)

      var byYear: [Int: Int] = [:]
      var withDrawing = 0
      var withText = 0
      var empty = 0
      var emptyDateString = 0

      for entry in allEntries {
        // Count by year
        let year = entry.year
        byYear[year, default: 0] += 1

        // Count by content type
        let hasDrawing = entry.drawingData != nil && !entry.drawingData!.isEmpty
        let hasText = !entry.body.isEmpty

        if hasDrawing {
          withDrawing += 1
        }
        if hasText && !hasDrawing {
          withText += 1
        }
        if !hasDrawing && !hasText {
          empty += 1
        }
        if entry.dateString.isEmpty {
          emptyDateString += 1
        }
      }

      entriesByYear = byYear
      entriesWithDrawing = withDrawing
      entriesWithText = withText
      entriesEmpty = empty
      entriesWithEmptyDateString = emptyDateString

    } catch {
      print("Failed to load debug breakdown: \(error)")
    }
  }

  private func printDetailedDebugInfo() {
    let descriptor = FetchDescriptor<DayEntry>()
    do {
      let allEntries = try modelContext.fetch(descriptor)

      print("========== DETAILED ENTRY DEBUG ==========")
      print("Total entries in database: \(allEntries.count)")
      print("")

      // Group by dateString
      var byDateString: [String: [DayEntry]] = [:]
      for entry in allEntries {
        let key = entry.dateString.isEmpty ? "(empty)" : entry.dateString
        byDateString[key, default: []].append(entry)
      }

      print("Unique dateStrings: \(byDateString.count)")
      print("")

      // Print entries sorted by dateString
      for (dateString, entries) in byDateString.sorted(by: { $0.key > $1.key }) {
        let hasDrawing = entries.first?.drawingData != nil && !(entries.first?.drawingData?.isEmpty ?? true)
        let hasText = !(entries.first?.body.isEmpty ?? true)
        let contentType = hasDrawing ? "🎨" : (hasText ? "📝" : "⬜️")

        if entries.count > 1 {
          print("⚠️ DUPLICATE: \(dateString) - \(entries.count) entries \(contentType)")
          for (idx, entry) in entries.enumerated() {
            print("   [\(idx)] createdAt: \(entry.createdAt), body: \(entry.body.prefix(20))..., hasDrawing: \(entry.drawingData != nil)")
          }
        } else {
          print("\(contentType) \(dateString) - createdAt: \(entries.first?.createdAt ?? Date())")
        }
      }

      print("")
      print("========== YEAR BREAKDOWN ==========")
      var yearCounts: [Int: Int] = [:]
      for entry in allEntries {
        yearCounts[entry.year, default: 0] += 1
      }
      for (year, count) in yearCounts.sorted(by: { $0.key > $1.key }) {
        print("\(year): \(count) entries")
      }

      print("")
      print("========== CONTENT BREAKDOWN ==========")
      let withDrawing = allEntries.filter { $0.drawingData != nil && !$0.drawingData!.isEmpty }.count
      let withTextOnly = allEntries.filter { ($0.drawingData == nil || $0.drawingData!.isEmpty) && !$0.body.isEmpty }.count
      let empty = allEntries.filter { ($0.drawingData == nil || $0.drawingData!.isEmpty) && $0.body.isEmpty }.count
      print("With drawing: \(withDrawing)")
      print("With text only: \(withTextOnly)")
      print("Empty: \(empty)")

      print("")
      print("========== END DEBUG ==========")

    } catch {
      print("Failed to print debug info: \(error)")
    }
  }

  private func clearDuplicates() {
    isCleaningDuplicates = true
    cleanupResult = nil

    // Use forceCleanupDuplicates to run regardless of previous cleanup flag
    let result = DuplicateEntryCleanup.shared.forceCleanupDuplicates(modelContext: modelContext, markAsCompleted: false)

    cleanupResult = "Merged: \(result.merged), Deleted: \(result.deleted)"
    isCleaningDuplicates = false

    // Reload stats
    loadStats()
  }

  private func deleteEmptyEntries() {
    isCleaningEmpty = true

    let descriptor = FetchDescriptor<DayEntry>()
    do {
      let allEntries = try modelContext.fetch(descriptor)
      var deletedCount = 0

      for entry in allEntries {
        let hasDrawing = entry.drawingData != nil && !entry.drawingData!.isEmpty
        let hasText = !entry.body.isEmpty

        if !hasDrawing && !hasText {
          modelContext.delete(entry)
          deletedCount += 1
        }
      }

      if deletedCount > 0 {
        try modelContext.save()
        print("Deleted \(deletedCount) empty entries")
        cleanupResult = "Deleted \(deletedCount) empty entries"
      }
    } catch {
      print("Failed to delete empty entries: \(error)")
      cleanupResult = "Failed: \(error.localizedDescription)"
    }

    isCleaningEmpty = false
    loadStats()
  }
}

struct JSONDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  var data: Data

  init(data: Data) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    self.data = data
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let file = FileWrapper(regularFileWithContents: data)
    return file
  }
}

// MARK: - Learn Core Features View
struct LearnCoreFeaturesView: View {
  @StateObject private var subscriptionManager = SubscriptionManager.shared
  @State private var selectedTutorialStep: TutorialStepType?

  var body: some View {
    List {
      // Interactive tutorials
      Section {
        ForEach(TutorialStepType.allCases) { stepType in
          Button {
            selectedTutorialStep = stepType
          } label: {
            HStack {
              Label(stepType.title, systemImage: stepType.icon)
                .foregroundColor(.textColor)
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondaryTextColor)
            }
          }
        }
      } header: {
        Text("Interactive Tutorials")
      }

      // Static widget tutorials
      Section {
        ForEach(TutorialDefinitions.widgetTutorials) { tutorial in
          NavigationLink {
            TutorialView(
              title: tutorial.title,
              screenshots: tutorial.screenshots,
              description: tutorial.description
            )
          } label: {
            HStack {
              Label(tutorial.title, systemImage: tutorial.icon)
                .foregroundColor(.primary)
              Spacer()
              if !subscriptionManager.isSubscribed && tutorial.isPremiumFeature {
                PremiumFeatureBadge()
              }
            }
          }
        }
      } header: {
        Text("Widget Tutorials")
      }

      // Static other tutorials
      Section {
        ForEach(TutorialDefinitions.otherTutorials) { tutorial in
          NavigationLink {
            TutorialView(
              title: tutorial.title,
              screenshots: tutorial.screenshots,
              description: tutorial.description
            )
          } label: {
            HStack {
              Label(tutorial.title, systemImage: tutorial.icon)
                .foregroundColor(.primary)
              Spacer()
              if !subscriptionManager.isSubscribed && tutorial.isPremiumFeature {
                PremiumFeatureBadge()
              }
            }
          }
        }
      }
    }
    .navigationTitle("Learn Core Features")
    .navigationBarTitleDisplayMode(.inline)
    .fullScreenCover(item: $selectedTutorialStep) { stepType in
      InteractiveTutorialView(stepType: stepType) {
        selectedTutorialStep = nil
      }
    }
  }
}

#if DEBUG
struct DebugDataSeederView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var selectedYear = 2024
  @State private var seedCount = 10
  @State private var currentDebugCount = 0
  @State private var isSeeding = false

  var body: some View {
    NavigationStack {
      Form {
        Section("Current Status") {
          HStack {
            Text("Seeded Entries (≤2024)")
            Spacer()
            Text("\(currentDebugCount)")
              .foregroundStyle(.secondary)
          }
        }

        Section("Seed Data") {
          Picker("Year", selection: $selectedYear) {
            ForEach((2020...2024).reversed(), id: \.self) { year in
              Text(String(year)).tag(year)
            }
          }

          HStack {
            Text("Count")
            Spacer()
            TextField("Count", value: $seedCount, format: .number)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .frame(width: 80)

            Button("MAX") {
              seedCount = DebugDataSeeder.shared.daysInYear(selectedYear)
            }
            .buttonStyle(.bordered)
            .font(.caption)
          }

          Button("Seed \(seedCount) Entries for \(selectedYear)") {
            seedData()
          }
          .disabled(isSeeding)
        }

        Section("Danger Zone") {
          Button("Clear All Seeded Data", role: .destructive) {
            clearData()
          }
          .disabled(isSeeding)
        }
      }
      .navigationTitle("Data Seeder")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
      .onAppear {
        refreshCount()
      }
    }
  }

  private func refreshCount() {
    currentDebugCount = DebugDataSeeder.shared.getDebugEntryCount(container: modelContext.container)
  }

  private func seedData() {
    isSeeding = true
    Task {
      await DebugDataSeeder.shared.seedEntries(
        for: selectedYear, count: seedCount, container: modelContext.container)
      refreshCount()
      isSeeding = false
    }
  }

  private func clearData() {
    isSeeding = true
    Task {
      await DebugDataSeeder.shared.clearAllDebugData(container: modelContext.container)
      refreshCount()
      isSeeding = false
    }
  }
}
#endif

#Preview {
  NavigationStack {
    SettingsView()
      .environment(\.userPreferences, UserPreferences.shared)
  }
}

#Preview("App Stats") {
  AppStatsView()
}
