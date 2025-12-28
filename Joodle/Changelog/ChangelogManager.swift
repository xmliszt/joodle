//
//  ChangelogManager.swift
//  Joodle
//
//  Created by Claude on 2025-01-15.
//

import Foundation

final class ChangelogManager {
    static let shared = ChangelogManager()

    private let defaults = UserDefaults.standard
    private let lastSeenVersionKey = "changelog_last_seen_version"

    private init() {}

    /// Last version whose changelog was displayed
    var lastSeenVersion: String? {
        get { defaults.string(forKey: lastSeenVersionKey) }
        set { defaults.set(newValue, forKey: lastSeenVersionKey) }
    }

    /// Check if we should show changelog for current version
    var shouldShowChangelog: Bool {
      print("\(AppEnvironment.fullVersionString) | \(ChangelogData.entry(for: AppEnvironment.fullVersionString)?.version ?? "n/a")")
        // Don't show during first launch (onboarding handles that)
        guard defaults.bool(forKey: "hasCompletedOnboarding") else {
            return false
        }

        // Check if there's a changelog for current version
        guard ChangelogData.entry(for: AppEnvironment.fullVersionString) != nil else {
            return false
        }

        // Show if never seen OR if last seen version differs from current
        guard let lastSeen = lastSeenVersion else {
          return true
        }

        return !hasSeenChangelog(for: AppEnvironment.fullVersionString)
    }

    /// Get the changelog entry to display (if any)
    var changelogToShow: ChangelogEntry? {
        guard shouldShowChangelog else { return nil }
        return ChangelogData.entry(for: AppEnvironment.fullVersionString)
    }

    /// Mark current version's changelog as seen
    func markCurrentVersionAsSeen() {
        lastSeenVersion = AppEnvironment.fullVersionString
    }

    /// Check if a specific version's changelog has been seen
    func hasSeenChangelog(for version: String) -> Bool {
        // Consider it seen if it's older than or equal to last seen version
        guard let lastSeen = lastSeenVersion else { return false }
        return compareVersions(version, lastSeen) <= 0
    }

    /// Compare two version strings (returns -1, 0, or 1)
    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        let v1Parts = v1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = v2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(v1Parts.count, v2Parts.count) {
            let p1 = i < v1Parts.count ? v1Parts[i] : 0
            let p2 = i < v2Parts.count ? v2Parts[i] : 0
            if p1 < p2 { return -1 }
            if p1 > p2 { return 1 }
        }
        return 0
    }

    // MARK: - Debug Helpers

    #if DEBUG
    /// Reset changelog state for testing
    func resetChangelogState() {
        lastSeenVersion = nil
    }

    /// Force a specific version as last seen for testing
    func setLastSeenVersion(_ version: String?) {
        lastSeenVersion = version
    }
    #endif
}
