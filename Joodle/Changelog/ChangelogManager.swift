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
        let currentVersion = AppEnvironment.rawVersionString
        let hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        let changelogEntry = ChangelogData.entry(for: currentVersion)
        let availableVersions = ChangelogData.entries.map { $0.version }

        print("📋 [Changelog Debug]")
        print("   Current app version: '\(currentVersion)'")
        print("   Available changelog versions: \(availableVersions)")
        print("   Changelog entry for current: \(changelogEntry?.version ?? "nil")")
        print("   Has completed onboarding: \(hasCompletedOnboarding)")
        print("   Last seen version: \(lastSeenVersion ?? "nil")")

        // Don't show during first launch (onboarding handles that)
        guard hasCompletedOnboarding else {
            print("   ❌ Skipping: Onboarding not completed")
            return false
        }

        // Check if there's a changelog for current version
        guard changelogEntry != nil else {
            print("   ❌ Skipping: No changelog found for version '\(currentVersion)'")
            return false
        }

        // Show if never seen OR if last seen version differs from current
        guard let lastSeen = lastSeenVersion else {
            print("   ✅ Showing: No last seen version (first time)")
            return true
        }

        let alreadySeen = hasSeenChangelog(for: currentVersion)
        print("   Already seen this version: \(alreadySeen)")

        if alreadySeen {
            print("   ❌ Skipping: Already seen this changelog")
        } else {
            print("   ✅ Showing: New version changelog")
        }

        return !alreadySeen
    }

    /// Get the changelog entry to display (if any)
    var changelogToShow: ChangelogEntry? {
        guard shouldShowChangelog else { return nil }
        return ChangelogData.entry(for: AppEnvironment.rawVersionString)
    }

    /// Mark current version's changelog as seen
    func markCurrentVersionAsSeen() {
        lastSeenVersion = AppEnvironment.rawVersionString
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
