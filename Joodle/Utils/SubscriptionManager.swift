//
//  SubscriptionManager.swift
//  Joodle
//
//  Created by Subscription Manager
//

import Foundation
import Combine
import StoreKit
import SwiftData

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

            // Check premium theme color on launch - reset to default if not subscribed
            await checkAndResetPremiumThemeColorIfNeeded()
            // Note: Widget subscription status is now updated inside updateSubscriptionStatus()
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

        // Listen for app entering background to update widget status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    deinit {
        expirationCheckTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Subscription Features

    var hasUnlimitedJoodles: Bool {
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

    var hasWatermarkRemoval: Bool {
        isSubscribed
    }

    // Free plan limits - maximum total Joodles allowed for free users
    nonisolated static let freeJoodlesAllowed = 30

    var maxJoodlesAllowed: Int {
        isSubscribed ? Int.max : Self.freeJoodlesAllowed
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
        self.isSubscribed = storeManager.hasActiveSubscription
        self.isInTrialPeriod = storeManager.isInTrialPeriod
        self.subscriptionExpirationDate = storeManager.subscriptionExpirationDate
        self.willAutoRenew = storeManager.willAutoRenew

        // Note: handleSubscriptionLost() and handleSubscriptionGained() are called
        // automatically by the didSet observer on isSubscribed when the value changes

        // Always update widget subscription status after StoreKit refresh
        // This ensures widgets have the latest subscription state
        WidgetHelper.shared.updateSubscriptionStatus()
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

    @objc private func appWillResignActive() {
        // Update widget subscription status when app goes to background
        // This ensures widget has fresh data even if the app isn't opened for a while
        WidgetHelper.shared.updateSubscriptionStatus()
    }

    // MARK: - Subscription State Change Handling

    private func handleSubscriptionGained() {
        // Auto-enable iCloud sync when user upgrades or restores subscription
        if !UserPreferences.shared.isCloudSyncEnabled {
            // Check if system requirements are met for iCloud sync
            let syncManager = CloudSyncManager.shared

            if syncManager.isCloudAvailable && syncManager.systemCloudEnabled {
                // Check if this is a reinstall with existing iCloud data
                let cloudStore = NSUbiquitousKeyValueStore.default
                cloudStore.synchronize()
                let hadSyncEnabled = cloudStore.bool(forKey: "is_cloud_sync_enabled_backup") ||
                                     cloudStore.bool(forKey: "cloud_sync_was_enabled")

                print("   Auto-enabling iCloud sync for subscriber")
                if hadSyncEnabled {
                    print("   Detected previous sync history")
                }

                UserPreferences.shared.isCloudSyncEnabled = true

                // Save sync state to iCloud KVS for future reinstall recovery
                cloudStore.set(true, forKey: "is_cloud_sync_enabled_backup")
                cloudStore.set(true, forKey: "cloud_sync_was_enabled")
                cloudStore.synchronize()

                // Note: Container was already created at app launch
                // ModelContainerManager.needsRestartForSyncChange will be checked by UI
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

        // Reset premium theme color to default if user was using a premium color
        let currentColor = UserPreferences.shared.accentColor
        if currentColor.isPremium {
            print("   Resetting premium theme color '\(currentColor.displayName)' to default '\(ThemeColor.defaultColor.displayName)'")
            UserPreferences.shared.accentColor = ThemeColor.defaultColor
            // Update widgets with the new theme color
            WidgetHelper.shared.updateThemeColor()
        }

        // Track if we need to recreate the container (which destroys and recreates views)
        let needsContainerRecreation = UserPreferences.shared.isCloudSyncEnabled

        // Disable iCloud sync if it was enabled
        if needsContainerRecreation {
            UserPreferences.shared.isCloudSyncEnabled = false

            // Also clear the iCloud KVS sync state so reinstall won't auto-enable
            // without a valid subscription
            let cloudStore = NSUbiquitousKeyValueStore.default
            cloudStore.set(false, forKey: "is_cloud_sync_enabled_backup")
            cloudStore.set(false, forKey: "cloud_sync_was_enabled")
            cloudStore.synchronize()

            // Note: ModelContainerManager.needsRestartForSyncChange will be checked by UI

            print("   iCloud sync disabled and cloud state cleared")
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

    /// Check and reset premium theme color if user doesn't have active subscription
    /// Called on app launch to ensure premium colors are not used by non-subscribers
    private func checkAndResetPremiumThemeColorIfNeeded() async {
        let currentColor = UserPreferences.shared.accentColor
        if currentColor.isPremium && !isSubscribed {
            print("⚠️ Premium theme color '\(currentColor.displayName)' was selected but user is not subscribed - resetting to default")

            await MainActor.run {
                UserPreferences.shared.accentColor = ThemeColor.defaultColor
                // Update widgets with the new theme color
                WidgetHelper.shared.updateThemeColor()
            }
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

                // Also clear the iCloud KVS sync state so reinstall won't auto-enable
                // without a valid subscription
                let cloudStore = NSUbiquitousKeyValueStore.default
                cloudStore.set(false, forKey: "is_cloud_sync_enabled_backup")
                cloudStore.set(false, forKey: "cloud_sync_was_enabled")
                cloudStore.synchronize()

                // Note: ModelContainerManager.needsRestartForSyncChange will be checked by UI
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
                return "Subscription ends \(formatExpirationDate(expiration))"
            } else {
                return "Subscription will not renew"
            }
        }

        return nil
    }

    private func formatExpirationDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        let timeZoneAbbreviation = formatter.timeZone.abbreviation() ?? ""
        return "\(formatter.string(from: date)) (\(timeZoneAbbreviation))"
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

    // MARK: - Drawing Protection for Initial Sync

    /// Check if today has a drawing in the current local database and protect it
    // MARK: - Joodle Limit Helpers

    /// Check if user can create a new Joodle based on their plan
    func canCreateJoodle(currentTotalCount: Int) -> Bool {
        if hasUnlimitedJoodles {
            return true
        }
        return currentTotalCount < maxJoodlesAllowed
    }

    /// Get remaining Joodles for free users
    func remainingJoodles(currentTotalCount: Int) -> Int {
        if hasUnlimitedJoodles {
            return Int.max
        }
        return max(0, maxJoodlesAllowed - currentTotalCount)
    }

    /// Get total count of Joodles across all entries
    func totalJoodleCount(from entries: [DayEntry]) -> Int {
        return entries.filter { entry in
            entry.drawingData != nil
        }.count
    }

    /// Check if a specific Joodle can be edited (by its index, 0-based)
    func canEditJoodle(atIndex index: Int) -> Bool {
        if hasUnlimitedJoodles {
            return true
        }
        // Free users can only edit their first N Joodles
        return index < maxJoodlesAllowed
    }
}
