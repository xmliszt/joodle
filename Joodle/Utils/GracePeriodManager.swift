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
@preconcurrency import UserNotifications

@MainActor
class GracePeriodManager: ObservableObject {
    static let shared = GracePeriodManager()

    // MARK: - Constants

    /// Grace period duration: 7 days
    static let gracePeriodDuration: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Storage Keys

    private static let startDateKey = "grace_period_start_date"
    private static let paywallShownKey = "has_shown_grace_expired_paywall"

    /// Identifier for the gentle "trial ending soon" local notification.
    private static let trialReminderIdentifier = "joodle_trial_reminder"

    /// Fire the trial reminder this long before expiry (2 days → at day 5 of a 7-day trial).
    static let trialReminderLeadTime: TimeInterval = 2 * 24 * 60 * 60

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
        reconcileWithCloud()

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
            scheduleTrialReminderIfNeeded()
            return
        }

        // No start date anywhere — this is a brand new user (or first launch after update)
        let now = Date()
        setStartDate(now)
        updateState()
        scheduleTrialReminderIfNeeded()

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

    /// Fraction (0...1) of the trial elapsed, for the timeline progress fill.
    /// 0 when not started; 1 once expired.
    var gracePeriodProgress: Double {
        guard let startDate = gracePeriodStartDate else { return 0 }
        let elapsed = Date().timeIntervalSince(startDate)
        return min(max(elapsed / Self.gracePeriodDuration, 0), 1)
    }

    /// 1-based day of the trial (Day 1 starts at the trial start date), or nil
    /// if the trial never started. Keeps counting past the trial's end.
    var currentTrialDay: Int? {
        guard let startDate = gracePeriodStartDate else { return nil }
        let elapsed = Date().timeIntervalSince(startDate)
        guard elapsed >= 0 else { return 1 }
        return Int(elapsed / (24 * 60 * 60)) + 1
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

    /// Reconcile trial state between UserDefaults and iCloud KVS, keeping the
    /// earliest start date seen anywhere. On the first launch after a
    /// reinstall, both stores look empty and a fresh date gets written before
    /// the old one syncs down from iCloud — taking the minimum lets the
    /// late-arriving original win, so reinstalling never restarts the trial.
    private func reconcileWithCloud() {
        let localDate = UserDefaults.standard.object(forKey: Self.startDateKey) as? Date
        let cloudDate = cloudStore.object(forKey: Self.startDateKey) as? Date

        if let earliest = [localDate, cloudDate].compactMap({ $0 }).min() {
            if localDate != earliest {
                UserDefaults.standard.set(earliest, forKey: Self.startDateKey)
                print("☁️ Grace period start snapped back to earliest known date: \(earliest)")
            }
            if cloudDate != earliest {
                cloudStore.set(earliest, forKey: Self.startDateKey)
                cloudStore.synchronize()
            }
        }

        // Paywall-shown is shown-anywhere-wins, mirroring the same idea.
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

            // No reminder needed once the trial is over.
            cancelTrialReminder()

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
        // KVS change notifications are delivered on a background thread; hop to
        // the main actor before touching the @Published state.
        Task { @MainActor in
            reconcileWithCloud()
            updateState()
            // The start date may have snapped back — move the reminder with it.
            scheduleTrialReminderIfNeeded()
        }
    }

    // MARK: - Trial Reminder

    /// Schedule a gentle local notification ~2 days before the trial ends (day 5 of 7).
    /// Idempotent: re-adding with the same identifier replaces any existing one.
    /// No-op for subscribers, or once the reminder date has already passed.
    func scheduleTrialReminderIfNeeded() {
        // Subscribers don't need a trial reminder.
        guard !SubscriptionManager.shared.isSubscribed else {
            cancelTrialReminder()
            return
        }
        guard let startDate = gracePeriodStartDate else { return }

        let fireDate = startDate.addingTimeInterval(Self.gracePeriodDuration - Self.trialReminderLeadTime)
        guard fireDate > Date() else { return }  // day 5 already passed — nothing to schedule

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.trialReminderIdentifier,
            content: trialReminderContent(),
            trigger: trigger
        )

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ [GracePeriod] Error scheduling trial reminder: \(error)")
                } else {
                    print("✅ [GracePeriod] Trial reminder scheduled for \(fireDate)")
                }
            }
        }
    }

    /// Cancel the pending trial reminder, if any.
    func cancelTrialReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.trialReminderIdentifier]
        )
    }

    /// Warm, pressure-free copy for the trial reminder. Joodle's trial has no auto-charge,
    /// so the tone reassures rather than warns — the user simply returns to Free, data intact.
    private func trialReminderContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "2 more days of Joodle Pro ✨")
        content.body = String(localized: "Hope you're loving Pro! You've got 2 more days of unlimited entries, every widget, and watermark-free sharing. When it ends, nothing's charged — you'll just move to Free.")
        content.sound = .default
        content.userInfo = ["isTrialReminder": true]
        return content
    }

    // MARK: - Testing Methods (Non-Production)

    /// Reset grace period for testing (clears both stores).
    /// Available in all builds so TestFlight/sandbox can run reviewer flows.
    func resetGracePeriod() {
        guard AppEnvironment.isActuallyNonProduction else {
            return
        }

        UserDefaults.standard.removeObject(forKey: Self.startDateKey)
        UserDefaults.standard.removeObject(forKey: Self.paywallShownKey)
        cloudStore.removeObject(forKey: Self.startDateKey)
        cloudStore.removeObject(forKey: Self.paywallShownKey)
        cloudStore.synchronize()
        hasAttemptedStart = false
        cancelTrialReminder()
        updateState()
        print("🔄 Grace period reset")
    }

    /// Fire the trial reminder notification shortly (for testing its copy/appearance).
    /// Background the app within a few seconds to see it on the lock screen.
    func sendTrialReminderNow() {
        guard AppEnvironment.isActuallyNonProduction else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.trialReminderIdentifier + "_debug",
            content: trialReminderContent(),
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [GracePeriod] Error sending test trial reminder: \(error)")
            } else {
                print("✅ [GracePeriod] Test trial reminder will fire in 5s")
            }
        }
    }

    /// Set a custom start date for testing.
    /// Available in all builds so TestFlight/sandbox can run reviewer flows.
    func setGracePeriodStart(_ date: Date) {
        guard AppEnvironment.isActuallyNonProduction else {
            return
        }

        setStartDate(date)
        hasAttemptedStart = true
        updateState()
    }
}
