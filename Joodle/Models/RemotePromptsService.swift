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

  private let baseEndpoint = "https://liyuxuan.dev/api/prompts/joodle"
  private var cachedPromptsByLocale: [String: [String]] = [:]

  private init() {}

  /// Fetches additional prompts from the remote API.
  /// Returns the cached result if available; otherwise performs a network request.
  /// Throws on network or decoding failure — callers should handle errors silently.
  func fetchPrompts() async throws -> [String] {
    let locale = LocaleProvider.currentLanguageCode
    if let cached = cachedPromptsByLocale[locale] {
      print("🎨 [Prompts] Returning \(cached.count) prompts from in-memory cache")
      return cached
    }

    guard let endpoint = localizedEndpoint(locale: locale) else {
      throw URLError(.badURL)
    }

    print("🎨 [Prompts] Fetching prompts from remote: \(endpoint.absoluteString)")
    let (data, response) = try await URLSession.shared.data(from: endpoint)

    if let httpResponse = response as? HTTPURLResponse {
      print("🎨 [Prompts] Response status code: \(httpResponse.statusCode)")
    }

    let decoded = try JSONDecoder().decode(RemotePromptsResponse.self, from: data)
    cachedPromptsByLocale[locale] = decoded.prompts
    print("🎨 [Prompts] Successfully fetched \(decoded.prompts.count) prompts from remote")
    return decoded.prompts
  }

  private func localizedEndpoint(locale: String) -> URL? {
    guard var components = URLComponents(string: baseEndpoint) else {
      return nil
    }

    components.queryItems = [
      URLQueryItem(name: "locale", value: locale)
    ]
    return components.url
  }
}
