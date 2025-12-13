import SwiftData
import SwiftUI
import Combine

// 1. The Steps: Easy to reorder or add new ones here.
enum OnboardingStep: Hashable, CaseIterable {
    case drawingEntry      // The greeting + drawing
    case valueProposition  // Confetti + Explanation
    case paywall           // Subscription choice
    // case icloudConfig   // Skipped for V1
    case widgetTutorial    // Final welcome (hidden for now)
    case onboardingCompletion // Completion step
}

// 2. The Brain: Manages data and navigation logic
@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()

    // Data collected during onboarding
    // We store the raw JSON data representing [PathData]
    @Published var firstDoodleData: Data?
    @Published var isPremium: Bool = false
    @Published var shouldDismiss = false

    var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Monitor subscription status changes
        SubscriptionManager.shared.$isSubscribed
            .assign(to: &$isPremium)
    }

    // Actions
    func completeStep(_ step: OnboardingStep) {
        switch step {
        case .drawingEntry:
            navigationPath.append(OnboardingStep.valueProposition)

        case .valueProposition:
            // Skip paywall and finish immediately if user already has an active subscription
            if StoreKitManager.shared.hasActiveSubscription {
                finishOnboarding()
            } else {
                navigationPath.append(OnboardingStep.paywall)
            }

        case .paywall:
            // Skip widget tutorial (not ready), go straight to completion
            navigationPath.append(OnboardingStep.onboardingCompletion)

        case .widgetTutorial:
            // Widget tutorial is currently hidden, but if somehow reached, go to completion
            navigationPath.append(OnboardingStep.onboardingCompletion)

        case .onboardingCompletion:
            finishOnboarding()
        }
    }

    func goBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    private func finishOnboarding() {
        // Save flags to UserDefaults to hide onboarding on next launch
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Update subscription status if premium was set during onboarding
        if isPremium {
            SubscriptionManager.shared.grantSubscription()
        }

        // Always save the drawing immediately to local database
        // This ensures the drawing is never lost, regardless of sync state
        saveOnboardingDrawing()

        // Auto-enable iCloud sync preference if user has subscription
        // Note: If the container wasn't created with sync enabled, user will see
        // a "restart required" banner in ContentView
        autoEnableCloudSyncIfEligible()

        shouldDismiss = true
    }

    /// Save the onboarding drawing to the database immediately
    private func saveOnboardingDrawing() {
        guard let data = firstDoodleData, !data.isEmpty, let context = modelContext else {
            print("OnboardingViewModel: No drawing data to save or no context")
            return
        }

        let today = Date()
        let todayDateString = DayEntry.dateToString(today)

        // Check for existing entry to avoid duplicates using timezone-agnostic dateString
        let predicate = #Predicate<DayEntry> { entry in
            entry.dateString == todayDateString
        }
        let descriptor = FetchDescriptor<DayEntry>(predicate: predicate)

        do {
            let existingEntries = try context.fetch(descriptor)
            let entryToUpdate: DayEntry

            if let existing = existingEntries.first {
                print("OnboardingViewModel: Updating existing entry for \(todayDateString)")
                entryToUpdate = existing
                entryToUpdate.drawingData = data
            } else {
                print("OnboardingViewModel: Creating new entry for \(todayDateString)")
                entryToUpdate = DayEntry(body: "", createdAt: today, drawingData: data)
                context.insert(entryToUpdate)
            }

            // Save immediately
            try context.save()
            print("OnboardingViewModel: Drawing saved successfully for \(todayDateString)")

            // Generate thumbnails asynchronously
            Task {
                let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(from: data)
                entryToUpdate.drawingThumbnail20 = thumbnails.0
                entryToUpdate.drawingThumbnail200 = thumbnails.1
                try? context.save()
                print("OnboardingViewModel: Thumbnails generated and saved")
            }
        } catch {
            print("OnboardingViewModel: Failed to save drawing: \(error)")
        }
    }

    /// Auto-enable iCloud sync preference when user finishes onboarding with an active subscription
    /// The actual sync will start after app restart if container was created without CloudKit
    private func autoEnableCloudSyncIfEligible() {
        // Check if user has active subscription
        guard isPremium || StoreKitManager.shared.hasActiveSubscription else {
            print("OnboardingViewModel: iCloud sync not auto-enabled - no active subscription")
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
            print("OnboardingViewModel: iCloud sync not auto-enabled - system requirements not met")
            print("   isCloudAvailable: \(syncManager.isCloudAvailable)")
            print("   systemCloudEnabled: \(syncManager.systemCloudEnabled)")
            return
        }

        print("OnboardingViewModel: Auto-enabling iCloud sync preference")

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
}
