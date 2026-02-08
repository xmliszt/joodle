//
//  ReviewRequestManager.swift
//  Joodle
//
//  Manages App Store review prompt requests.
//  Triggers the native review dialog after meaningful milestones.
//

import Foundation
import StoreKit
import SwiftUI

/// Manages when to request an App Store review using Apple's native API.
///
/// Apple controls actual display (max 3 times/year), so we only gate *when* to ask.
/// The prompt triggers when the user creates their 10th Joodle entry.
@MainActor
final class ReviewRequestManager {

  static let shared = ReviewRequestManager()

  private let defaults = UserDefaults.standard

  // MARK: - Keys

  /// Whether the review prompt has already been requested for the 10-entry milestone
  private static let hasRequestedReviewKey = "has_requested_review_for_10_entries"

  // MARK: - Init

  private init() {}

  // MARK: - Public

  /// Checks whether the review prompt should be shown based on entry count,
  /// and requests it if conditions are met.
  ///
  /// - Parameter entryCount: The total number of entries with meaningful content (drawing or text).
  func checkAndRequestReviewIfNeeded(entryCount: Int) {
    guard entryCount >= 30 else { return }
    guard !hasRequestedReview else { return }

    markReviewRequested()
    requestReview()
  }

  // MARK: - Private

  private var hasRequestedReview: Bool {
    defaults.bool(forKey: Self.hasRequestedReviewKey)
  }

  private func markReviewRequested() {
    defaults.set(true, forKey: Self.hasRequestedReviewKey)
  }

  private func requestReview() {
    guard let scene = UIApplication.shared.connectedScenes
      .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
    else { return }

    // Small delay to avoid interfering with the save animation
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      SKStoreReviewController.requestReview(in: scene)
    }
  }
}
