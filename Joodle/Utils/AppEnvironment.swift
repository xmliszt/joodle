//
//  AppEnvironment.swift
//  Joodle
//
//  Utility for detecting app environment (Debug, TestFlight, Production)
//

import Foundation

/// Utility for detecting the current app environment
enum AppEnvironment {
    case debug
    case testFlight
    case appStore

    /// The current app environment
    static var current: AppEnvironment {
        #if DEBUG
        return .debug
        #else
        if isTestFlight {
            return .testFlight
        } else {
            return .appStore
        }
        #endif
    }

    /// Whether the app is running in TestFlight
    static var isTestFlight: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }

    /// Whether the app is running in production (App Store)
    static var isAppStore: Bool {
        #if DEBUG
        return false
        #else
        return !isTestFlight
        #endif
    }

    /// Whether the app is running in debug mode
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Human-readable description of the current environment
    static var displayName: String {
        switch current {
        case .debug:
            return "Debug"
        case .testFlight:
            return "TestFlight"
        case .appStore:
            return "App Store"
        }
    }

    /// App version string (e.g., "1.0.0")
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// Build number string (e.g., "42")
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /// Full version string (e.g., "1.0.0 (42)")
    static var fullVersionString: String {
        "\(appVersion) (\(buildNumber))"
    }

    /// Bundle identifier
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }

    // MARK: - Feedback URLs

    /// The App Store ID for the app (update this with your actual App Store ID)
    private static let appStoreID = "6744076379"

    /// URL to open TestFlight for submitting feedback
    static var testFlightFeedbackURL: URL? {
        // This URL scheme opens TestFlight app directly
        // The beta-app path opens the current app's TestFlight page
        URL(string: "itms-beta://")
    }

    /// URL to open App Store for writing a review
    static var appStoreReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    /// The appropriate feedback URL based on current environment
    static var feedbackURL: URL? {
        switch current {
        case .debug, .testFlight:
            return testFlightFeedbackURL
        case .appStore:
            return appStoreReviewURL
        }
    }

    /// The label text for the feedback button
    static var feedbackButtonTitle: String {
        switch current {
        case .debug, .testFlight:
            return "Submit Testing Feedback"
        case .appStore:
            return "Write a Review"
        }
    }

    /// The icon name for the feedback button
    static var feedbackButtonIcon: String {
        switch current {
        case .debug, .testFlight:
            return "bubble.left.and.exclamationmark.bubble.right"
        case .appStore:
            return "star"
        }
    }
}
