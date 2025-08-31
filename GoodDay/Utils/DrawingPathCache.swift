//
//  DrawingPathCache.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import Foundation

/// Cache for decoded drawing paths to eliminate repeated JSON decoding
class DrawingPathCache: ObservableObject {
    private var cache: [Data: [Path]] = [:]
    private let maxCacheSize = 100 // Limit cache size to prevent memory issues
    private var accessOrder: [Data] = [] // Track access order for LRU eviction

    /// Get paths for the given drawing data, using cache if available
    func getPaths(for data: Data) -> [Path] {
        // Check if already cached
        if let cached = cache[data] {
            // Update access order for LRU
            updateAccessOrder(for: data)
            return cached
        }

        // Decode paths if not cached
        let paths = decodePaths(from: data)

        // Store in cache with LRU management
        storePaths(paths, for: data)

        return paths
    }

    /// Decode paths from raw drawing data
    private func decodePaths(from data: Data) -> [Path] {
        do {
            // Define PathData structure inline to avoid import issues
            struct PathData: Codable {
                let points: [CGPoint]
                let isDot: Bool

                init(points: [CGPoint], isDot: Bool = false) {
                    self.points = points
                    self.isDot = isDot
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    points = try container.decode([CGPoint].self, forKey: .points)
                    isDot = try container.decodeIfPresent(Bool.self, forKey: .isDot) ?? false
                }

                private enum CodingKeys: String, CodingKey {
                    case points
                    case isDot
                }
            }

            // Constants defined inline to avoid import issues
            let DRAWING_LINE_WIDTH: CGFloat = 5.0

            let decodedPaths = try JSONDecoder().decode([PathData].self, from: data)
            return decodedPaths.map { pathData in
                var path = Path()
                if pathData.isDot && pathData.points.count >= 1 {
                    // Recreate dot as ellipse
                    let center = pathData.points[0]
                    let dotRadius = DRAWING_LINE_WIDTH / 2
                    path.addEllipse(in: CGRect(
                        x: center.x - dotRadius,
                        y: center.y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    ))
                } else {
                    // Recreate line path
                    for (index, point) in pathData.points.enumerated() {
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                }
                return path
            }
        } catch {
            print("Failed to decode drawing data: \(error)")
            return []
        }
    }

    /// Store paths in cache with LRU eviction
    private func storePaths(_ paths: [Path], for data: Data) {
        // Add to cache
        cache[data] = paths

        // Update access order
        updateAccessOrder(for: data)

        // Evict oldest entries if cache is too large
        if cache.count > maxCacheSize {
            evictOldestEntries()
        }
    }

    /// Update access order for LRU tracking
    private func updateAccessOrder(for data: Data) {
        // Remove from current position if exists
        accessOrder.removeAll { $0 == data }
        // Add to end (most recently used)
        accessOrder.append(data)
    }

    /// Evict oldest cache entries to maintain size limit
    private func evictOldestEntries() {
        let excessCount = cache.count - maxCacheSize
        guard excessCount > 0 else { return }

        // Remove oldest entries
        for _ in 0..<excessCount {
            if let oldestData = accessOrder.first {
                cache.removeValue(forKey: oldestData)
                accessOrder.removeFirst()
            }
        }
    }

    /// Clear the entire cache (useful for memory pressure)
    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    /// Get current cache statistics for debugging
    var cacheStats: (count: Int, memoryEstimate: String) {
        let count = cache.count
        let bytesEstimate = cache.keys.reduce(0) { $0 + $1.count }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return (count: count, memoryEstimate: formatter.string(fromByteCount: Int64(bytesEstimate)))
    }
}

/// Singleton instance for global access
extension DrawingPathCache {
    static let shared = DrawingPathCache()
}
