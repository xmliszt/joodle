import SwiftData
import SwiftUI
import Combine

// 1. The Steps: Easy to reorder or add new ones here.
enum OnboardingStep: Hashable, CaseIterable {
    case drawingEntry              // The greeting + drawing
    case valueProposition          // Confetti + Explanation
    case yearGridDemo              // Interactive tutorial in sandboxed environment
    case featureIntroWidgets       // Feature intro: Widgets (kept - can't be interactive)
    case paywall                   // Subscription choice
    case icloudConfig              // iCloud sync configuration (only for subscribers)
    case dailyReminder             // Daily reminder configuration
    case onboardingCompletion      // Completion step
}

// 2. The Brain: Manages data and navigation logic
@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()

    // Data collected during onboarding
    // We store the raw JSON data representing [PathData]
    @Published var firstJoodleData: Data?
    @Published var isPremium: Bool = false
    @Published var shouldDismiss = false

    // iCloud sync preference set during onboarding
    @Published var userWantsCloudSync: Bool = false

    // Flag to indicate restart is needed after onboarding completes
    // This is checked by JoodleApp after onboarding dismisses
    @Published var needsRestartAfterOnboarding: Bool = false

    // Track if this is a revisit (user already completed onboarding before)
    // We use a separate flag because hasCompletedOnboarding is reset to false to trigger onboarding
    var isRevisitingOnboarding: Bool {
      UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") ||
      UserDefaults.standard.bool(forKey: "isRevisitFromSettings")
    }

    /// Check if this is a revisit triggered from Settings > Learn Core Features
    /// This flag ensures tutorials are shown even for users with active subscriptions
    var isRevisitFromSettings: Bool {
      UserDefaults.standard.bool(forKey: "isRevisitFromSettings")
    }

    var isReturnUser: Bool {
      // If revisiting from settings, never treat as return user (always show tutorials)
      if isRevisitFromSettings { return false }
      return !self.isRevisitingOnboarding && StoreKitManager.shared.hasActiveSubscription
    }

    /// Whether to show feature introduction steps
    /// Show for: first-time users, revisiting users from Settings
    /// Skip for: return users (reinstall with existing subscription)
    var shouldShowFeatureIntro: Bool {
        !isReturnUser
    }

    var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Monitor subscription status changes
        SubscriptionManager.shared.$isSubscribed
            .assign(to: &$isPremium)
    }

    // Actions
    func completeStep(_ step: OnboardingStep) {
        // Play haptic feedback on step transition
        Haptic.play(with: .light)

        switch step {
        case .drawingEntry:
            navigationPath.append(OnboardingStep.valueProposition)

        case .valueProposition:
            // After confirming first Joodle, decide next step based on user type
            if shouldShowFeatureIntro {
                // First-time user or revisiting from Settings: show interactive tutorial
                navigationPath.append(OnboardingStep.yearGridDemo)
            } else {
                // Return user (reinstall with subscription): skip feature intros
                // Go directly to iCloud config since they already have subscription
                navigationPath.append(OnboardingStep.icloudConfig)
            }

        case .yearGridDemo:
            // After interactive tutorial, show widgets intro
            navigationPath.append(OnboardingStep.featureIntroWidgets)

        case .featureIntroWidgets:
            // After widgets intro, proceed to paywall or iCloud config
            if StoreKitManager.shared.hasActiveSubscription {
                // User is already subscribed, show iCloud config
                navigationPath.append(OnboardingStep.icloudConfig)
            } else {
                navigationPath.append(OnboardingStep.paywall)
            }

        case .paywall:
            // After paywall, check if user subscribed
            if isPremium || StoreKitManager.shared.hasActiveSubscription {
                // User subscribed, show iCloud config
                navigationPath.append(OnboardingStep.icloudConfig)
            } else {
                // User skipped subscription, go to daily reminder
                navigationPath.append(OnboardingStep.dailyReminder)
            }

        case .icloudConfig:
            // After iCloud config, go to daily reminder setup
            navigationPath.append(OnboardingStep.dailyReminder)

        case .dailyReminder:
            // After daily reminder config, go to completion
            navigationPath.append(OnboardingStep.onboardingCompletion)

        case .onboardingCompletion:
            finishOnboarding()
        }
    }

    /// Called when user decides to skip iCloud sync setup
    func skipCloudSync() {
        Haptic.play(with: .light)
        userWantsCloudSync = false
        navigationPath.append(OnboardingStep.onboardingCompletion)
    }

    func goBack() {
        guard !navigationPath.isEmpty else { return }
        Haptic.play(with: .light)
        navigationPath.removeLast()
    }

    private func finishOnboarding() {
        // Save flags to UserDefaults to hide onboarding on next launch
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        // Clear the revisit from settings flag
        UserDefaults.standard.removeObject(forKey: "isRevisitFromSettings")

        // Update subscription status if premium was set during onboarding
        #if DEBUG
        if isPremium {
            SubscriptionManager.shared.grantSubscription()
        }
        #endif

        // Always save the drawing immediately to local database
        // This ensures the drawing is never lost, regardless of sync state
        saveOnboardingDrawing()

        // Enable iCloud sync if user opted in during onboarding
        enableCloudSyncIfRequested()

        // Check if restart is needed for iCloud sync to take effect
        if userWantsCloudSync && ModelContainerManager.shared.needsRestartForSyncChange {
            needsRestartAfterOnboarding = true
            // Save flag so JoodleApp knows to show restart alert
            UserDefaults.standard.set(true, forKey: "pending_icloud_sync_restart")
        }

        shouldDismiss = true
    }

    /// Save the onboarding drawing to the database immediately
    func saveOnboardingDrawing() {
        guard let data = firstJoodleData, !data.isEmpty, let context = modelContext else {
            print("OnboardingViewModel: No drawing data to save or no context")
            return
        }

        // Use CalendarDate for timezone-agnostic "today" determination
        let todayCalendarDate = CalendarDate.today()

        // Use findOrCreate to get the single entry for this date (merges duplicates if any)
        let entryToUpdate = DayEntry.findOrCreate(for: todayCalendarDate, in: context)
        let isNewJoodle = entryToUpdate.drawingData == nil || entryToUpdate.drawingData?.isEmpty == true

        // If this is a revisit onboarding, check Joodle limits
        if isRevisitingOnboarding {
            let allEntriesDescriptor = FetchDescriptor<DayEntry>()
            do {
                let allEntries = try context.fetch(allEntriesDescriptor)

                if isNewJoodle {
                    // User is trying to create a NEW Joodle via revisit onboarding
                    // Check if they're within their Joodle limit
                    let currentJoodleCount = SubscriptionManager.shared.totalJoodleCount(from: allEntries)

                    if !SubscriptionManager.shared.canCreateJoodle(currentTotalCount: currentJoodleCount) {
                        print("OnboardingViewModel: Joodle limit reached, skipping save during revisit onboarding")
                        return
                    }
                } else {
                    // User is trying to EDIT an existing entry via revisit onboarding
                    // Check if this Joodle is within the editable range for free users
                    let entriesWithDrawings = allEntries
                        .filter { $0.drawingData != nil }
                        .sorted { $0.dateString < $1.dateString }

                    if let index = entriesWithDrawings.firstIndex(where: { $0.id == entryToUpdate.id }) {
                        if !SubscriptionManager.shared.canEditJoodle(atIndex: index) {
                            print("OnboardingViewModel: Joodle #\(index + 1) is locked, skipping edit during revisit onboarding")
                            return
                        }
                    }
                }
            } catch {
                print("OnboardingViewModel: Failed to fetch entries for limit check: \(error)")
            }
        }

        // Update the entry with drawing data
        entryToUpdate.drawingData = data

        // Save immediately
        do {
            try context.save()
          print("OnboardingViewModel: Drawing saved successfully for \(todayCalendarDate.dateString)")
        } catch {
            print("OnboardingViewModel: Failed to save drawing: \(error)")
        }

        // Generate thumbnails asynchronously
        Task {
            let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(from: data)
            entryToUpdate.drawingThumbnail20 = thumbnails.0
            entryToUpdate.drawingThumbnail200 = thumbnails.1
            try? context.save()
            print("OnboardingViewModel: Thumbnails generated and saved")
        }
    }

    /// Update iCloud sync preference based on user's choice during onboarding
    private func enableCloudSyncIfRequested() {
        // During revisit onboarding, user can disable iCloud sync
        if !userWantsCloudSync && isRevisitingOnboarding && UserPreferences.shared.isCloudSyncEnabled {
            print("OnboardingViewModel: User opted to disable iCloud sync during revisit onboarding")

            // Use CloudSyncManager to properly disable sync
            CloudSyncManager.shared.disableSync()
            return
        }

        // Only enable if user explicitly opted in
        guard userWantsCloudSync else {
            print("OnboardingViewModel: User did not opt in for iCloud sync")
            return
        }

        // Check if user has active subscription
        guard isPremium || StoreKitManager.shared.hasActiveSubscription else {
            print("OnboardingViewModel: iCloud sync not enabled - no active subscription")
            return
        }

        // Check if iCloud sync is already enabled
        guard !UserPreferences.shared.isCloudSyncEnabled else {
            print("OnboardingViewModel: iCloud sync already enabled")
            return
        }

        // Check system requirements
        let syncManager = CloudSyncManager.shared
        guard syncManager.isCloudAvailable && syncManager.systemCloudEnabled else {
            print("OnboardingViewModel: iCloud sync not enabled - system requirements not met")
            print("   isCloudAvailable: \(syncManager.isCloudAvailable)")
            print("   systemCloudEnabled: \(syncManager.systemCloudEnabled)")
            return
        }

        print("OnboardingViewModel: Enabling iCloud sync preference")

        // Enable the sync preference
        UserPreferences.shared.isCloudSyncEnabled = true

        // Save sync state to iCloud KVS for future reinstall recovery
        let cloudStore = NSUbiquitousKeyValueStore.default
        cloudStore.set(true, forKey: "is_cloud_sync_enabled_backup")
        cloudStore.set(true, forKey: "cloud_sync_was_enabled")
        cloudStore.synchronize()

        // Check if container was created with different sync state
        if ModelContainerManager.shared.needsRestartForSyncChange {
            print("OnboardingViewModel: Container needs restart for sync to take effect")
        } else {
            print("OnboardingViewModel: Container already configured for sync, no restart needed")
        }
    }

    /// Check if iCloud sync can be enabled (system requirements met)
    var canEnableCloudSync: Bool {
        let syncManager = CloudSyncManager.shared
        return syncManager.isCloudAvailable && syncManager.systemCloudEnabled
    }

    /// Reason why iCloud sync cannot be enabled
    var cloudSyncBlockedReason: String? {
        let syncManager = CloudSyncManager.shared
        if !syncManager.systemCloudEnabled {
            return "iCloud is disabled in Settings"
        }
        if !syncManager.isCloudAvailable {
            return "No iCloud account found"
        }
        return nil
    }
}
