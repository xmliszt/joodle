//
//  RemoteFaqService.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Foundation

// MARK: - API Response Models

/// Response from the FAQ API endpoint
struct FaqResponse: Codable {
    let sections: [FaqSectionResponse]
}

/// FAQ section from the API
struct FaqSectionResponse: Codable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let items: [FaqItemResponse]
}

/// FAQ item from the API
struct FaqItemResponse: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let order: Int
}

// MARK: - Service Errors

enum FaqServiceError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .noData:
            return "No FAQ data available"
        }
    }
}

// MARK: - Remote FAQ Service

/// Service for fetching FAQs from the remote API
actor RemoteFaqService {
    static let shared = RemoteFaqService()

    // MARK: - Configuration

    /// Base URL for the FAQ API
  private var baseURL: String {
      return "https://liyuxuan.dev/api/faqs/joodle"
  }

    // MARK: - Caching

    private var sectionsCache: [FaqSectionResponse]?
    private var cacheTimestamp: Date?

    /// Cache duration in seconds (10 minutes for FAQs)
    private let cacheDuration: TimeInterval = 600

    private init() {}

    // MARK: - Public API

    /// Fetch all FAQ sections with their items
    func fetchFaqs(forceRefresh: Bool = false) async throws -> [FaqSectionResponse] {
        // Clear all caches first if forcing refresh
        if forceRefresh {
            clearCaches()
            print("📖 [FAQ] Force refresh: cleared all caches")
        }

        // Return cached data if valid and not forcing refresh
        if !forceRefresh,
           let cached = sectionsCache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheDuration {
            print("📖 [FAQ] Returning cached FAQs (\(cached.count) sections)")
            return cached
        }

        // Try to load from disk cache first if not forcing refresh
        if !forceRefresh, let diskCached = await loadFromDisk() {
            sectionsCache = diskCached
            cacheTimestamp = Date()
            print("📖 [FAQ] Loaded FAQs from disk cache (\(diskCached.count) sections)")
            return diskCached
        }

        guard let url = URL(string: baseURL) else {
            throw FaqServiceError.invalidURL
        }

        print("📖 [FAQ] Fetching FAQs from remote: \(baseURL)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FaqServiceError.networkError(URLError(.badServerResponse))
            }

            print("📖 [FAQ] Response status code: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                throw FaqServiceError.serverError(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let faqResponse = try decoder.decode(FaqResponse.self, from: data)

            // Sort sections and items by order
            let sorted = faqResponse.sections
                .sorted { $0.order < $1.order }
                .map { section in
                    FaqSectionResponse(
                        id: section.id,
                        title: section.title,
                        order: section.order,
                        items: section.items.sorted { $0.order < $1.order }
                    )
                }

            // Update cache
            sectionsCache = sorted
            cacheTimestamp = Date()

            // Persist to disk for offline access
            await persistToDisk(sorted)

            print("📖 [FAQ] Successfully fetched \(sorted.count) sections from remote")
            return sorted
        } catch let error as FaqServiceError {
            throw error
        } catch let error as DecodingError {
            print("📖 [FAQ] Decoding error: \(error)")
            throw FaqServiceError.decodingError(error)
        } catch {
            print("📖 [FAQ] Network error: \(error)")
            throw FaqServiceError.networkError(error)
        }
    }

    /// Get cached FAQs if available (for offline access)
    func getCachedFaqs() async -> [FaqSectionResponse]? {
        if let cached = sectionsCache {
            return cached
        }
        return await loadFromDisk()
    }

    /// Clear all caches
    func clearCaches() {
        sectionsCache = nil
        cacheTimestamp = nil
        clearDiskCache()
        print("📖 [FAQ] Caches cleared")
    }

    // MARK: - Disk Persistence

    private var cacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FAQs", isDirectory: true)
    }

    private var cacheFileURL: URL? {
        cacheDirectory?.appendingPathComponent("faqs.json")
    }

    private func ensureCacheDirectoryExists() {
        guard let cacheDir = cacheDirectory else { return }
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    private func persistToDisk(_ sections: [FaqSectionResponse]) async {
        ensureCacheDirectoryExists()
        guard let fileURL = cacheFileURL else { return }

        do {
            let data = try JSONEncoder().encode(sections)
            try data.write(to: fileURL)
            print("📖 [FAQ] Persisted FAQs to disk")
        } catch {
            print("⚠️ [FAQ] Failed to persist FAQs: \(error)")
        }
    }

    private func loadFromDisk() async -> [FaqSectionResponse]? {
        guard let fileURL = cacheFileURL else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            let sections = try JSONDecoder().decode([FaqSectionResponse].self, from: data)
            return sections
        } catch {
            return nil
        }
    }

    private func clearDiskCache() {
        guard let cacheDir = cacheDirectory else { return }

        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: cacheDir.path) {
                try fileManager.removeItem(at: cacheDir)
            }
        } catch {
            print("⚠️ [FAQ] Failed to clear disk cache: \(error)")
        }
    }
}

// MARK: - Conversion Extensions

extension FaqSectionResponse {
    /// Convert to the app's FaqSection model
    func toFaqSection() -> FaqSection {
        FaqSection(
            id: id,
            title: title,
            items: items.map { $0.toFaqItem() }
        )
    }
}

extension FaqItemResponse {
    /// Convert to the app's FaqItem model
    func toFaqItem() -> FaqItem {
        FaqItem(
            id: id,
            title: title,
            content: content
        )
    }
}
