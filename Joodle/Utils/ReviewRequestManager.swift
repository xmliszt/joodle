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
/// The prompt fires once, right after the 7-day Pro trial ends — the moment
/// perceived value peaks (the user just lived with full Pro for a week),
/// rather than at an arbitrary entry-count milestone weeks later.
@MainActor
final class ReviewRequestManager {

  static let shared = ReviewRequestManager()

  private let defaults = UserDefaults.standard

  // MARK: - Keys

  /// Legacy one-shot flag from the entry-count era — respected so users who
  /// were already prompted never get asked twice.
  private static let legacyRequestedReviewKey = "has_requested_review_for_10_entries"

  /// Whether the review prompt has been requested for the trial-end milestone
  private static let hasRequestedTrialEndReviewKey = "has_requested_review_trial_end"

  // MARK: - Init

  private init() {}

  // MARK: - Public

  /// Requests the review once, after the user's 7-day trial has ended.
  /// Call after the trial-ended sheet is dismissed so the two never stack.
  func requestReviewAfterTrialEnded() {
    guard !hasRequestedReview else { return }

    markReviewRequested()
    requestReview()
  }

  // MARK: - Private

  private var hasRequestedReview: Bool {
    defaults.bool(forKey: Self.hasRequestedTrialEndReviewKey)
      || defaults.bool(forKey: Self.legacyRequestedReviewKey)
  }

  private func markReviewRequested() {
    defaults.set(true, forKey: Self.hasRequestedTrialEndReviewKey)
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
