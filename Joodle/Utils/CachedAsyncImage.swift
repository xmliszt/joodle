//
//  CachedAsyncImage.swift
//  Joodle
//

import SwiftUI

// MARK: - Image Cache

/// A thread-safe image cache using NSCache for memory caching
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private let lock = NSLock()

    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Maximum number of images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func removeImage(for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeObject(forKey: url as NSURL)
    }

    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
    }
}

// MARK: - Async Image Phase

/// Represents the current phase of image loading, matching AsyncImage's API
public enum CachedAsyncImagePhase: Sendable {
    case empty
    case success(Image)
    case failure(Error)

    /// The loaded image, if available
    public var image: Image? {
        if case .success(let image) = self {
            return image
        }
        return nil
    }

    /// The error, if loading failed
    public var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Cached Async Image

/// An AsyncImage replacement with built-in memory and disk caching
///
/// Uses a two-tier caching strategy:
/// 1. Memory cache (NSCache) for fast retrieval
/// 2. URLCache (disk) for persistence across app launches
///
/// Usage mirrors SwiftUI's AsyncImage:
/// ```
/// CachedAsyncImage(url: imageURL) { phase in
///     switch phase {
///     case .empty:
///         ProgressView()
///     case .success(let image):
///         image.resizable().scaledToFit()
///     case .failure:
///         Image(systemName: "photo")
///     }
/// }
/// ```
public struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (CachedAsyncImagePhase) -> Content

    @State private var phase: CachedAsyncImagePhase = .empty
    @State private var currentTask: Task<Void, Never>?

    /// Creates a cached async image with a custom content builder
    /// - Parameters:
    ///   - url: The URL of the image to load
    ///   - scale: The scale factor for the image (default: 1.0)
    ///   - transaction: The transaction for animations (default: empty)
    ///   - content: A closure that returns the view for each loading phase
    public init(
        url: URL?,
        scale: CGFloat = 1.0,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (CachedAsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }

    public var body: some View {
        content(phase)
            .onAppear {
                loadImage()
            }
            .onChange(of: url) { _, newURL in
                // Cancel any existing task and reload
                currentTask?.cancel()
                phase = .empty
                loadImage()
            }
            .onDisappear {
                currentTask?.cancel()
            }
    }

    private func loadImage() {
        guard let url = url else {
            phase = .empty
            return
        }

        // Check memory cache first (synchronous, fast)
        if let cachedImage = ImageCache.shared.image(for: url) {
            withTransaction(transaction) {
                phase = .success(Image(uiImage: cachedImage))
            }
            return
        }

        // Load asynchronously
        currentTask = Task {
            await loadImageAsync(from: url)
        }
    }

    @MainActor
    private func loadImageAsync(from url: URL) async {
        // Double-check memory cache (in case it was populated while waiting)
        if let cachedImage = ImageCache.shared.image(for: url) {
            withTransaction(transaction) {
                phase = .success(Image(uiImage: cachedImage))
            }
            return
        }

        let request = URLRequest(url: url)

        // Check disk cache (URLCache)
        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let uiImage = UIImage(data: cachedResponse.data, scale: scale) {
            // Store in memory cache for faster future access
            ImageCache.shared.setImage(uiImage, for: url)

            withTransaction(transaction) {
                phase = .success(Image(uiImage: uiImage))
            }
            return
        }

        // Fetch from network
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check if task was cancelled
            if Task.isCancelled { return }

            guard let uiImage = UIImage(data: data, scale: scale) else {
                throw URLError(.cannotDecodeContentData)
            }

            // Cache the response to disk
            let cachedData = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedData, for: request)

            // Cache to memory
            ImageCache.shared.setImage(uiImage, for: url)

            withTransaction(transaction) {
                phase = .success(Image(uiImage: uiImage))
            }
        } catch {
            if !Task.isCancelled {
                withTransaction(transaction) {
                    phase = .failure(error)
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage {
    /// Creates a cached async image with default placeholder and error views
    /// - Parameters:
    ///   - url: The URL of the image to load
    ///   - scale: The scale factor for the image (default: 1.0)
    public init(url: URL?, scale: CGFloat = 1.0) where Content == _ConditionalContent<_ConditionalContent<ProgressView<EmptyView, EmptyView>, Image>, Image> {
        self.init(url: url, scale: scale) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
            case .failure:
                Image(systemName: "photo")
            }
        }
    }
}

// MARK: - Cache Management

extension CachedAsyncImage {
    /// Clears all cached images from memory
    public static func clearMemoryCache() {
        ImageCache.shared.clearCache()
    }

    /// Clears all cached images from both memory and disk
    public static func clearAllCaches() {
        ImageCache.shared.clearCache()
        URLCache.shared.removeAllCachedResponses()
    }

    /// Removes a specific image from memory cache
    /// - Parameter url: The URL of the image to remove
    public static func removeFromCache(url: URL) {
        ImageCache.shared.removeImage(for: url)
        let request = URLRequest(url: url)
        URLCache.shared.removeCachedResponse(for: request)
    }

    /// Prefetches and caches images for the given URLs
    /// - Parameter urls: The URLs to prefetch
    public static func prefetch(urls: [URL]) {
        for url in urls {
            // Skip if already in memory cache
            if ImageCache.shared.image(for: url) != nil {
                continue
            }

            Task {
                let request = URLRequest(url: url)

                // Check disk cache first
                if let cachedResponse = URLCache.shared.cachedResponse(for: request),
                   let uiImage = UIImage(data: cachedResponse.data) {
                    ImageCache.shared.setImage(uiImage, for: url)
                    return
                }

                // Fetch from network
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)

                    guard let uiImage = UIImage(data: data) else { return }

                    // Cache to disk
                    let cachedData = CachedURLResponse(response: response, data: data)
                    URLCache.shared.storeCachedResponse(cachedData, for: request)

                    // Cache to memory
                    ImageCache.shared.setImage(uiImage, for: url)
                } catch {
                    // Silently fail for prefetch
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("CachedAsyncImage") {
    VStack(spacing: 20) {
        CachedAsyncImage(
            url: URL(string: "https://picsum.photos/200/300")
        ) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 200, height: 300)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 300)
            case .failure:
                Image(systemName: "photo.trianglebadge.exclamationmark.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 300)
                    .foregroundStyle(.secondary)
            }
        }

        Text("Cached Async Image Demo")
            .font(.appCaption())
    }
    .padding()
}
