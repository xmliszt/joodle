//
//  RemotePromptsService.swift
//  Joodle
//
//  Created by Li Yuxuan on 22/2/26.
//

import Foundation

// MARK: - Response Model

private struct RemotePromptsResponse: Codable {
  let prompts: [String]
}

// MARK: - Remote Prompts Service

/// Actor-based service that fetches additional inspiration prompts from the remote API.
/// Thread-safe and uses a simple in-memory cache to avoid redundant network calls
/// within the same app session.
actor RemotePromptsService {
  static let shared = RemotePromptsService()

  private let endpoint = URL(string: "https://liyuxuan.dev/api/prompts/joodle")!
  private var cachedPrompts: [String]?

  private init() {}

  /// Fetches additional prompts from the remote API.
  /// Returns the cached result if available; otherwise performs a network request.
  /// Throws on network or decoding failure — callers should handle errors silently.
  func fetchPrompts() async throws -> [String] {
    if let cached = cachedPrompts {
      print("🎨 [Prompts] Returning \(cached.count) prompts from in-memory cache")
      return cached
    }

    print("🎨 [Prompts] Fetching prompts from remote: \(endpoint.absoluteString)")
    let (data, response) = try await URLSession.shared.data(from: endpoint)

    if let httpResponse = response as? HTTPURLResponse {
      print("🎨 [Prompts] Response status code: \(httpResponse.statusCode)")
    }

    let decoded = try JSONDecoder().decode(RemotePromptsResponse.self, from: data)
    cachedPrompts = decoded.prompts
    print("🎨 [Prompts] Successfully fetched \(decoded.prompts.count) prompts from remote")
    return decoded.prompts
  }
}
