//
//  FeatureTipManager.swift
//  Joodle
//
//  Drives non-blocking feature-discovery tooltips. Holds the persisted "seen"
//  set, the live frames of on-screen anchors, and the single currently-active
//  tip. Follows the `ChangelogManager.shared` singleton convention.
//
//  Eligibility model (no version comparison needed):
//    • A tip shows when its anchor is on screen AND it hasn't been seen.
//    • Tapping the target marks it seen forever (`markSeen`).
//    • New installs are suppressed: `markAllCurrentTipsAsSeen()` is called once
//      on first onboarding completion, so fresh users — who already learned the
//      features via the onboarding tutorial — don't get tooltips. Existing,
//      already-onboarded users have an empty seen set, so newly-added tips
//      surface for them on update.
//

import SwiftUI

@MainActor
final class FeatureTipManager: ObservableObject {
    static let shared = FeatureTipManager()

    // MARK: - Published State

    /// The tip currently eligible to display, or `nil` when none.
    @Published private(set) var activeTip: FeatureTip?

    /// Global-space frame of the active tip's anchor, used to position the
    /// bubble. Kept in sync with `activeTip`.
    @Published private(set) var activeFrame: CGRect?

    // MARK: - Private State

    private let defaults = UserDefaults.standard
    private let seenIDsKey = "featureTip_seenIDs"

    /// anchorID → latest global frame, only for anchors currently on screen.
    private var frames: [String: CGRect] = [:]

    private var seenIDs: Set<String>

    private init() {
        let stored = defaults.stringArray(forKey: seenIDsKey) ?? []
        seenIDs = Set(stored)
    }

    // MARK: - Anchor Registration

    /// Called by `.featureTip(_:)` when the target appears or moves.
    func registerFrame(anchorID: String, frame: CGRect) {
        guard frames[anchorID] != frame else { return }
        frames[anchorID] = frame
        recompute()
    }

    /// Called by `.featureTip(_:)` when the target leaves the screen.
    func unregisterFrame(anchorID: String) {
        guard frames[anchorID] != nil else { return }
        frames.removeValue(forKey: anchorID)
        recompute()
    }

    // MARK: - Dismissal

    /// Permanently dismiss the tip with the given id (tapped its target).
    func markSeen(_ id: String) {
        guard !seenIDs.contains(id) else { return }
        seenIDs.insert(id)
        persistSeenIDs()
        recompute()
    }

    /// Suppress every currently-defined tip. Call once on the user's first
    /// onboarding completion so new installs don't see tooltips for features
    /// the onboarding tutorial already covered.
    func markAllCurrentTipsAsSeen() {
        let allIDs = FeatureTipDefinitions.all.map(\.id)
        seenIDs.formUnion(allIDs)
        persistSeenIDs()
        recompute()
    }

    // MARK: - Selection

    /// Pick the highest-priority unseen tip whose anchor is on screen.
    private func recompute() {
        let candidate = FeatureTipDefinitions.all
            .filter { !seenIDs.contains($0.id) && frames[$0.anchorID] != nil }
            .max { $0.priority < $1.priority }

        let newFrame = candidate.flatMap { frames[$0.anchorID] }

        guard activeTip?.id != candidate?.id || activeFrame != newFrame else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            activeTip = candidate
            activeFrame = newFrame
        }
    }

    private func persistSeenIDs() {
        defaults.set(Array(seenIDs), forKey: seenIDsKey)
    }

    // MARK: - Debug / Testing

    /// Clear all seen state so tips reappear (for manual testing).
    func resetSeenState() {
        seenIDs.removeAll()
        persistSeenIDs()
        recompute()
    }
}
