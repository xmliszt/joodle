//
//  RemoteAlertService.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Remote Alert Service

/// Service responsible for fetching remote alerts from the API
/// and managing the display state
@MainActor
final class RemoteAlertService: ObservableObject {
    static let shared = RemoteAlertService()

    // MARK: - Published State

    /// The current alert to display (nil if none)
    @Published private(set) var currentAlert: RemoteAlert?

    // MARK: - Configuration

    /// API endpoint for fetching alerts
    private var endpoint: URL {
      return URL(string: "https://liyuxuan.dev/api/alerts/joodle")!
    }

    /// UserDefaults key for storing the last dismissed alert ID
    private let lastDismissedKey = "lastDismissedRemoteAlertId"

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Check for new alerts from the remote server
    /// Call this on app launch after any splash/loading screen
    func checkForAlert() async {
        // Skip if user hasn't completed onboarding yet
        // This handles fresh installs and reinstalls going through onboarding
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        guard hasCompletedOnboarding else {
            print("📢 Remote alert: Skipping - user is in onboarding")
            return
        }

        do {
            print("📢 Remote alert: fetch from \(endpoint)")
            var request = URLRequest(url: endpoint)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("📢 Remote alert: Non-200 response")
                return
            }

            // Decode response
            let decoder = JSONDecoder()
            let alertResponse = try decoder.decode(RemoteAlertResponse.self, from: data)

            // Check if there's an alert
            guard let alert = alertResponse.alert else {
                print("📢 Remote alert: No active alert")
                currentAlert = nil
                return
            }

            // Check if user has already dismissed this alert
            let lastDismissedId = UserDefaults.standard.string(forKey: lastDismissedKey)
            if alert.id == lastDismissedId {
                print("📢 Remote alert: Alert '\(alert.id)' already dismissed")
                currentAlert = nil
                return
            }

            // Check if announcements are enabled
            guard isAnnouncementAllowed(type: alert.type) else {
                print("📢 Remote alert: Alert '\(alert.id)' blocked by user preferences")
                currentAlert = nil
                return
            }

            // Show the alert
            print("📢 Remote alert: Showing alert '\(alert.id)'")
            currentAlert = alert

        } catch {
            // Fail silently - remote alerts are non-critical
            print("📢 Remote alert fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Preference Checking

    /// Check if a specific announcement type is allowed based on user preferences
    private func isAnnouncementAllowed(type: RemoteAlert.AnnouncementType) -> Bool {
        let prefs = UserPreferences.shared

        // If master toggle is off, block all announcements
        guard prefs.announcementsEnabled else {
            return false
        }

        // Check individual type preferences
        switch type {
        case .promo:
            return prefs.announcementPromoEnabled
        case .community:
            return prefs.announcementCommunityEnabled
        case .tips:
            return prefs.announcementTipsEnabled
        }
    }

    /// Dismiss the current alert and remember it so it won't show again
    func dismissCurrentAlert() {
        guard let alert = currentAlert else { return }

        // Store the dismissed alert ID
        UserDefaults.standard.set(alert.id, forKey: lastDismissedKey)
        print("📢 Remote alert: Dismissed alert '\(alert.id)'")

        // Clear the current alert
        currentAlert = nil
    }

    /// Handle the primary button action
    /// - Returns: true if a URL was opened, false otherwise
    @discardableResult
    func handlePrimaryAction() -> Bool {
        guard let alert = currentAlert,
              let urlString = alert.primaryButton.url,
              let url = URL(string: urlString) else {
            dismissCurrentAlert()
            return false
        }

        // Open the URL
        UIApplication.shared.open(url)
        dismissCurrentAlert()
        return true
    }

    /// Handle the secondary button action (always just dismisses)
    func handleSecondaryAction() {
        dismissCurrentAlert()
    }

    // MARK: - Debug Helpers

    /// Reset the dismissed state (for testing)
    func resetDismissedState() {
        UserDefaults.standard.removeObject(forKey: lastDismissedKey)
        print("📢 Remote alert: Reset dismissed state")
    }

    /// Force show a test alert
    func showTestAlert(type: RemoteAlert.AnnouncementType = .community) {
        let alertId = "test-alert-\(Date().timeIntervalSince1970)"

        // Check if announcements are enabled
        guard isAnnouncementAllowed(type: type) else {
            print("📢 Remote alert: Alert '\(alertId)' blocked by user preferences")
            currentAlert = nil
            return
        }

        currentAlert = RemoteAlert(
            id: alertId,
            title: "Test Alert 🧪",
            message: "This is a test alert to preview the remote alert UI. It will behave just like a real remote alert.",
            primaryButton: RemoteAlert.AlertButton(
                text: "Open Example",
                url: "https://example.com"
            ),
            secondaryButton: RemoteAlert.AlertButton(
                text: "Dismiss",
                url: nil
            ),
            imageURL: nil,
            type: type
        )
    }
}
