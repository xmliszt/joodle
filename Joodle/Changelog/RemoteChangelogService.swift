//
//  RemoteChangelogService.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Foundation

// MARK: - API Response Models

/// Response from the changelog index endpoint
struct ChangelogIndexResponse: Codable {
    let changelogs: [ChangelogIndexEntry]
}

/// Lightweight changelog entry for the index (without full markdown content)
struct ChangelogIndexEntry: Codable, Identifiable {
    let version: String
    let date: String
    let headerImageURL: String?

    var id: String { version }

    /// Parse the date string into a Date object
    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    /// Parse version components
    var versionComponents: (major: Int, minor: Int, build: Int)? {
        let parts = version.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }
}

/// Response from the individual changelog endpoint
struct ChangelogDetailResponse: Codable {
    let version: String
    let date: String
    let headerImageURL: String?
    let markdown: String
}

// MARK: - Service Errors

enum ChangelogServiceError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case notFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .notFound:
            return "Changelog not found"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

// MARK: - Remote Changelog Service

/// Service for fetching changelogs from the remote API
actor RemoteChangelogService {
    static let shared = RemoteChangelogService()

    // MARK: - Configuration

    /// Base URL for the changelog API
    /// Update this to your Vercel API endpoint
    private let baseURL = "https://liyuxuan.dev/api/changelogs/joodle"

    // MARK: - Caching

    private var indexCache: [ChangelogIndexEntry]?
    private var indexCacheTimestamp: Date?
    private var markdownCache: [String: String] = [:] // version -> markdown

    /// Cache duration in seconds (5 minutes)
    private let cacheDuration: TimeInterval = 300

    private init() {}

    // MARK: - Public API

    /// Fetch the changelog index (list of all changelogs without full content)
    func fetchChangelogIndex(forceRefresh: Bool = false) async throws -> [ChangelogIndexEntry] {
        // Return cached data if valid and not forcing refresh
        if !forceRefresh,
           let cached = indexCache,
           let timestamp = indexCacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheDuration {
            return cached
        }

        guard let url = URL(string: baseURL) else {
            throw ChangelogServiceError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChangelogServiceError.networkError(URLError(.badServerResponse))
            }

            guard httpResponse.statusCode == 200 else {
                throw ChangelogServiceError.serverError(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let indexResponse = try decoder.decode(ChangelogIndexResponse.self, from: data)

            // Sort by version (newest first)
            let sorted = indexResponse.changelogs.sorted { entry1, entry2 in
                compareVersions(entry1.version, entry2.version) > 0
            }

            // Update cache
            indexCache = sorted
            indexCacheTimestamp = Date()

            // Persist to disk for offline access
            await persistIndexToDisk(sorted)

            return sorted
        } catch let error as ChangelogServiceError {
            throw error
        } catch let error as DecodingError {
            throw ChangelogServiceError.decodingError(error)
        } catch {
            throw ChangelogServiceError.networkError(error)
        }
    }

    /// Fetch the full markdown content for a specific version
    func fetchChangelogDetail(version: String, forceRefresh: Bool = false) async throws -> String {
        // Return cached markdown if available and not forcing refresh
        if !forceRefresh, let cached = markdownCache[version] {
            return cached
        }

        // Try to load from disk cache first
        if !forceRefresh, let diskCached = await loadMarkdownFromDisk(version: version) {
            markdownCache[version] = diskCached
            return diskCached
        }

        guard let url = URL(string: "\(baseURL)/\(version)") else {
            throw ChangelogServiceError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChangelogServiceError.networkError(URLError(.badServerResponse))
            }

            if httpResponse.statusCode == 404 {
                throw ChangelogServiceError.notFound
            }

            guard httpResponse.statusCode == 200 else {
                throw ChangelogServiceError.serverError(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let detailResponse = try decoder.decode(ChangelogDetailResponse.self, from: data)

            // Update cache
            markdownCache[version] = detailResponse.markdown

            // Persist to disk
            await persistMarkdownToDisk(version: version, markdown: detailResponse.markdown)

            return detailResponse.markdown
        } catch let error as ChangelogServiceError {
            throw error
        } catch let error as DecodingError {
            throw ChangelogServiceError.decodingError(error)
        } catch {
            throw ChangelogServiceError.networkError(error)
        }
    }

    /// Convert a remote index entry to a full ChangelogEntry
    func convertToChangelogEntry(_ indexEntry: ChangelogIndexEntry, markdown: String) -> ChangelogEntry? {
        guard let components = indexEntry.versionComponents,
              let date = indexEntry.parsedDate else {
            return nil
        }

        return ChangelogEntry(
            version: indexEntry.version,
            major: components.major,
            minor: components.minor,
            build: components.build,
            date: date,
            headerImageURL: indexEntry.headerImageURL.flatMap { URL(string: $0) },
            markdownContent: markdown
        )
    }

    /// Clear all caches (useful for debugging or force refresh)
    func clearCaches() {
        indexCache = nil
        indexCacheTimestamp = nil
        markdownCache.removeAll()
    }

    /// Get cached index if available (for offline access)
    func getCachedIndex() async -> [ChangelogIndexEntry]? {
        if let cached = indexCache {
            return cached
        }
        return await loadIndexFromDisk()
    }

    // MARK: - Disk Persistence

    private var cacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Changelogs", isDirectory: true)
    }

    private func ensureCacheDirectoryExists() {
        guard let cacheDir = cacheDirectory else { return }
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    private func persistIndexToDisk(_ entries: [ChangelogIndexEntry]) async {
        ensureCacheDirectoryExists()
        guard let cacheDir = cacheDirectory else { return }

        let fileURL = cacheDir.appendingPathComponent("index.json")

        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL)
        } catch {
            print("⚠️ Failed to persist changelog index: \(error)")
        }
    }

    private func loadIndexFromDisk() async -> [ChangelogIndexEntry]? {
        guard let cacheDir = cacheDirectory else { return nil }

        let fileURL = cacheDir.appendingPathComponent("index.json")

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ChangelogIndexEntry].self, from: data)
        } catch {
            return nil
        }
    }

    private func persistMarkdownToDisk(version: String, markdown: String) async {
        ensureCacheDirectoryExists()
        guard let cacheDir = cacheDirectory else { return }

        let fileURL = cacheDir.appendingPathComponent("\(version).md")

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("⚠️ Failed to persist changelog markdown: \(error)")
        }
    }

    private func loadMarkdownFromDisk(version: String) async -> String? {
        guard let cacheDir = cacheDirectory else { return nil }

        let fileURL = cacheDir.appendingPathComponent("\(version).md")

        return try? String(contentsOf: fileURL, encoding: .utf8)
    }

    // MARK: - Version Comparison

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
}
