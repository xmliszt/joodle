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
import Network

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Stored Properties (persisted to UserDefaults)

    /// Whether user has an active subscription - computed from stored expiration date
    @Published private(set) var isSubscribed: Bool = false {
        didSet {
            // Don't trigger side effects during initialization to avoid circular dependency
            guard !isInitializing else { return }

            // Handle subscription state changes
            if oldValue && !isSubscribed {
                handleSubscriptionLost()
            } else if !oldValue && isSubscribed {
                handleSubscriptionGained()
            }
        }
    }

    @Published var isInTrialPeriod: Bool = false
    @Published var willAutoRenew: Bool = false

    /// Flag indicating subscription just expired (for UI alerts)
    @Published var subscriptionJustExpired: Bool = false

    /// The stored subscription expiration date - this is the source of truth for local checks
    var subscriptionExpirationDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "subscriptionExpirationDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "subscriptionExpirationDate")
        }
    }

    /// The stored product ID of the current subscription
    private var storedProductID: String? {
        get {
            UserDefaults.standard.string(forKey: "subscriptionProductID")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "subscriptionProductID")
        }
    }

    /// Last time subscription was successfully verified online with StoreKit
    private var lastOnlineVerificationDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastOnlineVerificationDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastOnlineVerificationDate")
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var expirationCheckTimer: Timer?

    /// Flag to prevent triggering side effects during initialization
    private var isInitializing = true

    /// Minimum interval between StoreKit refreshes (in seconds) to avoid rate limiting
    private let refreshInterval: TimeInterval = 30

    /// Last time we attempted a refresh (to implement rate limiting)
    private var lastRefreshAttempt: Date?

    // MARK: - Initialization

    private init() {
        // Set initial subscription state from stored date WITHOUT triggering didSet side effects
        if let expirationDate = subscriptionExpirationDate, Date() < expirationDate {
            isSubscribed = true
        }

        // Now allow side effects
        isInitializing = false

        // Start monitoring subscription status
        Task {
            // Refresh from StoreKit on launch to get latest status
            await refreshSubscriptionFromStoreKit()

            // Check iCloud sync status on launch - disable if not subscribed
            await checkAndDisableCloudSyncIfNeeded()

            // Check premium theme color on launch - reset to default if not subscribed
            await checkAndResetPremiumThemeColorIfNeeded()
        }

        // Set up periodic expiration check (local check, very lightweight)
        setupExpirationCheck()

        // Listen for app becoming active to refresh status from StoreKit
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

    // MARK: - Network-Aware Access Control

    /// Check if network is available for StoreKit verification
    private var isNetworkAvailable: Bool {
        // Use NetworkMonitor if available, otherwise return true to not block
        return NetworkMonitor.shared.isConnected
    }

    /// Verify subscription with online check before granting access
    /// Returns true if access should be granted, false otherwise
    @discardableResult func verifySubscriptionForAccess() async -> Bool {
        // If network is available, always refresh from StoreKit to get latest status
        if isNetworkAvailable {
            await refreshSubscriptionFromStoreKit()
            return isSubscribed
        }

        // Network is NOT available - check local expiry date
        // If subscription is still valid locally, allow access (safe assumption)
        // When user comes online, the expiry date will be auto-updated
        if let expirationDate = subscriptionExpirationDate, Date() < expirationDate {
            print("✅ Offline but subscription expiry date is still valid - allowing access")
            return isSubscribed
        }

        // Network unavailable AND (no expiry date OR expiry date has passed)
        // This is a security risk - deny access
        print("⚠️ Offline and subscription has expired locally - denying access")
        return false
    }

    // MARK: - Local Subscription Check

    /// Updates isSubscribed based on the stored expiration date (no network call)
    private func updateSubscribedStateFromStoredDate() {
        if let expirationDate = subscriptionExpirationDate {
            let wasSubscribed = isSubscribed
            let nowSubscribed = Date() < expirationDate

            // Only update if changed to avoid unnecessary didSet triggers
            if wasSubscribed != nowSubscribed {
                isSubscribed = nowSubscribed
            }
        } else {
            if isSubscribed {
                isSubscribed = false
            }
        }
    }

    // MARK: - StoreKit Refresh

    /// Refreshes subscription status from StoreKit and updates stored expiration date
    func refreshSubscriptionFromStoreKit() async {
        // Check if network is available
        // When offline, StoreKit returns inconsistent cached results
        // So we skip the StoreKit query and just use local expiry date
        guard isNetworkAvailable else {
            print("⚠️ Offline - skipping StoreKit refresh, using local expiry date")
            // Just check local expiry date
            updateSubscribedStateFromStoredDate()

            // Update widget subscription status
            WidgetHelper.shared.updateSubscriptionStatus()
            return
        }

        let storeManager = StoreKitManager.shared

        // Ensure products are loaded
        if storeManager.products.isEmpty {
            await storeManager.loadProducts()
        }

        // Query StoreKit for current subscription status (only when online)
        await storeManager.updatePurchasedProducts()

        // Update our stored state from StoreKit
        if storeManager.hasActiveSubscription {
            // Store the expiration date and product ID
            subscriptionExpirationDate = storeManager.subscriptionExpirationDate
            storedProductID = storeManager.currentProductID
            isInTrialPeriod = storeManager.isInTrialPeriod
            willAutoRenew = storeManager.willAutoRenew

            // Update subscribed state
            if !isSubscribed {
                isSubscribed = true
            }

            print("✅ Subscription active - expires: \(storeManager.subscriptionExpirationDate?.formatted() ?? "N/A")")
        } else {
            // StoreKit says no active subscription - immediately clear everything
            // StoreKit is the source of truth, stored date is just a cache
            subscriptionExpirationDate = nil
            storedProductID = nil
            isInTrialPeriod = false
            willAutoRenew = false

            if isSubscribed {
                isSubscribed = false
            }

            print("❌ Subscription not active - cleared stored data")
        }

        // Update last online verification timestamp (only when online)
        lastOnlineVerificationDate = Date()

        // Update widget subscription status
        WidgetHelper.shared.updateSubscriptionStatus()
    }

    /// Public method for external callers (maintains API compatibility)
    func updateSubscriptionStatus() async {
        await refreshSubscriptionFromStoreKit()
    }

    // MARK: - Expiration Monitoring

    private func setupExpirationCheck() {
        // Check every 30 seconds if subscription has expired (local check only)
        expirationCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkExpiration()
            }
        }
    }

    /// Local check - just compares current time with stored expiration date
    private func checkExpiration() {
        guard isSubscribed else { return }

        if let expirationDate = subscriptionExpirationDate {
            if Date() >= expirationDate {
                // Subscription has expired locally - refresh from StoreKit to confirm
                // (in case of renewal)
                Task {
                    await refreshSubscriptionFromStoreKit()
                }
            }
        }
    }

    @objc private func appDidBecomeActive() {
        // Refresh subscription status from StoreKit when app becomes active
        Task {
            await refreshSubscriptionFromStoreKit()
        }
    }

    @objc private func appWillResignActive() {
        // Update widget subscription status when app goes to background
        WidgetHelper.shared.updateSubscriptionStatus()
    }

    // MARK: - Subscription State Change Handling

    private func handleSubscriptionGained() {
        print("🎉 Subscription gained!")

        // Auto-enable iCloud sync when user upgrades or restores subscription
        if !UserPreferences.shared.isCloudSyncEnabled {
            let syncManager = CloudSyncManager.shared

            if syncManager.isCloudAvailable && syncManager.systemCloudEnabled {
                let cloudStore = NSUbiquitousKeyValueStore.default
                cloudStore.synchronize()
                let hadSyncEnabled = cloudStore.bool(forKey: "is_cloud_sync_enabled_backup") ||
                                     cloudStore.bool(forKey: "cloud_sync_was_enabled")

                print("   Auto-enabling iCloud sync for subscriber")
                if hadSyncEnabled {
                    print("   Detected previous sync history")
                }

                UserPreferences.shared.isCloudSyncEnabled = true

                cloudStore.set(true, forKey: "is_cloud_sync_enabled_backup")
                cloudStore.set(true, forKey: "cloud_sync_was_enabled")
                cloudStore.synchronize()
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
            WidgetHelper.shared.updateThemeColor()
        }

        let needsContainerRecreation = UserPreferences.shared.isCloudSyncEnabled

        if needsContainerRecreation {
            UserPreferences.shared.isCloudSyncEnabled = false

            let cloudStore = NSUbiquitousKeyValueStore.default
            cloudStore.set(false, forKey: "is_cloud_sync_enabled_backup")
            cloudStore.set(false, forKey: "cloud_sync_was_enabled")
            cloudStore.synchronize()

            print("   iCloud sync disabled and cloud state cleared")
        }

        // Update widget subscription status
        WidgetHelper.shared.updateSubscriptionStatus()

        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .subscriptionDidExpire,
            object: nil
        )

        // Set the expired flag
        if needsContainerRecreation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.subscriptionJustExpired = true
            }
        } else {
            subscriptionJustExpired = true
        }
    }

    // MARK: - Theme Color Check

    func checkAndResetPremiumThemeColorIfNeeded() async {
        guard !isSubscribed else { return }

        let currentColor = UserPreferences.shared.accentColor
        if currentColor.isPremium {
            print("🎨 Non-subscriber using premium color '\(currentColor.displayName)' - resetting to default")
            UserPreferences.shared.accentColor = ThemeColor.defaultColor
            WidgetHelper.shared.updateThemeColor()
        }
    }

    // MARK: - Cloud Sync Check

    func checkAndDisableCloudSyncIfNeeded() async {
        guard !isSubscribed else { return }

        if UserPreferences.shared.isCloudSyncEnabled {
            print("☁️ Non-subscriber has iCloud sync enabled - disabling")
            UserPreferences.shared.isCloudSyncEnabled = false

            let cloudStore = NSUbiquitousKeyValueStore.default
            cloudStore.set(false, forKey: "is_cloud_sync_enabled_backup")
            cloudStore.set(false, forKey: "cloud_sync_was_enabled")
            cloudStore.synchronize()
        }
    }

    /// Reset the expired flag (call after user acknowledges)
    func acknowledgeExpiry() {
        subscriptionJustExpired = false
    }

    // MARK: - Status Message

    var subscriptionStatusMessage: String? {
        guard isSubscribed else { return nil }

        if !willAutoRenew {
            if let expirationDate = subscriptionExpirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Expires \(formatter.string(from: expirationDate))"
            }
            return "Subscription ending"
        }

        if isInTrialPeriod {
            if let expirationDate = subscriptionExpirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Trial ends \(formatter.string(from: expirationDate))"
            }
            return "Free trial active"
        }

        return nil
    }

    func formatExpirationDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var shouldShowRenewalWarning: Bool {
        guard isSubscribed else { return false }

        if !willAutoRenew {
            return true
        }

        if isInTrialPeriod {
            if let expirationDate = subscriptionExpirationDate {
                let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                return daysUntilExpiry <= 3
            }
        }

        return false
    }

    var isAccessAtRisk: Bool {
        guard isSubscribed else { return false }

        if !willAutoRenew {
            if let expirationDate = subscriptionExpirationDate {
                let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                return daysUntilExpiry <= 7
            }
            return true
        }

        return false
    }

    // MARK: - Debug Methods

    #if DEBUG
    func grantSubscription() {
        // For testing: grant a 1-hour subscription
        subscriptionExpirationDate = Date().addingTimeInterval(3600)
        storedProductID = "debug.subscription"
        isSubscribed = true
    }

    func revokeSubscription() {
        subscriptionExpirationDate = nil
        storedProductID = nil
        isSubscribed = false
    }
    #endif

    // MARK: - Joodle Access Helpers (Synchronous - uses cached state)

    /// Synchronous check - uses cached subscription state
    /// For critical access points, use verifySubscriptionForAccess() first
    func canCreateJoodle(currentTotalCount: Int) -> Bool {
        if isSubscribed {
            return true
        }
        return currentTotalCount < Self.freeJoodlesAllowed
    }

    /// Async access check with online verification
    /// Use this before allowing creation of new Joodles
    func canCreateJoodleWithVerification(currentTotalCount: Int) async -> Bool {
        let hasAccess = await verifySubscriptionForAccess()
        if hasAccess {
            return true
        }
        return currentTotalCount < Self.freeJoodlesAllowed
    }

    func remainingJoodles(currentTotalCount: Int) -> Int {
        if isSubscribed {
            return Int.max
        }
        return max(0, Self.freeJoodlesAllowed - currentTotalCount)
    }

    func totalJoodleCount(from entries: [DayEntry]) -> Int {
        return entries.filter { entry in
            entry.drawingData != nil
        }.count
    }

    func fetchTotalJoodleCount(in modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<DayEntry>(
            predicate: #Predicate { entry in
                entry.drawingData != nil
            }
        )

        do {
            let count = try modelContext.fetchCount(descriptor)
            return count
        } catch {
            print("Error fetching Joodle count: \(error)")
            return 0
        }
    }

    func checkAccess(in modelContext: ModelContext) -> Bool {
        let totalCount = fetchTotalJoodleCount(in: modelContext)
        return canCreateJoodle(currentTotalCount: totalCount)
    }

    /// Async access check with online verification
    /// Use this before allowing Joodle creation
    func checkAccessWithVerification(in modelContext: ModelContext) async -> Bool {
        let totalCount = fetchTotalJoodleCount(in: modelContext)
        return await canCreateJoodleWithVerification(currentTotalCount: totalCount)
    }

    func canEditJoodle(entry: DayEntry, in modelContext: ModelContext) -> Bool {
        if isSubscribed {
            return true
        }

        let descriptor = FetchDescriptor<DayEntry>(
            predicate: #Predicate { entry in
                entry.drawingData != nil
            },
            sortBy: [SortDescriptor(\.dateString, order: .forward)]
        )

        do {
            let allJoodles = try modelContext.fetch(descriptor)
            guard let index = allJoodles.firstIndex(where: { $0.id == entry.id }) else {
                return true
            }
            return index < Self.freeJoodlesAllowed
        } catch {
            print("Error checking Joodle edit access: \(error)")
            return true
        }
    }

    func canEditJoodle(atIndex index: Int) -> Bool {
        if isSubscribed {
            return true
        }
        return index < Self.freeJoodlesAllowed
    }

    /// Async edit check with online verification
    /// Use this before allowing Joodle edits
    func canEditJoodleWithVerification(entry: DayEntry, in modelContext: ModelContext) async -> Bool {
        let hasAccess = await verifySubscriptionForAccess()
        if hasAccess {
            return true
        }

        // Fall back to checking if within free limit
        return canEditJoodle(entry: entry, in: modelContext)
    }

    /// Async edit check with online verification (by index)
    func canEditJoodleWithVerification(atIndex index: Int) async -> Bool {
        let hasAccess = await verifySubscriptionForAccess()
        if hasAccess {
            return true
        }
        return index < Self.freeJoodlesAllowed
    }
}
