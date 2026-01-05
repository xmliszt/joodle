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

// MARK: - Settings Icon View
struct SettingsIconView: View {
  let systemName: String
  let backgroundColor: Color

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(.white)
      .frame(width: 28, height: 28)
      .background(backgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}

// MARK: - Settings Row View
struct SettingsRowView: View {
  let icon: String
  let iconColor: Color
  let title: String
  var trailingText: String? = nil
  var trailingView: AnyView? = nil
  var isExternal: Bool = false

  var body: some View {
    HStack {
      SettingsIconView(systemName: icon, backgroundColor: iconColor)
      Text(title)
        .foregroundColor(.primary)
      Spacer()
      if let text = trailingText {
        Text(text)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      if let view = trailingView {
        view
      }
      if isExternal {
        Image(systemName: "arrow.up.right")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
}

// MARK: - Membership Banner View (Reusable Component)

struct MembershipBannerView: View {
  let isSubscribed: Bool
  let statusMessage: String?
  let joodleCount: Int
  let alarmCount: Int
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      ZStack(alignment: .topLeading) {
        // Background image (1200x600 = 2:1 aspect ratio)
        Image(isSubscribed ? "Others/Pro Banner" : "Others/Free Banner")
          .resizable()
          .aspectRatio(2/1, contentMode: .fit)

        // Content overlay - positioned at top to avoid mushroom glow at bottom
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(isSubscribed ? "Joodle Pro" : "Unlock Joodle Pro")
              .font(.headline)
              .fontWeight(.bold)
              .foregroundColor(isSubscribed ? .white : .black)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundColor(isSubscribed ? .white.opacity(0.8) : .black.opacity(0.8))
          }

          if isSubscribed {
            if let statusMessage = statusMessage {
              Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            } else {
              Text("Thanks for supporting Joodle!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            }
          } else {
            HStack(spacing: 16) {
              HStack(spacing: 4) {
                Image(systemName: "doc.text")
                  .font(.caption)
                Text("\(joodleCount)/\(SubscriptionManager.freeJoodlesAllowed)")
                  .font(.caption)
              }
              .foregroundColor(joodleCount >= SubscriptionManager.freeJoodlesAllowed ? .red : .black.opacity(0.8))

              HStack(spacing: 4) {
                Image(systemName: "bell")
                  .font(.caption)
                Text("\(alarmCount)/5")
                  .font(.caption)
              }
              .foregroundColor(alarmCount >= 5 ? .red : .black.opacity(0.8))
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
      }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
  #if DEBUG
  @State private var showDataSeeder = false
  #endif
  @State private var currentJoodleCount: Int = 0

  @State private var showSubscriptionTesting = false
  @State private var showRedeemCode = false
  @State private var showFaq = false
  @State private var showShareSheet = false
  @State private var showDeviceIdentifierAlert = false
  #if DEBUG
  @State private var showBannerPreview = false
  #endif

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

  // Navigation state for sub-pages
  @State private var showExperimentalFeatures = false

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
      if isNonProductionEnvironment {
        betaTesterSection
      }
      membershipBannerSection
      generalSection
      labSection
      externalSettingsSection
      needHelpSection
      getInvolvedSection
      legalSection
      footerSection
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
        .id(color)
      }
    }
    .onChange(of: userPreferences.preferredColorScheme) { _, _ in
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
    .offerCodeRedemption(isPresented: $showRedeemCode) { _ in
      Task {
        await storeKitManager.updatePurchasedProducts()
        await subscriptionManager.updateSubscriptionStatus()
      }
    }
    .onAppear {
      Task {
        await StoreKitManager.shared.updatePurchasedProducts()
        await subscriptionManager.updateSubscriptionStatus()
        if !subscriptionManager.isSubscribed {
          currentJoodleCount = subscriptionManager.fetchTotalJoodleCount(in: modelContext)
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidExpire)) { _ in
      Task {
        await subscriptionManager.updateSubscriptionStatus()
      }
    }
  }

  // MARK: - Beta Tester Section
  @ViewBuilder
  private var betaTesterSection: some View {
    Section {
      Link(destination: URL(string: "https://apps.apple.com/sg/app/joodle-journaling-with-doodle/id6756204776")!) {
        HStack {
          if #available(iOS 18.0, *) {
            Image(systemName: "fireworks")
              .font(.system(size: 14, weight: .semibold))
              .frame(width: 28, height: 28)
              .symbolRenderingMode(.palette)
              .symbolEffect(.bounce)
              .foregroundStyle(.accent, .red, .yellow)
              .background(.gray.opacity(0.1))
              .clipShape(RoundedRectangle(cornerRadius: 6))
          } else {
            // Fallback on earlier versions
            Image(systemName: "fireworks")
              .font(.system(size: 14, weight: .semibold))
              .frame(width: 28, height: 28)
              .symbolRenderingMode(.palette)
              .foregroundStyle(.accent, .red, .yellow)
              .background(.gray.opacity(0.1))
              .clipShape(RoundedRectangle(cornerRadius: 6))
          }

          Text("Download in App Store")
            .font(.body.weight(.medium))
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    } footer: {
      Text("Joodle is now available in App Store!")
    }
  }

  // MARK: - Membership Banner Section

  @ViewBuilder
  private var membershipBannerSection: some View {
    Section {
      // Membership Banner - only this should trigger paywall
      MembershipBannerView(
        isSubscribed: subscriptionManager.isSubscribed,
        statusMessage: subscriptionManager.subscriptionStatusMessage,
        joodleCount: currentJoodleCount,
        alarmCount: reminderManager.reminders.count,
        onTap: {
          if subscriptionManager.isSubscribed {
            showSubscriptions = true
          } else {
            showPaywall = true
          }
        }
      )

      // Redeem Promo Code
      Button {
        showRedeemCode = true
      } label: {
        HStack {
          SettingsIconView(systemName: "ticket.fill", backgroundColor: .orange)
          Text("Redeem Promo Code")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      // Tutorial for TestFlight users only - how to redeem promo code
      if isNonProductionEnvironment {
        NavigationLink {
          TutorialView(
            title: TutorialDefinitions.testFlightUserRedeemPromoCode.title,
            screenshots: TutorialDefinitions.testFlightUserRedeemPromoCode.screenshots,
            description: TutorialDefinitions.testFlightUserRedeemPromoCode.description
          )
        } label: {
          HStack {
            SettingsIconView(systemName: TutorialDefinitions.testFlightUserRedeemPromoCode.icon, backgroundColor: .indigo)
            Text("How to Get Promo Code")
              .foregroundColor(.primary)
          }
        }
      }
    }
  }

  // MARK: - General Section

  @ViewBuilder
  private var generalSection: some View {
    Section {
      // iCloud Sync
      NavigationLink {
        iCloudSyncView()
      } label: {
        HStack {
          SettingsIconView(systemName: "icloud.fill", backgroundColor: .cyan)
          Text("iCloud Sync")
            .foregroundColor(.primary)
          Spacer()
          iCloudSyncStatusView
        }
      }

      // Daily Reminder
      NavigationLink {
        DailyReminderSettingsView()
      } label: {
        HStack {
          SettingsIconView(systemName: "bell.fill", backgroundColor: .red)
          Text("Daily Reminder")
            .foregroundColor(.primary)
          Spacer()
          if userPreferences.isDailyReminderEnabled {
            Text(userPreferences.dailyReminderTime.formatted(date: .omitted, time: .shortened))
              .font(.subheadline)
              .foregroundColor(.secondary)
          } else {
            Text("Off")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
      }

      // Anniversary Alarms
      NavigationLink {
        AnniversaryAlarmsSettingsView()
      } label: {
        HStack {
          SettingsIconView(systemName: "alarm.fill", backgroundColor: .orange)
          Text("Anniversary Alarms")
            .foregroundColor(.primary)
          Spacer()
          if !reminderManager.reminders.isEmpty {
            Text("\(reminderManager.reminders.count)")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
      }

      // Customization
      NavigationLink {
        CustomizationSettingsView(
          showPaywall: $showPaywall,
          pendingThemeColor: $pendingThemeColor,
          showThemeOverlay: $showThemeOverlay
        )
      } label: {
        HStack {
          SettingsIconView(systemName: "paintbrush.fill", backgroundColor: .purple)
          Text("Customization")
            .foregroundColor(.primary)
          Spacer()
        }
      }

      // Interactions
      if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
        NavigationLink {
          InteractionsSettingsView()
        } label: {
          HStack {
            SettingsIconView(systemName: "hand.tap.fill", backgroundColor: .blue)
            Text("Interactions")
              .foregroundColor(.primary)
            Spacer()
          }
        }
      }

      // Backup & Restore
      NavigationLink {
        BackupRestoreSettingsView()
      } label: {
        HStack {
          SettingsIconView(systemName: "externaldrive.fill", backgroundColor: .gray)
          Text("Backup & Restore")
            .foregroundColor(.primary)
          Spacer()
        }
      }

      // Announcements
      NavigationLink {
        AnnouncementsSettingsView()
      } label: {
        HStack {
          SettingsIconView(systemName: "megaphone.fill", backgroundColor: .blue)
          Text("Announcements")
            .foregroundColor(.primary)
          Spacer()
          if !userPreferences.announcementsEnabled {
            Text("Off")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
      }
    } header: {
      Text("General")
    }
  }

  @ViewBuilder
  private var iCloudSyncStatusView: some View {
    if !subscriptionManager.hasICloudSync {
      PremiumFeatureBadge()
    } else if needsRestartForSync {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
        .font(.caption)
    } else if cloudSyncManager.isSyncing && subscriptionManager.hasICloudSync {
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

  // MARK: - Labs Section

  @ViewBuilder
  private var labSection: some View {
    Section {
      Button {
        showExperimentalFeatures = true
      } label: {
        HStack {
          SettingsIconView(systemName: "flask.fill", backgroundColor: .purple)
          Text("Experimental Features")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    } header: {
      Text("Labs")
    }
  }

  // MARK: - External Settings Section

  @ViewBuilder
  private var externalSettingsSection: some View {
    Section {
      Button {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
          UIApplication.shared.open(url)
        }
      } label: {
        SettingsRowView(
          icon: "bell.badge.fill",
          iconColor: .red,
          title: "Notifications",
          isExternal: true
        )
      }

      Button {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      } label: {
        SettingsRowView(
          icon: "gear",
          iconColor: .gray,
          title: "App Settings",
          isExternal: true
        )
      }
    } header: {
      Text("External Settings")
    } footer: {
      Text("Manage photos permission, Siri and search, and notification appearance in the system Settings app.")
    }
  }

  // MARK: - Need Help Section

  private var contactUsMailURL: URL? {
    let email = "joodle@liyuxuan.dev"
    let subject = "Feedback on Joodle"
    let iOSVersion = UIDevice.current.systemVersion
    let body = "\n\n\n\n\nJoodle \(AppEnvironment.fullVersionDisplayString) - iOS \(iOSVersion)\nID: \(deviceIdentifier)"

    let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    return URL(string: "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)")
  }

  @ViewBuilder
  private var needHelpSection: some View {
    Section {
      NavigationLink {
        ChangelogListView()
      } label: {
        SettingsRowView(
          icon: "sparkles",
          iconColor: .indigo,
          title: "What's New"
        )
      }

      NavigationLink {
        LearnCoreFeaturesView()
      } label: {
        SettingsRowView(
          icon: "book.fill",
          iconColor: .indigo,
          title: "Learn Core Features"
        )
      }

      NavigationLink {
        FaqView()
      } label: {
        SettingsRowView(
          icon: "questionmark.circle.fill",
          iconColor: .indigo,
          title: "Frequently Asked Questions"
        )
      }

      if let mailURL = contactUsMailURL {
        Link(destination: mailURL) {
          SettingsRowView(
            icon: "envelope.fill",
            iconColor: .indigo,
            title: "Contact Us",
            isExternal: true
          )
        }
      }
    } header: {
      Text("Need Help?")
    }
  }

  // MARK: - Get Involved Section

  /// Returns true if the app is running in a production App Store environment
  private var isProductionEnvironment: Bool {
    AppEnvironment.isAppStore
  }

  @ViewBuilder
  private var getInvolvedSection: some View {
    Section {
      Link(destination: URL(string: "https://discord.gg/WnQSdZqBjk")!) {
        HStack {
          Image("Social/discord")
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6))
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
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6))
          Text("Follow on X")
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Link(destination: URL(string: "https://liyuxuan.dev/apps/joodle")!) {
        SettingsRowView(
          icon: "globe.americas.fill",
          iconColor: .pink,
          title: "Visit Developer Website",
          isExternal: true
        )
      }

      Button {
        openFeedback()
      } label: {
        SettingsRowView(
          icon: AppEnvironment.feedbackButtonIcon,
          iconColor: .pink,
          title: AppEnvironment.feedbackButtonTitle,
          isExternal: true
        )
      }

      if isProductionEnvironment {
        Link(destination: URL(string: "https://tinyurl.com/joodle-feedback")!) {
          SettingsRowView(
            icon: "bubble.left.and.bubble.right.fill",
            iconColor: .pink,
            title: "Submit Your Feedback",
            isExternal: true
          )
        }
      }

      Button {
        showShareSheet = true
      } label: {
        SettingsRowView(
          icon: "heart.fill",
          iconColor: .pink,
          title: "Recommend Joodle",
          trailingView: AnyView(
            Image(systemName: "square.and.arrow.up")
              .font(.caption)
              .foregroundColor(.secondary)
          )
        )
      }
      .sheet(isPresented: $showShareSheet) {
        let shareText = "Hey! I've found a gem journaling app that allows you to draw your days! Joodle, that's what it's called, is made for people like you and I. Check it out here:"
        let shareURL = URL(string: "https://apps.apple.com/sg/app/joodle-journaling-with-doodle/id6756204776")!
        ShareSheet(items: [shareText, shareURL])
      }
    } header: {
      Text("Get Involved")
    }
  }

  // MARK: - Legal Section

  @ViewBuilder
  private var legalSection: some View {
    Section {
      Link(destination: URL(string: "https://liyuxuan.dev/apps/joodle/privacy-policy")!) {
        SettingsRowView(
          icon: "hand.raised.fill",
          iconColor: .gray,
          title: "Privacy Policy",
          isExternal: true
        )
      }

      Link(destination: URL(string: "https://liyuxuan.dev/apps/joodle/terms-of-service")!) {
        SettingsRowView(
          icon: "doc.text.fill",
          iconColor: .gray,
          title: "Terms of Service",
          isExternal: true
        )
      }
    } header: {
      Text("Legal")
    }
  }

  // MARK: - Footer Section

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
  private var footerSection: some View {
    Section {
      EmptyView()
    } footer: {
      VStack(spacing: 8) {
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

        Text("VERSION \(AppEnvironment.fullVersionDisplayString)")
          .font(.caption)
          .foregroundStyle(.secondary)

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

  // MARK: - Developer Options Section

  /// Returns true if the app is running in a non-production environment
  private var isNonProductionEnvironment: Bool {
    !AppEnvironment.isAppStore
  }

  /// Returns true if we're simulating production
  private var isSimulatingProduction: Bool {
    AppEnvironment.isSimulatingProduction
  }

  @ViewBuilder
  private var developerOptionsSection: some View {
    if AppEnvironment.isDebug && !simulateProductionEnvironment {
      Section {
        Button("App Stats") {
          showAppStats = true
        }
        #if DEBUG
        Button("Data Seeder") {
          showDataSeeder = true
        }
        #endif
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

        #if DEBUG
        Button("Show Test Remote Alert") {
          RemoteAlertService.shared.showTestAlert()
        }

        Button("Reset Remote Alert State") {
          RemoteAlertService.shared.resetDismissedState()
        }

        Button("Fetch Remote Alert Now") {
          Task {
            await RemoteAlertService.shared.checkForAlert()
          }
        }
        #endif

        Toggle("Simulate Production Environment", isOn: Binding(
          get: { AppEnvironment.simulateProductionEnvironment },
          set: { newValue in
            AppEnvironment.simulateProductionEnvironment = newValue
            simulateProductionEnvironment = newValue
          }
        ))

        if isNonProductionEnvironment {
          Button("Revisit Onboarding") {
            showOnboarding = true
          }
        }
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

        #if DEBUG
        Button("Preview Membership Banner") {
          showBannerPreview = true
        }
        #endif
      }
      .sheet(isPresented: $showSubscriptionTesting) {
        SubscriptionTestingView()
      }
      #if DEBUG
      .sheet(isPresented: $showBannerPreview) {
        MembershipBannerPreviewView()
      }
      #endif
    }

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

  // MARK: - Helper Methods

  private func openFeedback() {
    guard let url = AppEnvironment.feedbackURL else { return }

    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url)
    } else {
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
          let dtoHasContent = !dto.body.isEmpty || (dto.drawingData != nil && !dto.drawingData!.isEmpty)
          if !dtoHasContent {
            skippedCount += 1
            continue
          }

          let entry = DayEntry.findOrCreate(for: dto.createdAt, in: context)
          let hadContent = !entry.body.isEmpty || (entry.drawingData != nil && !entry.drawingData!.isEmpty)

          if entry.body.isEmpty && !dto.body.isEmpty {
            entry.body = dto.body
          } else if !entry.body.isEmpty && !dto.body.isEmpty && entry.body != dto.body {
            entry.body = entry.body + "\n\n---\n\n" + dto.body
          }

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
        let finalImported = importedCount
        let finalMerged = mergedCount
        let finalSkipped = skippedCount
        await MainActor.run {
          importMessage = "Imported \(finalImported) new entries, merged \(finalMerged) existing entries. Skipped \(finalSkipped) empty entries."
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

// MARK: - Daily Reminder Settings View

struct DailyReminderSettingsView: View {
  @Environment(\.userPreferences) private var userPreferences
  @StateObject private var reminderManager = ReminderManager.shared
  @State private var showNotificationDeniedAlert = false

  private var dailyReminderTimeBinding: Binding<Date> {
    Binding(
      get: { userPreferences.dailyReminderTime },
      set: { newTime in
        userPreferences.dailyReminderTime = newTime
        reminderManager.updateDailyReminderTime(newTime)
      }
    )
  }

  var body: some View {
    Form {
      Section {
        Toggle(isOn: Binding(
          get: { userPreferences.isDailyReminderEnabled },
          set: { newValue in
            if newValue {
              Task {
                let success = await reminderManager.enableDailyReminder(at: userPreferences.dailyReminderTime)
                await MainActor.run {
                  if success {
                    userPreferences.isDailyReminderEnabled = true
                  } else {
                    showNotificationDeniedAlert = true
                  }
                }
              }
            } else {
              userPreferences.isDailyReminderEnabled = false
              reminderManager.disableDailyReminder()
            }
          }
        )) {
          HStack {
            SettingsIconView(systemName: "bell.fill", backgroundColor: .red)
            Text("Enable Daily Reminder")
          }
        }

        if userPreferences.isDailyReminderEnabled {
          HStack {
            SettingsIconView(systemName: "clock.fill", backgroundColor: .red)
            DatePicker(
              "Reminder Time",
              selection: dailyReminderTimeBinding,
              displayedComponents: .hourAndMinute
            )
          }
        }
      } footer: {
        Text("Get a daily notification to capture your moment. Daily reminder will be skipped if today's entry has already been filled.")
      }
    }
    .navigationTitle("Daily Reminder")
    .navigationBarTitleDisplayMode(.inline)
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
}

// MARK: - Customization Settings View

struct CustomizationSettingsView: View {
  @Environment(\.userPreferences) private var userPreferences
  @StateObject private var subscriptionManager = SubscriptionManager.shared
  @Binding var showPaywall: Bool
  @Binding var pendingThemeColor: ThemeColor?
  @Binding var showThemeOverlay: Bool
  private var themeColorManager = ThemeColorManager.shared

  init(showPaywall: Binding<Bool>, pendingThemeColor: Binding<ThemeColor?>, showThemeOverlay: Binding<Bool>) {
    self._showPaywall = showPaywall
    self._pendingThemeColor = pendingThemeColor
    self._showThemeOverlay = showThemeOverlay
  }

  private var viewModeBinding: Binding<ViewMode> {
    Binding(
      get: { userPreferences.defaultViewMode },
      set: { userPreferences.defaultViewMode = $0 }
    )
  }

  private var startOfWeekBinding: Binding<String> {
    Binding(
      get: { userPreferences.startOfWeek },
      set: { userPreferences.startOfWeek = $0 }
    )
  }

  private var colorSchemeBinding: Binding<ColorScheme?> {
    Binding(
      get: { userPreferences.preferredColorScheme },
      set: { newValue in
        userPreferences.preferredColorScheme = newValue
        NotificationCenter.default.post(name: .didChangeColorScheme, object: nil)
      }
    )
  }

  var body: some View {
    Form {
      // Default View Mode Section
      Section {
        VStack(spacing: 0) {
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

      // Start of Week Section
      Section {
        VStack(spacing: 12) {
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

          Text("Start of Week affects the layout in \"Normal\" view mode.")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } header: {
        Text("Start of Week")
      }

      // Color Scheme Section
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

      // Theme Color Section
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
            // Let the overlay handle the completion
          }
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
      } header: {
        Text("Theme Color")
      }
    }
    .navigationTitle("Customization")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(userPreferences.preferredColorScheme)
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
        .id(color)
      }
    }
  }
}

// MARK: - Interactions Settings View

// MARK: - Anniversary Alarms Settings View

struct AnniversaryAlarmsSettingsView: View {
  @StateObject private var reminderManager = ReminderManager.shared
  @State private var selectedReminders = Set<String>()
  @State private var showPastTimeAlert = false

  /// Sorted reminders by date (ascending)
  private var sortedReminders: [Reminder] {
    reminderManager.reminders.sorted { lhs, rhs in
      // First compare by dateString (which is in yyyy-MM-dd format, so lexicographic order works)
      if lhs.dateString != rhs.dateString {
        return lhs.dateString < rhs.dateString
      }
      // If same date, compare by reminder time
      return lhs.reminderDate < rhs.reminderDate
    }
  }

  var body: some View {
    List(selection: $selectedReminders) {
      if sortedReminders.isEmpty {
        Section {
          VStack(spacing: 12) {
            Image(systemName: "alarm")
              .font(.system(size: 40))
              .foregroundStyle(.secondary)
            Text("No Anniversary Alarms")
              .font(.headline)
              .foregroundStyle(.secondary)
            Text("Set alarms for future Joodle entries to get notified on special dates.")
              .font(.subheadline)
              .foregroundStyle(.tertiary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 40)
        }
      } else {
        Section {
          ForEach(sortedReminders) { reminder in
            AnniversaryAlarmRow(
              reminder: reminder,
              onTimeChange: { newTime in
                updateReminderTime(reminder: reminder, newTime: newTime)
              },
              onPastTimeError: {
                showPastTimeAlert = true
              }
            )
          }
          .onDelete(perform: deleteReminders)
        } footer: {
          Text("Swipe left to delete, or tap Edit to select multiple alarms.")
        }
      }
    }
    .navigationTitle("Anniversary Alarms")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if !sortedReminders.isEmpty {
          EditButton()
        }
      }

      ToolbarItem(placement: .bottomBar) {
        if !selectedReminders.isEmpty {
          Button(role: .destructive) {
            deleteSelectedReminders()
          } label: {
            Text("Delete Selected (\(selectedReminders.count))")
              .foregroundStyle(.red)
          }
        }
      }
    }
    .alert("Invalid Alarm Time", isPresented: $showPastTimeAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("The selected time has already passed. Please choose a future time for your anniversary alarm.")
    }
  }

  private func deleteReminders(at offsets: IndexSet) {
    let remindersToDelete = offsets.map { sortedReminders[$0] }
    for reminder in remindersToDelete {
      reminderManager.removeReminder(for: reminder.dateString)
    }
  }

  private func deleteSelectedReminders() {
    for dateString in selectedReminders {
      reminderManager.removeReminder(for: dateString)
    }
    selectedReminders.removeAll()
  }

  private func updateReminderTime(reminder: Reminder, newTime: Date) {
    Task {
      await reminderManager.addReminder(
        for: reminder.dateString,
        at: newTime,
        entryBody: reminder.entryBody
      )
    }
  }
}

// MARK: - Anniversary Alarm Row

struct AnniversaryAlarmRow: View {
  let reminder: Reminder
  let onTimeChange: (Date) -> Void
  let onPastTimeError: () -> Void

  @State private var selectedTime: Date

  init(reminder: Reminder, onTimeChange: @escaping (Date) -> Void, onPastTimeError: @escaping () -> Void) {
    self.reminder = reminder
    self.onTimeChange = onTimeChange
    self.onPastTimeError = onPastTimeError
    self._selectedTime = State(initialValue: reminder.reminderDate)
  }

  private var displayDate: String {
    CalendarDate(dateString: reminder.dateString)?.displayString ?? reminder.dateString
  }

  /// Combines the entry date with the selected time
  private func combinedReminderDate(from time: Date) -> Date {
    guard let entryDate = DayEntry.stringToLocalDate(reminder.dateString) else {
      return time
    }

    let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
    var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: entryDate)
    dateComponents.hour = timeComponents.hour
    dateComponents.minute = timeComponents.minute

    return Calendar.current.date(from: dateComponents) ?? time
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(displayDate)
          .font(.body)
          .foregroundStyle(.primary)

        if let entryBody = reminder.entryBody, !entryBody.isEmpty {
          Text(entryBody)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      DatePicker(
        "Alarm Time",
        selection: $selectedTime,
        displayedComponents: .hourAndMinute
      )
      .labelsHidden()
      .onChange(of: selectedTime) { _, newTime in
        let combined = combinedReminderDate(from: newTime)
        if combined <= Date() {
          // Reset to previous time and show error
          selectedTime = reminder.reminderDate
          onPastTimeError()
        } else {
          onTimeChange(combined)
        }
      }
    }
  }
}

struct InteractionsSettingsView: View {
  @Environment(\.userPreferences) private var userPreferences

  private var hapticBinding: Binding<Bool> {
    Binding(
      get: { userPreferences.enableHaptic },
      set: { userPreferences.enableHaptic = $0 }
    )
  }

  var body: some View {
    Form {
      Section {
        Toggle(isOn: hapticBinding) {
          HStack {
            SettingsIconView(systemName: "hand.tap.fill", backgroundColor: .blue)
            Text("Haptic Feedback")
          }
        }
      } footer: {
        Text("Haptic feedback also depends on your device's vibration setting in Settings > Accessibility > Touch > Vibration.")
      }
    }
    .navigationTitle("Interactions")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - Backup & Restore Settings View

struct BackupRestoreSettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var showFileExporter = false
  @State private var showFileImporter = false
  @State private var exportDocument: JSONDocument?
  @State private var importMessage = ""
  @State private var showImportAlert = false

  var body: some View {
    Form {
      Section {
        Button(action: { exportData() }) {
          HStack {
            SettingsIconView(systemName: "square.and.arrow.up.fill", backgroundColor: .gray)
            Text("Backup Locally")
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Button(action: { showFileImporter = true }) {
          HStack {
            SettingsIconView(systemName: "square.and.arrow.down.fill", backgroundColor: .gray)
            Text("Restore From Local Backup")
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      } footer: {
        Text("Create a local backup of your Joodle entries or restore from a previous backup. Backups are saved as JSON files.")
      }
    }
    .navigationTitle("Backup & Restore")
    .navigationBarTitleDisplayMode(.inline)
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
          let dtoHasContent = !dto.body.isEmpty || (dto.drawingData != nil && !dto.drawingData!.isEmpty)
          if !dtoHasContent {
            skippedCount += 1
            continue
          }

          let entry = DayEntry.findOrCreate(for: dto.createdAt, in: context)
          let hadContent = !entry.body.isEmpty || (entry.drawingData != nil && !entry.drawingData!.isEmpty)

          if entry.body.isEmpty && !dto.body.isEmpty {
            entry.body = dto.body
          } else if !entry.body.isEmpty && !dto.body.isEmpty && entry.body != dto.body {
            entry.body = entry.body + "\n\n---\n\n" + dto.body
          }

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
        let finalImported = importedCount
        let finalMerged = mergedCount
        let finalSkipped = skippedCount
        await MainActor.run {
          importMessage = "Imported \(finalImported) new entries, merged \(finalMerged) existing entries. Skipped \(finalSkipped) empty entries."
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

// MARK: - Data Transfer Objects

struct DayEntryDTO: Codable {
  let body: String
  let createdAt: Date
  let dateString: String?
  let drawingData: Data?
  let drawingThumbnail20: Data?
  let drawingThumbnail200: Data?

  enum CodingKeys: String, CodingKey {
    case body
    case createdAt
    case dateString
    case drawingData
    case drawingThumbnail20
    case drawingThumbnail200
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

// MARK: - App Stats View

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

  // Debug breakdown
  @State private var entriesByYear: [Int: Int] = [:]
  @State private var entriesWithDrawing: Int = 0
  @State private var entriesWithText: Int = 0
  @State private var entriesEmpty: Int = 0
  @State private var entriesWithEmptyDateString: Int = 0

  var body: some View {
    NavigationStack {
      List {
        Section("Overview") {
          HStack {
            Text("Total Entries")
            Spacer()
            Text("\(totalEntries)")
              .foregroundColor(.secondary)
          }
          HStack {
            Text("Unique Dates")
            Spacer()
            Text("\(uniqueDateCount)")
              .foregroundColor(.secondary)
          }
          HStack {
            Text("Duplicate Entries")
            Spacer()
            Text("\(duplicateCount)")
              .foregroundColor(duplicateCount > 0 ? .orange : .secondary)
          }
        }

        Section("Content Breakdown") {
          HStack {
            Text("With Drawing")
            Spacer()
            Text("\(entriesWithDrawing)")
              .foregroundColor(.secondary)
          }
          HStack {
            Text("With Text Only")
            Spacer()
            Text("\(entriesWithText)")
              .foregroundColor(.secondary)
          }
          HStack {
            Text("Empty Entries")
            Spacer()
            Text("\(entriesEmpty)")
              .foregroundColor(entriesEmpty > 0 ? .orange : .secondary)
          }
          HStack {
            Text("Missing Date String")
            Spacer()
            Text("\(entriesWithEmptyDateString)")
              .foregroundColor(entriesWithEmptyDateString > 0 ? .red : .secondary)
          }
        }

        if !entriesByYear.isEmpty {
          Section("Entries by Year") {
            ForEach(entriesByYear.keys.sorted().reversed(), id: \.self) { year in
              HStack {
                Text("\(year)")
                Spacer()
                Text("\(entriesByYear[year] ?? 0)")
                  .foregroundColor(.secondary)
              }
            }
          }
        }

        if duplicateCount > 0 {
          Section("Duplicate Details") {
            ForEach(duplicateDetails.keys.sorted(), id: \.self) { dateString in
              HStack {
                Text(dateString)
                  .font(.caption)
                Spacer()
                Text("\(duplicateDetails[dateString] ?? 0) entries")
                  .font(.caption)
                  .foregroundColor(.orange)
              }
            }
          }
        }

        Section("Sync Status") {
          HStack {
            Text("iCloud Available")
            Spacer()
            Image(systemName: cloudSyncManager.isCloudAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
              .foregroundColor(cloudSyncManager.isCloudAvailable ? .green : .red)
          }
          HStack {
            Text("Can Sync")
            Spacer()
            Image(systemName: cloudSyncManager.canSync ? "checkmark.circle.fill" : "xmark.circle.fill")
              .foregroundColor(cloudSyncManager.canSync ? .green : .red)
          }
          HStack {
            Text("Is Syncing")
            Spacer()
            if cloudSyncManager.isSyncing {
              ProgressView()
                .scaleEffect(0.8)
            } else {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
            }
          }
        }

        Section("Subscription") {
          HStack {
            Text("Status")
            Spacer()
            Text(subscriptionManager.isSubscribed ? "Pro" : "Free")
              .foregroundColor(subscriptionManager.isSubscribed ? .green : .secondary)
          }
          if let message = subscriptionManager.subscriptionStatusMessage {
            HStack {
              Text("Details")
              Spacer()
              Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }

        Section("Actions") {
          Button {
            printDetailedDebugInfo()
          } label: {
            Text("Print Debug Info to Console")
          }

          if duplicateCount > 0 {
            Button {
              clearDuplicates()
            } label: {
              HStack {
                Text("Clear Duplicates")
                if isCleaningDuplicates {
                  Spacer()
                  ProgressView()
                    .scaleEffect(0.8)
                }
              }
            }
            .disabled(isCleaningDuplicates)
          }

          if entriesEmpty > 0 {
            Button(role: .destructive) {
              deleteEmptyEntries()
            } label: {
              HStack {
                Text("Delete Empty Entries")
                if isCleaningEmpty {
                  Spacer()
                  ProgressView()
                    .scaleEffect(0.8)
                }
              }
            }
            .disabled(isCleaningEmpty)
          }
        }

        if let result = cleanupResult {
          Section("Result") {
            Text(result)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
      .navigationTitle("App Stats")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
      .onAppear {
        loadStats()
        loadDebugBreakdown()
      }
    }
  }

  private func loadStats() {
    let descriptor = FetchDescriptor<DayEntry>()
    if let entries = try? modelContext.fetch(descriptor) {
      totalEntries = entries.count
      let dateStrings = entries.compactMap { $0.dateString }
      uniqueDateCount = Set(dateStrings).count
      duplicateCount = totalEntries - uniqueDateCount
    }
  }

  private func loadDebugBreakdown() {
    let descriptor = FetchDescriptor<DayEntry>()
    guard let entries = try? modelContext.fetch(descriptor) else { return }

    var yearCounts: [Int: Int] = [:]
    var withDrawing = 0
    var withText = 0
    var empty = 0
    var emptyDateString = 0
    var dateDuplicates: [String: Int] = [:]

    for entry in entries {
      let calendar = Calendar.current
      let year = calendar.component(.year, from: entry.createdAt)
      yearCounts[year, default: 0] += 1

      let hasDrawing = entry.drawingData != nil && !entry.drawingData!.isEmpty
      let hasText = !entry.body.isEmpty

      if hasDrawing {
        withDrawing += 1
      } else if hasText {
        withText += 1
      } else {
        empty += 1
      }

      if entry.dateString.isEmpty {
        emptyDateString += 1
      }

      dateDuplicates[entry.dateString, default: 0] += 1
    }

    entriesByYear = yearCounts
    entriesWithDrawing = withDrawing
    entriesWithText = withText
    entriesEmpty = empty
    entriesWithEmptyDateString = emptyDateString
    duplicateDetails = dateDuplicates.filter { $0.value > 1 }
  }

  private func printDetailedDebugInfo() {
    let descriptor = FetchDescriptor<DayEntry>()
    guard let entries = try? modelContext.fetch(descriptor) else { return }

    print("=== DETAILED DEBUG INFO ===")
    print("Total entries: \(entries.count)")
    print("")

    let sortedEntries = entries.sorted { $0.createdAt < $1.createdAt }
    var dateGroups: [String: [DayEntry]] = [:]

    for entry in sortedEntries {
      let key = entry.dateString.isEmpty ? "(empty)" : entry.dateString
      dateGroups[key, default: []].append(entry)
    }

    print("=== ENTRIES BY DATE ===")
    for dateString in dateGroups.keys.sorted() {
      let group = dateGroups[dateString]!
      if group.count > 1 {
        print("\n⚠️ DUPLICATE: \(dateString) - \(group.count) entries")
        for (index, entry) in group.enumerated() {
          let hasDrawing = entry.drawingData != nil && !entry.drawingData!.isEmpty
          let textPreview = entry.body.prefix(50).replacingOccurrences(of: "\n", with: " ")
          print("  [\(index + 1)] Created: \(entry.createdAt), Drawing: \(hasDrawing), Text: \"\(textPreview)\"")
        }
      }
    }

    print("\n=== EMPTY ENTRIES ===")
    let emptyEntries = entries.filter { entry in
      let hasDrawing = entry.drawingData != nil && !entry.drawingData!.isEmpty
      let hasText = !entry.body.isEmpty
      return !hasDrawing && !hasText
    }
    for entry in emptyEntries {
      print("Empty: \(entry.dateString.isEmpty ? "(empty)" : entry.dateString) - Created: \(entry.createdAt)")
    }

    print("\n=== END DEBUG INFO ===")
  }

  private func clearDuplicates() {
    isCleaningDuplicates = true

    Task {
      let result = DuplicateEntryCleanup.shared.forceCleanupDuplicates(modelContext: modelContext, markAsCompleted: false)
      await MainActor.run {
        cleanupResult = "Merged \(result.merged), deleted \(result.deleted) entries"
        isCleaningDuplicates = false
        loadStats()
        loadDebugBreakdown()
      }
    }
  }

  private func deleteEmptyEntries() {
    isCleaningEmpty = true

    Task {
      let descriptor = FetchDescriptor<DayEntry>()
      guard let entries = try? modelContext.fetch(descriptor) else {
        await MainActor.run {
          isCleaningEmpty = false
          cleanupResult = "Failed to fetch entries"
        }
        return
      }

      var deletedCount = 0
      for entry in entries {
        let hasDrawing = entry.drawingData != nil && !entry.drawingData!.isEmpty
        let hasText = !entry.body.isEmpty
        if !hasDrawing && !hasText {
          modelContext.delete(entry)
          deletedCount += 1
        }
      }

      try? modelContext.save()

      await MainActor.run {
        cleanupResult = "Deleted \(deletedCount) empty entries"
        isCleaningEmpty = false
        loadStats()
        loadDebugBreakdown()
      }
    }
  }
}

// MARK: - JSON Document

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
    FileWrapper(regularFileWithContents: data)
  }
}

// MARK: - Learn Core Features View

struct LearnCoreFeaturesView: View {
  @StateObject private var subscriptionManager = SubscriptionManager.shared
  @State private var selectedTutorialStep: TutorialStepType?

  var body: some View {
    List {
      Section {
        ForEach(TutorialStepType.allCases) { stepType in
          Button {
            selectedTutorialStep = stepType
          } label: {
            HStack {
              SettingsIconView(systemName: stepType.icon, backgroundColor: .indigo)
              Text(stepType.title)
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
              SettingsIconView(systemName: tutorial.icon, backgroundColor: .indigo)
              Text(tutorial.title)
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
              SettingsIconView(systemName: tutorial.icon, backgroundColor: .indigo)
              Text(tutorial.title)
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

// MARK: - Debug Data Seeder View

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

// MARK: - Membership Banner Preview View (Debug)

#if DEBUG
struct MembershipBannerPreviewView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedState: BannerPreviewState = .free

  enum BannerPreviewState: String, CaseIterable {
    case free = "Free User"
    case freeNearLimit = "Free (Near Limit)"
    case freeAtLimit = "Free (At Limit)"
    case proActive = "Pro (Active)"
    case proTrial = "Pro (Trial)"
    case proCancelled = "Pro (Cancelled)"
    case proExpiringSoon = "Pro (Expiring Soon)"
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Picker("Preview State", selection: $selectedState) {
            ForEach(BannerPreviewState.allCases, id: \.self) { state in
              Text(state.rawValue).tag(state)
            }
          }
          .pickerStyle(.menu)
        }

        Section("Preview") {
          MembershipBannerView(
            isSubscribed: isSubscribed,
            statusMessage: statusMessage,
            joodleCount: joodleCount,
            alarmCount: alarmCount,
            onTap: {}
          )
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
      }
      .navigationTitle("Banner Preview")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private var isSubscribed: Bool {
    switch selectedState {
    case .free, .freeNearLimit, .freeAtLimit:
      return false
    case .proActive, .proTrial, .proCancelled, .proExpiringSoon:
      return true
    }
  }

  private var statusMessage: String? {
    switch selectedState {
    case .proTrial:
      let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      return "Trial ends \(formatter.string(from: futureDate))"
    case .proCancelled:
      let futureDate = Calendar.current.date(byAdding: .day, value: 20, to: Date())!
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      return "Expires \(formatter.string(from: futureDate))"
    case .proExpiringSoon:
      let futureDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      return "Expires \(formatter.string(from: futureDate))"
    default:
      return nil
    }
  }

  private var joodleCount: Int {
    switch selectedState {
    case .free:
      return 12
    case .freeNearLimit:
      return 28
    case .freeAtLimit:
      return 30
    default:
      return 0
    }
  }

  private var alarmCount: Int {
    switch selectedState {
    case .free:
      return 2
    case .freeNearLimit:
      return 4
    case .freeAtLimit:
      return 5
    default:
      return 0
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
