//
//  DailyReminderConfigView.swift
//  Joodle
//
//  Created by AI Assistant
//

import SwiftUI

/// Onboarding step for configuring daily reminders
/// Shown after iCloud config to encourage users to set up daily notifications
struct DailyReminderConfigView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @StateObject private var reminderManager = ReminderManager.shared

    @State private var enableReminder: Bool
    @State private var reminderTime: Date
    @State private var showNotificationDeniedAlert = false
    @State private var isRequestingPermission = false
    @State private var wiggleTrigger = false

    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
        // During revisit onboarding, initialize based on current preference
        // During first onboarding, default to true to encourage enabling
        let isRevisiting = viewModel.isRevisitingOnboarding
        self._enableReminder = State(initialValue: isRevisiting
            ? UserPreferences.shared.isDailyReminderEnabled
            : true)
        self._reminderTime = State(initialValue: UserPreferences.shared.dailyReminderTime)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.appBorder.opacity(0.4))
                        .frame(width: 100, height: 100)

                  if #available(iOS 18.0, *) {
                    Image(systemName: enableReminder ? "bell.badge.fill" : "bell.slash")
                      .font(.system(size: 48))
                      .foregroundStyle(.appAccent)
                      .contentTransition(.symbolEffect(.replace))
                      .symbolEffect(.wiggle.byLayer, options: .nonRepeating, value: wiggleTrigger)
                  } else {
                    // Fallback on earlier versions
                    Image(systemName: enableReminder ? "bell.badge.fill" : "bell.slash")
                      .font(.system(size: 48))
                      .foregroundStyle(.appAccent)
                      .contentTransition(.symbolEffect(.replace))
                  }
                }
                .padding(.bottom, 32)

                // Title
                Text("Daily Reminder")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)

                // Description
                Text("Get a gentle nudge every day to capture your moment in Joodle.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)

                // Toggle and Time Picker
                VStack(spacing: 16) {
                    Toggle(isOn: Binding(
                        get: { enableReminder },
                        set: { newValue in
                            handleToggleChange(newValue)
                        }
                    )) {
                        HStack {
                            Text("Enable Daily Reminder")
                                .font(.body)

                            if isRequestingPermission {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .appAccent))
                    .disabled(isRequestingPermission)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.appBorder.opacity(0.4))
                    )
                    .padding(.horizontal, 24)

                    // Time picker row (always visible, disabled when reminder is off)
                    HStack {
                        Text("Reminder Time")
                            .font(.body)
                            .foregroundStyle(enableReminder ? .primary : .secondary)

                        Spacer()

                        DatePicker(
                            "",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .disabled(!enableReminder)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.appBorder.opacity(enableReminder ? 0.4 : 0.2))
                    )
                    .opacity(enableReminder ? 1.0 : 0.5)
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Bottom CTA button
                OnboardingButtonView(label: "Continue") {
                    saveReminderSettings()
                    viewModel.completeStep(.dailyReminder)
                }
                .disabled(isRequestingPermission)
            }

            // Back button in top left corner
            Button {
                viewModel.goBack()
            } label: {
                Image(systemName: "arrow.left")
            }
            .circularGlassButton(tintColor: .primary)
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .alert("Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Skip", role: .cancel) {
                enableReminder = false
            }
        } message: {
            Text("Please enable notifications in Settings to receive daily reminders.")
        }
        .onAppear {
            // Trigger wiggle animation on appear if reminder is enabled
            if enableReminder {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    wiggleTrigger.toggle()
                }
            }
        }
    }

    private func handleToggleChange(_ newValue: Bool) {
        if newValue {
            // Enabling - check permission
            isRequestingPermission = true
            Task {
                let success = await reminderManager.enableDailyReminder(at: reminderTime)
                await MainActor.run {
                    isRequestingPermission = false
                    if success {
                        enableReminder = true
                        // Trigger wiggle animation when enabled
                        wiggleTrigger.toggle()
                    } else {
                        // Permission denied - show alert
                        showNotificationDeniedAlert = true
                    }
                }
            }
        } else {
            // Disabling
            enableReminder = false
        }
    }

    private func saveReminderSettings() {
        UserPreferences.shared.isDailyReminderEnabled = enableReminder
        UserPreferences.shared.dailyReminderTime = reminderTime

        if enableReminder {
            // Schedule the daily reminder
            reminderManager.updateDailyReminderTime(reminderTime)
        } else {
            // Cancel any existing reminder
            reminderManager.disableDailyReminder()
        }
    }
}

#Preview {
    NavigationStack {
        DailyReminderConfigView(viewModel: OnboardingViewModel())
    }
}
