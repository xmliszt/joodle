//
//  ChangelogData.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Foundation

enum ChangelogData {
    /// All changelog entries auto-discovered from Changelogs folder
    /// Files must be named: {major}.{minor}.{build}_{year}-{month}-{day}.md
    /// Example: 1.0.55_2025-12-28.md
    static let entries: [ChangelogEntry] = discoverChangelogs()

    // MARK: - Optional Header Images
    // Add header image URLs for specific versions here
    // Key: version string (e.g., "1.0.55"), Value: remote image URL
    private static let headerImages: [String: URL] = [
        "1.0.58": URL(string: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Changelogs/1.0.58.png")!,
        "1.0.54": URL(string: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Changelogs/1.0.54.png")!,
    ]

    /// Get the header image URL for a specific version
    static func headerImage(for version: String) -> URL? {
        headerImages[version]
    }

    /// Get changelog for a specific version (e.g., "1.0.55")
    static func entry(for version: String) -> ChangelogEntry? {
        entries.first { $0.version == version }
    }

    /// Get the latest changelog
    static var latest: ChangelogEntry? {
        entries.first
    }

    // MARK: - Private Helpers

    /// Discovers and parses all changelog files from the Changelogs folder
    private static func discoverChangelogs() -> [ChangelogEntry] {
        var entries: [ChangelogEntry] = []

        // Get all .md files from bundle
        guard let resourcePath = Bundle.main.resourcePath else {
            print("Warning: Could not access bundle resource path")
            return []
        }

        let changelogsPath = (resourcePath as NSString).appendingPathComponent("Changelogs")
        let fileManager = FileManager.default

        // Check if Changelogs directory exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: changelogsPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            // Fallback: try to find files in root bundle
            return discoverFromRootBundle()
        }

        do {
            let files = try fileManager.contentsOfDirectory(atPath: changelogsPath)
            for filename in files where filename.hasSuffix(".md") {
                if let entry = parseChangelogFile(filename: filename, directory: changelogsPath) {
                    entries.append(entry)
                }
            }
        } catch {
            print("Warning: Could not read Changelogs directory: \(error)")
        }

        // Sort by version (newest first)
        return entries.sorted { compareVersions($0.version, $1.version) > 0 }
    }

    /// Fallback: discover changelog files from root bundle
    private static func discoverFromRootBundle() -> [ChangelogEntry] {
        var entries: [ChangelogEntry] = []

        guard let urls = Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: nil) else {
            return []
        }

        for url in urls {
            let filename = url.lastPathComponent
            // Check if filename matches our pattern
            if filename.contains("_") && filename.first?.isNumber == true {
                if let entry = parseChangelogFile(filename: filename, url: url) {
                    entries.append(entry)
                }
            }
        }

        return entries.sorted { compareVersions($0.version, $1.version) > 0 }
    }

    /// Parses a changelog file from directory path
    /// Filename format: {major}.{minor}.{build}_{year}-{month}-{day}.md
    private static func parseChangelogFile(filename: String, directory: String) -> ChangelogEntry? {
        let url = URL(fileURLWithPath: directory).appendingPathComponent(filename)
        return parseChangelogFile(filename: filename, url: url)
    }

    /// Parses a changelog file from URL
    private static func parseChangelogFile(filename: String, url: URL) -> ChangelogEntry? {
        // Remove .md extension
        let baseName = filename.replacingOccurrences(of: ".md", with: "")

        // Split by underscore: version_date
        let parts = baseName.split(separator: "_")
        guard parts.count == 2 else {
            print("Warning: Invalid changelog filename format: \(filename)")
            return nil
        }

        let versionString = String(parts[0])  // e.g., "1.0.55"
        let dateString = String(parts[1])     // e.g., "2025-12-28"

        // Parse version components
        let versionParts = versionString.split(separator: ".")
        guard versionParts.count == 3,
              let major = Int(versionParts[0]),
              let minor = Int(versionParts[1]),
              let build = Int(versionParts[2]) else {
            print("Warning: Invalid version format in: \(filename)")
            return nil
        }

        // Parse date components
        let dateParts = dateString.split(separator: "-")
        guard dateParts.count == 3,
              let year = Int(dateParts[0]),
              let month = Int(dateParts[1]),
              let day = Int(dateParts[2]) else {
            print("Warning: Invalid date format in: \(filename)")
            return nil
        }

        // Create date
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = Calendar.current.date(from: components) else {
            print("Warning: Could not create date from: \(filename)")
            return nil
        }

        // Load markdown content
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("Warning: Could not load content from: \(filename)")
            return nil
        }

        return ChangelogEntry(
            version: versionString,
            major: major,
            minor: minor,
            build: build,
            date: date,
            headerImageURL: headerImage(for: versionString),
            markdownContent: content
        )
    }

    /// Compare two version strings (returns -1, 0, or 1)
    private static func compareVersions(_ v1: String, _ v2: String) -> Int {
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
}
