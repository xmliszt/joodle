//
//  PromptsManager.swift
//  Joodle
//
//  Created by Li Yuxuan on 22/2/26.
//

import Foundation

// MARK: - Prompts Manager

/// Singleton that maintains the full pool of inspiration prompts.
/// Starts with the bundled `joodlePrompts` list and silently merges in
/// any additional prompts fetched from the remote API.
@MainActor
final class PromptsManager {
  static let shared = PromptsManager()

  /// The full prompt pool, seeded with the bundled list.
  /// Remote prompts are appended (deduplicated) after a successful fetch.
  private(set) var allPrompts: [String] = joodlePrompts

  private init() {}

  /// Fetches additional prompts from the remote API in the background.
  /// The underlying service caches results in-memory, so repeated calls
  /// within a session incur no network cost.
  /// On success, merges unique new prompts into `allPrompts`.
  /// All failures are swallowed silently — the bundled list is always available.
  func fetchRemotePrompts() async {
    do {
      let remotePrompts = try await RemotePromptsService.shared.fetchPrompts()
      let newPrompts = remotePrompts.filter { !allPrompts.contains($0) }
      if !newPrompts.isEmpty {
        allPrompts += newPrompts
        print("🎨 [Prompts] Added \(newPrompts.count) new remote prompts. Total pool: \(allPrompts.count)")
      } else {
        print("🎨 [Prompts] No new prompts to add. Total pool: \(allPrompts.count)")
      }
    } catch {
      print("🎨 [Prompts] Remote fetch failed (using bundled prompts): \(error.localizedDescription)")
    }
  }
}
