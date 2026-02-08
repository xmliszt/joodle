//
//  GracePeriodManager.swift
//  Joodle
//
//  Manages the 7-day grace period for new users.
//  All new users get full Pro features for 7 days from first launch.
//  After expiry, a one-time paywall is shown, then users fall to free tier.
//

import Foundation
import Combine

@MainActor
class GracePeriodManager: ObservableObject {
    static let shared = GracePeriodManager()

    // MARK: - Constants

    /// Grace period duration: 7 days
    static let gracePeriodDuration: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Storage Keys

    private static let startDateKey = "grace_period_start_date"
    private static let paywallShownKey = "has_shown_grace_expired_paywall"

    // MARK: - Published Properties

    /// Whether the user is currently in the grace period (has Pro access for free)
    @Published private(set) var isInGracePeriod: Bool = false

    /// Number of days remaining in the grace period
    @Published private(set) var gracePeriodDaysRemaining: Int = 0

    /// Whether the grace period has expired (start date exists but 7+ days elapsed)
    @Published private(set) var hasGracePeriodExpired: Bool = false

    // MARK: - Private Properties

    private let cloudStore = NSUbiquitousKeyValueStore.default
    private var expirationTimer: Timer?

    /// Flag to prevent multiple simultaneous starts
    private var hasAttemptedStart = false

    // MARK: - Initialization

    private init() {
        // Sync iCloud KVS → UserDefaults on init
        cloudStore.synchronize()
        restoreFromCloudIfNeeded()

        // Calculate initial state
        updateState()

        // Set up periodic state check (every 60 seconds)
        setupExpirationCheck()

        // Listen for iCloud KVS external changes (e.g., from another device)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
    }

    deinit {
        expirationTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Start the grace period if not already started.
    /// Called on every app launch — only sets the start date once.
    /// Safe to call multiple times (idempotent).
    func startGracePeriodIfNeeded() {
        guard !hasAttemptedStart else { return }
        hasAttemptedStart = true

        // Check if a start date already exists (in either store)
        if gracePeriodStartDate != nil {
            updateState()
            return
        }

        // No start date anywhere — this is a brand new user (or first launch after update)
        let now = Date()
        setStartDate(now)
        updateState()

        // Track analytics
        AnalyticsManager.shared.trackGracePeriodStarted(startDate: now)

        print("🎉 Grace period started: \(now) — expires \(now.addingTimeInterval(Self.gracePeriodDuration))")
    }

    /// Whether the one-time grace-expired paywall should be shown
    var shouldShowGraceExpiredPaywall: Bool {
        // Only show if grace period has expired, not yet shown, and user is not subscribed
        guard hasGracePeriodExpired else { return false }
        guard !hasShownGraceExpiredPaywall else { return false }
        guard !SubscriptionManager.shared.hasPremiumAccess else { return false }
        return true
    }

    /// Mark the grace-expired paywall as shown (call after dismissing the sheet)
    func markGraceExpiredPaywallShown() {
        UserDefaults.standard.set(true, forKey: Self.paywallShownKey)
        cloudStore.set(true, forKey: Self.paywallShownKey)
        cloudStore.synchronize()
    }

    /// The date when the grace period expires (nil if not started)
    var gracePeriodExpirationDate: Date? {
        guard let startDate = gracePeriodStartDate else { return nil }
        return startDate.addingTimeInterval(Self.gracePeriodDuration)
    }

    // MARK: - Private Helpers

    /// Read the grace period start date from UserDefaults (cache) or iCloud KVS (primary)
    private var gracePeriodStartDate: Date? {
        // Check local cache first (faster)
        if let localDate = UserDefaults.standard.object(forKey: Self.startDateKey) as? Date {
            return localDate
        }
        // Fall back to iCloud KVS
        if let cloudDate = cloudStore.object(forKey: Self.startDateKey) as? Date {
            // Restore to local cache
            UserDefaults.standard.set(cloudDate, forKey: Self.startDateKey)
            return cloudDate
        }
        return nil
    }

    /// Whether the grace-expired paywall has already been shown
    private var hasShownGraceExpiredPaywall: Bool {
        UserDefaults.standard.bool(forKey: Self.paywallShownKey) ||
        cloudStore.bool(forKey: Self.paywallShownKey)
    }

    /// Write the start date to both stores
    private func setStartDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: Self.startDateKey)
        cloudStore.set(date, forKey: Self.startDateKey)
        cloudStore.synchronize()
    }

    /// Restore iCloud KVS data to UserDefaults if local is missing
    private func restoreFromCloudIfNeeded() {
        // Restore start date
        if UserDefaults.standard.object(forKey: Self.startDateKey) == nil,
           let cloudDate = cloudStore.object(forKey: Self.startDateKey) as? Date {
            UserDefaults.standard.set(cloudDate, forKey: Self.startDateKey)
            print("☁️ Restored grace period start date from iCloud KVS: \(cloudDate)")
        }

        // Restore paywall shown flag
        if !UserDefaults.standard.bool(forKey: Self.paywallShownKey) &&
            cloudStore.bool(forKey: Self.paywallShownKey) {
            UserDefaults.standard.set(true, forKey: Self.paywallShownKey)
            print("☁️ Restored grace expired paywall flag from iCloud KVS")
        }
    }

    /// Recalculate the published state from the stored start date
    private func updateState() {
        guard let startDate = gracePeriodStartDate else {
            isInGracePeriod = false
            hasGracePeriodExpired = false
            gracePeriodDaysRemaining = 0
            return
        }

        let elapsed = Date().timeIntervalSince(startDate)
        let remaining = Self.gracePeriodDuration - elapsed

        if remaining > 0 {
            isInGracePeriod = true
            hasGracePeriodExpired = false
            // Ceiling: even 0.1 days remaining shows as "1 day"
            gracePeriodDaysRemaining = max(1, Int(ceil(remaining / (24 * 60 * 60))))
        } else {
            let wasInGracePeriod = isInGracePeriod
            isInGracePeriod = false
            hasGracePeriodExpired = true
            gracePeriodDaysRemaining = 0

            if wasInGracePeriod {
                // Grace period just expired — track it
                AnalyticsManager.shared.trackGracePeriodExpired()
                print("⏰ Grace period expired")

                // Reset premium features to free tier defaults if user is not subscribed
                if !SubscriptionManager.shared.isSubscribed {
                    SubscriptionManager.shared.resetPremiumFeaturesToDefaults()
                    print("   Premium features reset to free tier defaults")
                }
            }
        }
    }

    // MARK: - Expiration Monitoring

    private func setupExpirationCheck() {
        // Check every 60 seconds if grace period state changed
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateState()
            }
        }
    }

    @objc private func cloudStoreDidChange(_ notification: Notification) {
        // iCloud KVS changed externally — restore and recalculate
        restoreFromCloudIfNeeded()
        updateState()
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// Reset grace period for testing (clears both stores)
    func resetGracePeriod() {
        UserDefaults.standard.removeObject(forKey: Self.startDateKey)
        UserDefaults.standard.removeObject(forKey: Self.paywallShownKey)
        cloudStore.removeObject(forKey: Self.startDateKey)
        cloudStore.removeObject(forKey: Self.paywallShownKey)
        cloudStore.synchronize()
        hasAttemptedStart = false
        updateState()
        print("🔄 Grace period reset")
    }

    /// Set a custom start date for testing
    func setGracePeriodStart(_ date: Date) {
        setStartDate(date)
        hasAttemptedStart = true
        updateState()
    }
    #endif
}
