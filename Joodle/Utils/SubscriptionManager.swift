//
//  SubscriptionManager.swift
//  Joodle
//
//  Created by Subscription Manager
//

import Foundation
import Combine
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isSubscribed: Bool {
        didSet {
            UserDefaults.standard.set(isSubscribed, forKey: "isJoodleSuper")

            // Handle subscription state changes
            if oldValue && !isSubscribed {
                handleSubscriptionLost()
            } else if !oldValue && isSubscribed {
                handleSubscriptionGained()
            }
        }
    }

    @Published var isInTrialPeriod: Bool = false
    @Published var subscriptionExpirationDate: Date?
    @Published var willAutoRenew: Bool = true

    /// Flag indicating subscription just expired (for UI alerts)
    @Published var subscriptionJustExpired: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var expirationCheckTimer: Timer?

    private init() {
        self.isSubscribed = UserDefaults.standard.bool(forKey: "isJoodleSuper")

        // Start monitoring subscription status
        Task {
            await updateSubscriptionStatus()

            // Check iCloud sync status on launch - disable if not subscribed
            await checkAndDisableCloudSyncIfNeeded()

            // Update widget subscription status
            await MainActor.run {
                WidgetHelper.shared.updateSubscriptionStatus()
            }
        }

        // Set up periodic expiration check
        setupExpirationCheck()

        // Listen for app becoming active to refresh status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        expirationCheckTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Subscription Features

    var hasUnlimitedDoodles: Bool {
        isSubscribed
    }

    var hasWidgets: Bool {
        isSubscribed
    }

    var hasICloudSync: Bool {
        isSubscribed
    }

    var hasAllShareTemplates: Bool {
        isSubscribed
    }

    // Free plan limits - maximum total doodles allowed for free users
    nonisolated static let freeDoodlesAllowed = 21

    var maxDoodlesAllowed: Int {
        isSubscribed ? Int.max : Self.freeDoodlesAllowed
    }

    // MARK: - Update Status

    func updateSubscriptionStatus() async {
        let storeManager = StoreKitManager.shared

        // First ensure products are loaded
        if storeManager.products.isEmpty {
            await storeManager.loadProducts()
        }

        // Update purchased products from StoreKit
        await storeManager.updatePurchasedProducts()

        // Sync our state with StoreKitManager
        let wasSubscribed = self.isSubscribed
        self.isSubscribed = storeManager.hasActiveSubscription
        self.isInTrialPeriod = storeManager.isInTrialPeriod
        self.subscriptionExpirationDate = storeManager.subscriptionExpirationDate
        self.willAutoRenew = storeManager.willAutoRenew

        // Note: handleSubscriptionLost() and handleSubscriptionGained() are called
        // automatically by the didSet observer on isSubscribed when the value changes

        print("📊 SubscriptionManager updated:")
        print("   isSubscribed: \(isSubscribed)")
        print("   isInTrialPeriod: \(isInTrialPeriod)")
        print("   expirationDate: \(subscriptionExpirationDate?.formatted() ?? "nil")")
        print("   willAutoRenew: \(willAutoRenew)")
    }

    // MARK: - Expiration Monitoring

    private func setupExpirationCheck() {
        // Check every 60 seconds if subscription has expired
        expirationCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkExpiration()
            }
        }
    }

    private func checkExpiration() {
        guard isSubscribed else { return }

        if let expirationDate = subscriptionExpirationDate {
            if Date() > expirationDate {
                // Subscription has expired - refresh from StoreKit to confirm
                Task {
                    await updateSubscriptionStatus()
                }
            }
        }
    }

    @objc private func appDidBecomeActive() {
        // Refresh subscription status when app becomes active
        Task {
            await updateSubscriptionStatus()
        }
    }

    // MARK: - Subscription State Change Handling

    private func handleSubscriptionGained() {
        print("🎉 Subscription gained - enabling premium features")

        // Auto-enable iCloud sync when user upgrades
        if !UserPreferences.shared.isCloudSyncEnabled {
            // Check if system requirements are met for iCloud sync
            let syncManager = CloudSyncManager.shared

            if syncManager.isCloudAvailable && syncManager.systemCloudEnabled {
                print("   Auto-enabling iCloud sync for new subscriber")
                UserPreferences.shared.isCloudSyncEnabled = true

                // Notify the app to recreate ModelContainer with cloud sync
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudSyncPreferenceChanged"),
                    object: nil
                )
            } else {
                print("   iCloud sync not auto-enabled: system requirements not met")
                print("   isCloudAvailable: \(syncManager.isCloudAvailable)")
                print("   systemCloudEnabled: \(syncManager.systemCloudEnabled)")
            }
        }

        // Update widget subscription status
        WidgetHelper.shared.updateSubscriptionStatus()

        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .subscriptionDidActivate,
            object: nil
        )
    }

    private func handleSubscriptionLost() {
        print("⚠️ Subscription lost - disabling premium features")

        // Track if we need to recreate the container (which destroys and recreates views)
        let needsContainerRecreation = UserPreferences.shared.isCloudSyncEnabled

        // Disable iCloud sync if it was enabled
        if needsContainerRecreation {
            UserPreferences.shared.isCloudSyncEnabled = false

            // Notify the app to recreate ModelContainer without cloud sync
            NotificationCenter.default.post(
                name: NSNotification.Name("CloudSyncPreferenceChanged"),
                object: nil
            )

            print("   iCloud sync disabled")
        }

        // Update widget subscription status
        WidgetHelper.shared.updateSubscriptionStatus()

        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .subscriptionDidExpire,
            object: nil
        )

        // Set the expired flag after a delay if container recreation is needed
        // This allows the view hierarchy to be recreated before showing the alert
        // Otherwise the alert would be dismissed when the view is destroyed
        if needsContainerRecreation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.subscriptionJustExpired = true
            }
        } else {
            subscriptionJustExpired = true
        }
    }

    /// Check and disable iCloud sync if user doesn't have active subscription
    /// Called on app launch to ensure sync is disabled for non-subscribers
    private func checkAndDisableCloudSyncIfNeeded() async {
        // If iCloud sync is enabled but user is not subscribed, disable it
        if UserPreferences.shared.isCloudSyncEnabled && !isSubscribed {
            print("⚠️ iCloud sync was enabled but user is not subscribed - disabling")

            await MainActor.run {
                UserPreferences.shared.isCloudSyncEnabled = false

                // Notify the app to recreate ModelContainer without cloud sync
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloudSyncPreferenceChanged"),
                    object: nil
                )
            }
        }
    }

    /// Call this after showing the expiry alert to the user
    func acknowledgeExpiry() {
        subscriptionJustExpired = false
    }

    // MARK: - Computed Properties

    var subscriptionStatusMessage: String? {
        guard isSubscribed else { return nil }

        if isInTrialPeriod {
            if let expiration = subscriptionExpirationDate {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
                if daysLeft <= 1 {
                    return "Free trial ends today"
                }
                return "Free trial ends in \(daysLeft) days"
            } else {
                return "You're on a free trial"
            }
        } else if !willAutoRenew {
            if let expiration = subscriptionExpirationDate {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
                if daysLeft <= 0 {
                    return "Subscription expires today"
                } else if daysLeft == 1 {
                    return "Subscription expires tomorrow"
                }
                return "Subscription ends \(expiration.formatted(date: .abbreviated, time: .omitted))"
            } else {
                return "Subscription will not renew"
            }
        }

        return nil
    }

    var shouldShowRenewalWarning: Bool {
        guard isSubscribed else { return false }

        // Show warning if in trial
        if isInTrialPeriod {
            if let expiration = subscriptionExpirationDate {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
                return daysLeft <= 3
            }
            return false
        }

        // Show warning if subscription won't renew
        guard !willAutoRenew else { return false }

        if let expiration = subscriptionExpirationDate {
            let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
            return daysUntilExpiration <= 7
        }

        return true
    }

    /// Check if user is about to lose access (for showing warnings)
    var isAccessAtRisk: Bool {
        guard isSubscribed else { return false }

        if !willAutoRenew || isInTrialPeriod {
            if let expiration = subscriptionExpirationDate {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
                return daysLeft <= 3
            }
        }

        return false
    }

    // MARK: - Manual Subscription Control (for testing/debugging)

    func grantSubscription() {
        self.isSubscribed = true
        // Update widget subscription status
        WidgetHelper.shared.updateSubscriptionStatus()
    }

    func revokeSubscription() {
        self.isSubscribed = false
        // Update widget subscription status
        WidgetHelper.shared.updateSubscriptionStatus()
    }

    // MARK: - Doodle Limit Helpers

    /// Check if user can create a new doodle based on their plan
    func canCreateDoodle(currentTotalCount: Int) -> Bool {
        if hasUnlimitedDoodles {
            return true
        }
        return currentTotalCount < maxDoodlesAllowed
    }

    /// Get remaining doodles for free users
    func remainingDoodles(currentTotalCount: Int) -> Int {
        if hasUnlimitedDoodles {
            return Int.max
        }
        return max(0, maxDoodlesAllowed - currentTotalCount)
    }

    /// Get total count of doodles across all entries
    func totalDoodleCount(from entries: [DayEntry]) -> Int {
        return entries.filter { entry in
            entry.drawingData != nil
        }.count
    }

    /// Check if a specific doodle can be edited (by its index, 0-based)
    func canEditDoodle(atIndex index: Int) -> Bool {
        if hasUnlimitedDoodles {
            return true
        }
        // Free users can only edit their first N doodles
        return index < maxDoodlesAllowed
    }
}
