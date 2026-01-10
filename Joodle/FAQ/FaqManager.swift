//
//  FaqManager.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import Foundation

/// Manages FAQ state and data fetching
@MainActor
final class FaqManager: ObservableObject {
    static let shared = FaqManager()

    // MARK: - Published Properties

    /// All FAQ sections to display
    @Published private(set) var sections: [FaqSection] = []

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error message if fetch failed
    @Published private(set) var errorMessage: String?

    // MARK: - Private Properties

    private let remoteService = RemoteFaqService.shared
    private var hasFetchedOnce = false

    private init() {}

    // MARK: - Public Methods

    /// Load FAQs from remote, falling back to cached data
    func loadFaqs(forceRefresh: Bool = false) async {
        // Skip if already loading
        guard !isLoading else { return }

        // Skip if already fetched and not forcing refresh
        if hasFetchedOnce && !forceRefresh {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let remoteSections = try await remoteService.fetchFaqs(forceRefresh: forceRefresh)

            // Convert to app models
            sections = remoteSections.map { $0.toFaqSection() }
            hasFetchedOnce = true

            print("📖 [FaqManager] Loaded \(sections.count) sections from remote")

        } catch {
            print("📖 [FaqManager] Failed to fetch remote FAQs: \(error.localizedDescription)")

            // Try to get cached data
            if let cached = await remoteService.getCachedFaqs() {
                sections = cached.map { $0.toFaqSection() }
                print("📖 [FaqManager] Using cached FAQs (\(sections.count) sections)")
            } else {
                // No cached data available
                sections = []
                errorMessage = "Unable to load FAQs. Please check your connection and try again."
                print("📖 [FaqManager] No FAQs available (no cache)")
            }

            hasFetchedOnce = true
        }

        isLoading = false
    }

    /// Force refresh FAQs from remote
    func refresh() async {
        await loadFaqs(forceRefresh: true)
    }

    /// Clear all caches
    func clearCaches() async {
        await remoteService.clearCaches()
        hasFetchedOnce = false
    }
}
