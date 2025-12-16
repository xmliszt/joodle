import Foundation
import UserNotifications
import SwiftUI
import Combine

struct Reminder: Codable, Identifiable, Equatable {
    var id: String { dateString }
    let dateString: String
    let reminderDate: Date
    let entryBody: String?

    static func == (lhs: Reminder, rhs: Reminder) -> Bool {
        lhs.dateString == rhs.dateString &&
        lhs.reminderDate == rhs.reminderDate &&
        lhs.entryBody == rhs.entryBody
    }
}

@MainActor
class ReminderManager: ObservableObject {
    static let shared = ReminderManager()

    @Published private(set) var reminders: [Reminder] = []

    private let maxFreeReminders = 5
    private let localStorageKey = "joodle_reminders"
    private let cloudStorageKey = "joodle_reminders_cloud"
    private var cancellables = Set<AnyCancellable>()

    // iCloud Key-Value Store
    private let cloudStore = NSUbiquitousKeyValueStore.default
    private var cloudChangeObserver: NSObjectProtocol?

    private init() {
        loadReminders()
        cleanupOutdatedReminders()
        setupForegroundObserver()
        setupCloudObserver()

        // Perform initial sync from cloud
        syncFromCloud()
    }

    deinit {
        // Remove observer directly in deinit since it's nonisolated
        if let observer = cloudChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Properties

    /// Number of remaining free reminders available
    var remainingFreeReminders: Int {
        max(0, maxFreeReminders - reminders.count)
    }

    /// Whether the user has reached the free reminder limit
    var hasReachedFreeLimit: Bool {
        !SubscriptionManager.shared.isSubscribed && reminders.count >= maxFreeReminders
    }

    // MARK: - Persistence

    private func loadReminders() {
        if let data = UserDefaults.standard.data(forKey: localStorageKey),
           let decoded = try? JSONDecoder().decode([Reminder].self, from: data) {
            self.reminders = decoded
        }
    }

    private func saveReminders() {
        if let encoded = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(encoded, forKey: localStorageKey)
        }

        // Also sync to iCloud if cloud sync is enabled
        syncToCloud()
    }

    // MARK: - iCloud Sync

