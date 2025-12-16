import SwiftUI

struct ReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let dateString: String
    let entryBody: String?
    @StateObject private var reminderManager = ReminderManager.shared
    @State private var selectedTime: Date
    @State private var showPaywall = false
    @State private var showPastTimeAlert = false

    private var hasExistingReminder: Bool {
        reminderManager.getReminder(for: dateString) != nil
    }

    init(dateString: String, entryBody: String? = nil) {
        self.dateString = dateString
        self.entryBody = entryBody
        // Default to 9 AM on the entry date if no reminder exists
        if let existing = ReminderManager.shared.getReminder(for: dateString) {
            _selectedTime = State(initialValue: existing.reminderDate)
        } else if let entryDate = DayEntry.stringToLocalDate(dateString) {
            // Set to 9 AM on that day
            var components = Calendar.current.dateComponents([.year, .month, .day], from: entryDate)
            components.hour = 9
            components.minute = 0
            _selectedTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
        } else {
            _selectedTime = State(initialValue: Date())
        }
    }

    /// Combines the entry date with the selected time
    private var combinedReminderDate: Date {
        guard let entryDate = DayEntry.stringToLocalDate(dateString) else {
            return selectedTime
        }

        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: entryDate)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute

        return Calendar.current.date(from: dateComponents) ?? selectedTime
    }

    /// Whether the combined reminder date is in the past
    private var isReminderInPast: Bool {
        combinedReminderDate <= Date()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Time picker
                DatePicker("Reminder Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 120)

                // Set/Update button
                Button {
                    // Debug logging
                    let formatter = DateFormatter()
                    formatter.dateStyle = .full
                    formatter.timeStyle = .long
                    formatter.timeZone = .current

                    // Check if reminder time is in the past
                    if isReminderInPast {
                        showPastTimeAlert = true
                        return
                    }

                    if reminderManager.addReminder(for: dateString, at: combinedReminderDate, entryBody: entryBody) {
                        dismiss()
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Text(hasExistingReminder ? "Update Reminder" : "Set Reminder")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .reminderButtonStyle()
                .padding(.horizontal)
            }
            .padding(.top, 20)
            .navigationTitle(dateString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.appTextPrimary)
                }

                if hasExistingReminder {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) {
                            reminderManager.removeReminder(for: dateString)
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                StandalonePaywallView()
            }
            .alert("Invalid Reminder Time", isPresented: $showPastTimeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The selected time has already passed. Please choose a future time for your reminder.")
            }
        }
        .onAppear {
            reminderManager.requestNotificationPermission()
        }
    }
}

// MARK: - Reminder Button Style

private struct ReminderButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .foregroundColor(.appBackground)
                .frame(height: 48)
                .background(.appAccent)
                .clipShape(Capsule())
                .glassEffect(.regular.interactive())
        } else {
            content
                .foregroundColor(.appBackground)
                .frame(height: 48)
                .background(.appAccent)
                .clipShape(Capsule())
                .shadow(color: .appBackground.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

private extension View {
    func reminderButtonStyle() -> some View {
        self.modifier(ReminderButtonStyleModifier())
    }
}

// MARK: - Preview

#Preview("No Reminder") {
    ReminderSheet(dateString: DayEntry.dateToString(Date()))
}

#Preview("With Entry Body") {
    ReminderSheet(dateString: DayEntry.dateToString(Date().addingTimeInterval(86400)), entryBody: "Meeting with the team to discuss project updates")
}
