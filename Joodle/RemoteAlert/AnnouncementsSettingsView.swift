//
//  AnnouncementsSettingsView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

// MARK: - Announcements Settings View

/// Settings view for managing announcement preferences
struct AnnouncementsSettingsView: View {
    @Environment(\.userPreferences) private var userPreferences

    var body: some View {
        List {
            // MARK: - Master Toggle Section
            Section {
                Toggle(isOn: Binding(
                    get: { userPreferences.announcementsEnabled },
                    set: { newValue in
                        let previousValue = userPreferences.announcementsEnabled
                        userPreferences.announcementsEnabled = newValue
                        if newValue != previousValue {
                            AnalyticsManager.shared.trackSettingChanged(
                                name: "announcements_enabled",
                                value: newValue,
                                previousValue: previousValue
                            )
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text("Enable Announcements")
                    }
                }
            } footer: {
                Text("When enabled, you may occasionally see announcements when opening the app. You can customize which types of announcements you'd like to receive below.")
            }

            // MARK: - Announcement Types Section
            Section {
                ForEach(RemoteAlert.AnnouncementType.allCases) { type in
                    announcementTypeRow(for: type)
                }
            } header: {
                Text("Announcement Types")
            } footer: {
                Text("Choose which types of announcements you'd like to receive.")
            }
            .disabled(!userPreferences.announcementsEnabled)
            .opacity(userPreferences.announcementsEnabled ? 1 : 0.5)
        }
        .navigationTitle("Announcements")
        .navigationBarTitleDisplayMode(.inline)
        .postHogScreenView("Announcements")
        .animation(.easeInOut(duration: 0.2), value: userPreferences.announcementsEnabled)
    }

    // MARK: - Announcement Type Row

    @ViewBuilder
    private func announcementTypeRow(for type: RemoteAlert.AnnouncementType) -> some View {
        Toggle(isOn: bindingForType(type)) {
            HStack(spacing: 12) {
                Image(systemName: type.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(type.iconColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.body)

                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Binding Helper

    private func bindingForType(_ type: RemoteAlert.AnnouncementType) -> Binding<Bool> {
        switch type {
        case .promo:
            return Binding(
                get: { userPreferences.announcementPromoEnabled },
                set: { newValue in
                    let previousValue = userPreferences.announcementPromoEnabled
                    userPreferences.announcementPromoEnabled = newValue
                    if newValue != previousValue {
                        AnalyticsManager.shared.trackSettingChanged(
                            name: "announcement_promo_enabled",
                            value: newValue,
                            previousValue: previousValue
                        )
                    }
                }
            )
        case .community:
            return Binding(
                get: { userPreferences.announcementCommunityEnabled },
                set: { newValue in
                    let previousValue = userPreferences.announcementCommunityEnabled
                    userPreferences.announcementCommunityEnabled = newValue
                    if newValue != previousValue {
                        AnalyticsManager.shared.trackSettingChanged(
                            name: "announcement_community_enabled",
                            value: newValue,
                            previousValue: previousValue
                        )
                    }
                }
            )
        case .tips:
            return Binding(
                get: { userPreferences.announcementTipsEnabled },
                set: { newValue in
                    let previousValue = userPreferences.announcementTipsEnabled
                    userPreferences.announcementTipsEnabled = newValue
                    if newValue != previousValue {
                        AnalyticsManager.shared.trackSettingChanged(
                            name: "announcement_tips_enabled",
                            value: newValue,
                            previousValue: previousValue
                        )
                    }
                }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AnnouncementsSettingsView()
    }
}
