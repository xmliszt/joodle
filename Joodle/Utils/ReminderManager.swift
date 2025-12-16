import Foundation
import UserNotifications
import SwiftUI
import Combine

struct Reminder: Codable, Identifiable {
    var id: String { dateString }
    let dateString: String
    let reminderDate: Date
    let entryBody: String?
}

@MainActor
class ReminderManager: ObservableObject {
    static let shared = ReminderManager()

    @Published private(set) var reminders: [Reminder] = []

    private let maxFreeReminders = 5
    private let storageKey = "joodle_reminders"
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadReminders()
        cleanupOutdatedReminders()
        setupForegroundObserver()
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
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Reminder].self, from: data) {
            self.reminders = decoded
        }
    }

    private func saveReminders() {
        if let encoded = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - Foreground Observer

    private func setupForegroundObserver() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.cleanupOutdatedReminders()
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