    private func setupCloudObserver() {
        // Observe changes from other devices
        cloudChangeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleCloudChange(notification)
            }
        }

        // Start observing iCloud KVS
        cloudStore.synchronize()
    }

    private func removeCloudObserver() {
        if let observer = cloudChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            cloudChangeObserver = nil
        }
    }

    private func handleCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonForChange = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        switch reasonForChange {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange,
             NSUbiquitousKeyValueStoreAccountChange:
            syncFromCloud()
        default:
            break
        }
    }

    /// Push local reminders to iCloud
    private func syncToCloud() {
        guard UserPreferences.shared.isCloudSyncEnabled else { return }

        guard let encoded = try? JSONEncoder().encode(reminders) else { return }

        cloudStore.set(encoded, forKey: cloudStorageKey)
        cloudStore.synchronize()
    }

    /// Pull reminders from iCloud and merge with local
    private func syncFromCloud() {
        guard UserPreferences.shared.isCloudSyncEnabled else { return }

        cloudStore.synchronize()

        guard let data = cloudStore.data(forKey: cloudStorageKey),
              let cloudReminders = try? JSONDecoder().decode([Reminder].self, from: data) else {
            return
        }

        mergeReminders(from: cloudReminders)
    }

    /// Merge reminders from cloud with local reminders
    /// Strategy: Keep the most recent version of each reminder (by reminderDate)
    /// and add any reminders that exist only in cloud
    private func mergeReminders(from cloudReminders: [Reminder]) {
        var merged: [String: Reminder] = [:]

        // Add all local reminders first
        for reminder in reminders {
            merged[reminder.dateString] = reminder
        }

        // Merge cloud reminders - prefer the one with the later reminderDate
        var hasChanges = false
        for cloudReminder in cloudReminders {
            if let existing = merged[cloudReminder.dateString] {
                if cloudReminder.reminderDate > existing.reminderDate {
                    merged[cloudReminder.dateString] = cloudReminder
                    hasChanges = true
                }
            } else {
                merged[cloudReminder.dateString] = cloudReminder
                hasChanges = true
            }
        }

        if hasChanges {
            let newReminders = Array(merged.values)

            // Cancel all existing notifications
            for reminder in reminders {
                cancelNotification(for: reminder)
            }

            reminders = newReminders

            // Save to local storage (but don't trigger another cloud sync)
            if let encoded = try? JSONEncoder().encode(reminders) {
                UserDefaults.standard.set(encoded, forKey: localStorageKey)
            }

            // Reschedule notifications for all reminders
            for reminder in reminders {
                scheduleNotification(for: reminder)
            }
        }
    }

    /// Force a full sync (pull then push)
    func performFullSync() {
        guard UserPreferences.shared.isCloudSyncEnabled else { return }
        syncFromCloud()
        syncToCloud()
    }

    // MARK: - Foreground Observer

    private func setupForegroundObserver() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.cleanupOutdatedReminders()
                    self?.syncFromCloud()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Reminder Management

    func canAddReminder() -> Bool {
        if SubscriptionManager.shared.isSubscribed {
            return true
        }
        return reminders.count < maxFreeReminders
    }

    @discardableResult
    func addReminder(for dateString: String, at date: Date, entryBody: String? = nil) -> Bool {
        // Debug logging
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .long
        formatter.timeZone = .current

        print("════════════════════════════════════════════")
        print("📝 [ReminderManager] addReminder called")
        print("   - dateString: \(dateString)")
        print("   - requested date: \(formatter.string(from: date))")
        print("   - current time: \(formatter.string(from: now))")
        print("   - date timestamp: \(date.timeIntervalSince1970)")
        print("   - now timestamp: \(now.timeIntervalSince1970)")
        print("   - difference (seconds): \(date.timeIntervalSince(now))")
        print("   - is in future: \(date > now)")
        print("   - timezone: \(TimeZone.current.identifier)")

        // Check limit if adding new reminder (not updating existing)
        let isUpdating = reminders.contains(where: { $0.dateString == dateString })
        if !isUpdating && !canAddReminder() {
            print("❌ [ReminderManager] Cannot add reminder - limit reached")
            return false
        }

        // Remove existing reminder for this dateString if any
        removeReminder(for: dateString, notify: false)

        let reminder = Reminder(dateString: dateString, reminderDate: date, entryBody: entryBody)
        reminders.append(reminder)
        saveReminders()
        scheduleNotification(for: reminder)

        // Verify pending notifications
        printPendingNotifications()

        return true
    }

    func removeReminder(for dateString: String, notify: Bool = true) {
        if let reminder = reminders.first(where: { $0.dateString == dateString }) {
            cancelNotification(for: reminder)
            reminders.removeAll { $0.dateString == dateString }
            if notify {
                saveReminders()
            }
        }
    }

    func getReminder(for dateString: String) -> Reminder? {
        return reminders.first(where: { $0.dateString == dateString })
    }

    func cleanupOutdatedReminders() {
        let now = Date()
        let outdated = reminders.filter { $0.reminderDate < now }

        guard !outdated.isEmpty else { return }

        for reminder in outdated {
            cancelNotification(for: reminder)
        }
        reminders.removeAll { $0.reminderDate < now }
        saveReminders()
    }

    // MARK: - Notifications

    private func scheduleNotification(for reminder: Reminder) {
        let now = Date()

        // Debug logging
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .long
        formatter.timeZone = .current

        print("────────────────────────────────────────────")
        print("🔔 [ReminderManager] scheduleNotification called")
        print("   - Reminder ID: \(reminder.id)")
        print("   - Current time: \(formatter.string(from: now))")
        print("   - Scheduled time: \(formatter.string(from: reminder.reminderDate))")
        print("   - Time until trigger: \(reminder.reminderDate.timeIntervalSince(now)) seconds")

        // Check if the reminder date is in the past
        if reminder.reminderDate <= now {
            print("⚠️ [ReminderManager] WARNING: Reminder date is in the PAST! Skipping notification.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Joodle Reminder"
        content.body = formatNotificationBody(for: reminder)
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminder.reminderDate
        )
        print("   - Date components: year=\(components.year ?? 0), month=\(components.month ?? 0), day=\(components.day ?? 0), hour=\(components.hour ?? 0), minute=\(components.minute ?? 0), second=\(components.second ?? 0)")

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        print("   - Next trigger date: \(String(describing: trigger.nextTriggerDate()))")

        let request = UNNotificationRequest(
            identifier: reminder.id,
            content: content,
            trigger: trigger
        )

        // Check authorization status first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("   - Authorization status: \(settings.authorizationStatus.rawValue)")
            print("   - Alert setting: \(settings.alertSetting.rawValue)")
            print("   - Sound setting: \(settings.soundSetting.rawValue)")

            if settings.authorizationStatus != .authorized {
                print("❌ [ReminderManager] Notifications NOT authorized!")
                return
            }

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ [ReminderManager] Error scheduling notification: \(error)")
                } else {
                    print("✅ [ReminderManager] Notification scheduled successfully for \(reminder.id)")
                }
            }
        }
    }

    /// Debug function to print all pending notifications
    func printPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("────────────────────────────────────────────")
            print("📋 [ReminderManager] Pending notifications: \(requests.count)")
            for request in requests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    print("   - ID: \(request.identifier)")
                    print("     Title: \(request.content.title)")
                    print("     Next trigger: \(String(describing: trigger.nextTriggerDate()))")
                    print("     Date components: \(trigger.dateComponents)")
                }
            }
            print("════════════════════════════════════════════")
        }
    }

    private func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.id]
        )
    }

    private func formatNotificationBody(for reminder: Reminder) -> String {
        // Use entry body if available and not empty
        if let body = reminder.entryBody, !body.isEmpty {
            // Truncate if too long for notification
            let maxLength = 100
            if body.count > maxLength {
                return String(body.prefix(maxLength)) + "..."
            }
            return body
        }

        // Fallback to default text with formatted date
        guard let date = DayEntry.stringToLocalDate(reminder.dateString) else {
            return "Time to check your Joodle!"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        let formattedDate = formatter.string(from: date)

        return "Time to check your Joodle for \(formattedDate)"
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            }
            if granted {
                print("Notification permission granted")
            }
        }
    }

    /// Check current notification authorization status
    func checkNotificationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
