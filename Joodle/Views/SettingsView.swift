import CoreHaptics
import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Navigation Coordinator for Swipe Back Gesture
struct NavigationGestureEnabler: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UIViewController {
    let controller = UIViewController()
    return controller
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    DispatchQueue.main.async {
      if let navigationController = uiViewController.navigationController {
        navigationController.interactivePopGestureRecognizer?.isEnabled = true
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
  @State private var showOnboarding = false
  @State private var showPlaceholderGenerator = false
  @State private var showPaywall = false
  @State private var showSubscriptions = false
  @State private var showAppStats = false

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

  var body: some View {
    Form {

      // MARK: - View Mode Preferences
      Section("Default View") {
        if #available(iOS 26.0, *) {
          Picker("View Mode", selection: viewModeBinding) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          .pickerStyle(.palette)
          .glassEffect(.regular.interactive())
        } else {
          // Fallback on earlier versions
          Picker("View Mode", selection: viewModeBinding) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          .pickerStyle(.palette)
        }
      }

      // MARK: - Appearance Preferences
      Section("Appearance") {
        if #available(iOS 26.0, *) {
          Picker("Color Scheme", selection: colorSchemeBinding) {
            Text("System").tag(nil as ColorScheme?)
            Text("Light").tag(ColorScheme.light as ColorScheme?)
            Text("Dark").tag(ColorScheme.dark as ColorScheme?)
          }
          .pickerStyle(.palette)
          .glassEffect(.regular.interactive())
        } else {
          // Fallback on earlier versions
          Picker("Color Scheme", selection: colorSchemeBinding) {
            Text("System").tag(nil as ColorScheme?)
            Text("Light").tag(ColorScheme.light as ColorScheme?)
            Text("Dark").tag(ColorScheme.dark as ColorScheme?)
          }
          .pickerStyle(.palette)
        }
      }

      // MARK: - Interaction Preferences
      if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
        Section {
          Toggle(isOn: hapticBinding) {
            Text("Haptic feedback")
          }
        } header: {
          Text("Interactions")
        } footer: {
          Text("Haptic feedback also depends on your device's Vibration setting in Settings > Accessibility > Touch > Vibration")
        }
      }

      // MARK: - Subscription
      Section("Super Subscription") {
        if subscriptionManager.isSubscribed {
          // Detailed subscription status card
          Button {
            showSubscriptions = true
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                HStack(spacing: 4) {
                  Image(systemName: "crown.fill")
                    .foregroundStyle(.accent)
                    .font(.body)
                  Text("Joodle Super")
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
                Text("You have full access to all premium features")
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
              Text("Unlock Joodle Super")
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .foregroundColor(.primary)
        }
      }

      // MARK: - Data Management
      // Only show manual backup/restore when iCloud sync is not active
      Section("Data Management") {
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
          Text("Backup locally")
        }

        Button(action: { showFileImporter = true }) {
          Text("Restore from local backup")
        }
      }


      // MARK: Revisit onboarding flow
      Section {
        Button("Revisit Onboarding") {
          showOnboarding = true
        }
      }

      // MARK: - Feedback
      Section {
        Button {
          openFeedback()
        } label: {
          HStack {
            Image(systemName: AppEnvironment.feedbackButtonIcon)
              .foregroundColor(.accent)
              .frame(width: 24)
            Text(AppEnvironment.feedbackButtonTitle)
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "arrow.up.right")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      } footer: {
        Text("Version \(AppEnvironment.fullVersionString)")
          .font(.caption2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      // MARK: - Developer Options (Only show in debug build)
      if AppEnvironment.isDebug {
        Section("Developer Options") {
          Button("App Stats") {
            showAppStats = true
          }
          Button("Clear Today's Entries", role: .destructive) {
            clearTodaysEntries()
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
        }
      }
    }
    .background(NavigationGestureEnabler())
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("dismiss", systemImage: "arrow.left") {
          dismiss()
        }.tint(Color.appPrimary)
      }
    }
    .preferredColorScheme(userPreferences.preferredColorScheme)
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
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidExpire)) { _ in
      // Refresh UI when subscription expires
      Task {
        await subscriptionManager.updateSubscriptionStatus()
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
    do {
      let descriptor = FetchDescriptor<DayEntry>()
      let entries = try modelContext.fetch(descriptor)
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
      exportDocument = JSONDocument(data: data)
      showFileExporter = true
    } catch {
      print("Failed to prepare export: \(error)")
    }
  }

  private func importData(from url: URL) {
    guard url.startAccessingSecurityScopedResource() else { return }
    defer { url.stopAccessingSecurityScopedResource() }

    do {
      let data = try Data(contentsOf: url)
      let dtos = try JSONDecoder().decode([DayEntryDTO].self, from: data)

      var count = 0
      for dto in dtos {
        // Check for duplicates based on same day using timezone-agnostic dateString
        let dateString = DayEntry.dateToString(dto.createdAt)

        let descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate<DayEntry> { entry in
          entry.dateString == dateString
        })

        let existing = try modelContext.fetch(descriptor)
        if existing.isEmpty {
          let newEntry = DayEntry(
            body: dto.body,
            createdAt: dto.createdAt,
            drawingData: dto.drawingData
          )
          newEntry.drawingThumbnail20 = dto.drawingThumbnail20
          newEntry.drawingThumbnail200 = dto.drawingThumbnail200
          modelContext.insert(newEntry)
          count += 1
        }
      }

      try modelContext.save()
      importMessage = "Successfully imported \(count) entries."
      showImportAlert = true
    } catch {
      importMessage = "Import failed: \(error.localizedDescription)"
      showImportAlert = true
    }
  }

  private func clearTodaysEntries() {
    let todayDateString = DayEntry.dateToString(Date())

    let predicate = #Predicate<DayEntry> { entry in
      entry.dateString == todayDateString
    }

    do {
      try modelContext.delete(model: DayEntry.self, where: predicate)
      try modelContext.save()
    } catch {
      print("Failed to clear today's entries: \(error)")
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
  @State private var duplicateCount: Int = 0
  @State private var duplicateDetails: [String: Int] = [:]
  @State private var isCleaningDuplicates = false
  @State private var cleanupResult: String?

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
            Text("Dates with Duplicates")
            Spacer()
            Text("\(duplicateCount)")
              .foregroundStyle(duplicateCount > 0 ? .red : .green)
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
    // Fetch total entries
    let descriptor = FetchDescriptor<DayEntry>()
    do {
      let entries = try modelContext.fetch(descriptor)
      totalEntries = entries.count
    } catch {
      print("Failed to fetch entries: \(error)")
    }

    // Check for duplicates
    duplicateCount = DuplicateEntryCleanup.shared.checkDuplicateCount(modelContext: modelContext)
    duplicateDetails = DuplicateEntryCleanup.shared.getDuplicateDetails(modelContext: modelContext)
  }

  private func clearDuplicates() {
    isCleaningDuplicates = true
    cleanupResult = nil

    // Reset the cleanup flag to allow re-running
    DuplicateEntryCleanup.shared.resetCleanupFlag()

    let result = DuplicateEntryCleanup.shared.cleanupDuplicates(modelContext: modelContext)

    cleanupResult = "Merged: \(result.merged), Deleted: \(result.deleted)"
    isCleaningDuplicates = false

    // Reload stats
    loadStats()
  }
}

#Preview {
  AppStatsView()
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
    return FileWrapper(regularFileWithContents: data)
  }
}

#Preview {
  NavigationStack {
    SettingsView()
      .environment(\.userPreferences, UserPreferences.shared)
  }
}
