//
//  FeatureTipManager.swift
//  Joodle
//
//  Drives non-blocking feature-discovery tooltips. Holds the persisted "seen"
//  set, the live frames of on-screen anchors, the active screen scopes, and the
//  single currently-active tip. Follows the `ChangelogManager.shared` singleton
//  convention.
//
//  Eligibility model (no version comparison needed):
//    • `.anchorVisible` tips show while their anchor is on screen AND unseen.
//    • `.scoped` tips show while their scope (a whole screen) is active AND
//      unseen — even before the target row renders. When the live anchor frame
//      is unavailable the bubble clamps to a screen edge (see `fallbackEdge`).
//    • Tapping a tip's target marks its whole feature seen (`markSeen` clears
//      every tip sharing the same `featureKey`).
//    • New installs are suppressed: `markAllCurrentTipsAsSeen()` is called once
//      on first onboarding completion, so fresh users — who already learned the
//      features via the onboarding tutorial — don't get tooltips. Existing,
//      already-onboarded users have these tips unseen, so newly-added tips
//      surface for them on update.
//

import SwiftUI

@MainActor
final class FeatureTipManager: ObservableObject {
    static let shared = FeatureTipManager()

    // MARK: - Published State

    /// The tip currently eligible to display, or `nil` when none.
    @Published private(set) var activeTip: FeatureTip?

    /// Global-space frame of the active tip's anchor when it is on screen, used
    /// to position the bubble. `nil` for a scoped tip whose target is currently
    /// off-screen — the overlay then clamps to `fallbackEdge`.
    @Published private(set) var activeFrame: CGRect?

    /// Edge a scoped tip clamps to when `activeFrame` is `nil`.
    @Published private(set) var fallbackEdge: FeatureTipEdge = .bottom

    // MARK: - Private State

    private let defaults = UserDefaults.standard
    private let seenIDsKey = "featureTip_seenIDs"

    /// anchorID → latest global frame, only for anchors currently on screen.
    private var frames: [String: CGRect] = [:]

    /// anchorID → last known global frame, retained after the anchor leaves the
    /// screen so we can tell which edge it scrolled off toward.
    private var lastFrames: [String: CGRect] = [:]

    /// Screen scopes currently active (see `.featureTipScope(_:)`).
    private var activeScopes: Set<String> = []

    /// Full-screen height reported by the overlay, used to derive the fallback
    /// edge from a last-known frame.
    private var viewportHeight: CGFloat = 0

    private var seenIDs: Set<String>

    /// Whether any defined tip is still unseen. When `false` the manager can
    /// never surface a tip, so the per-scroll-frame registration hot path
    /// short-circuits to a no-op — the common case for already-resolved users
    /// and brand-new installs (which are suppressed up front). Recomputed only
    /// when the seen set changes, never on the hot path.
    private var hasUnseenTips: Bool

    private init() {
        let stored = defaults.stringArray(forKey: seenIDsKey) ?? []
        let seen = Set(stored)
        seenIDs = seen
        hasUnseenTips = FeatureTipDefinitions.all.contains { !seen.contains($0.id) }
    }

    // MARK: - Anchor Registration

    /// Called by `.featureTip(_:)` when the target appears or moves.
    func registerFrame(anchorID: String, frame: CGRect) {
        // Hot path (fires every frame while scrolling): bail before touching any
        // state once there's nothing left that could ever show.
        guard hasUnseenTips else { return }
        lastFrames[anchorID] = frame
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

    // MARK: - Scope Registration

    /// Called by `.featureTipScope(_:)` when its host screen becomes visible.
    func activateScope(_ scopeID: String) {
        guard hasUnseenTips else { return }
        guard !activeScopes.contains(scopeID) else { return }
        activeScopes.insert(scopeID)
        recompute()
    }

    /// Called by `.featureTipScope(_:)` when its host screen is covered/popped.
    func deactivateScope(_ scopeID: String) {
        guard activeScopes.contains(scopeID) else { return }
        activeScopes.remove(scopeID)
        // Forget where this scope's targets last sat, so the next time the user
        // enters the screen the tip starts from its `defaultEdge` instead of
        // wherever they previously scrolled to (e.g. clamped to the top edge).
        for tip in FeatureTipDefinitions.all {
            if case .scoped(scopeID, _) = tip.behavior {
                lastFrames.removeValue(forKey: tip.anchorID)
            }
        }
        recompute()
    }

    /// Reported by the overlay so the fallback edge can be derived from a
    /// last-known frame relative to the screen middle.
    ///
    /// Deliberately NOT gated on `hasUnseenTips`: the overlay reports this once
    /// when it first lays out (app launch), which may be before any tip becomes
    /// unseen (e.g. a debug reset, or simply ordering). Skipping it would leave
    /// `viewportHeight == 0`, making `edge(for:)` fall back to `.bottom` and the
    /// tip wrongly reappear at the bottom after scrolling its target off the top.
    /// It's not a hot path — it only fires on appear / rotation.
    func setViewportHeight(_ height: CGFloat) {
        guard viewportHeight != height else { return }
        viewportHeight = height
        recompute()
    }

    // MARK: - Dismissal

    /// Permanently dismiss the feature owning the given tip id (its target was
    /// tapped). Clears every tip sharing the same `featureKey`, so resolving a
    /// later stage also retires the earlier guiding tips.
    func markSeen(_ id: String) {
        guard let tip = FeatureTipDefinitions.all.first(where: { $0.id == id }) else { return }
        let groupIDs = FeatureTipDefinitions.all
            .filter { $0.featureKey == tip.featureKey }
            .map(\.id)
        let newlySeen = Set(groupIDs).subtracting(seenIDs)
        guard !newlySeen.isEmpty else { return }
        seenIDs.formUnion(newlySeen)
        refreshHasUnseenTips()
        persistSeenIDs()
        recompute()
    }

    /// Suppress every currently-defined tip. Call once on the user's first
    /// onboarding completion so new installs don't see tooltips for features
    /// the onboarding tutorial already covered.
    func markAllCurrentTipsAsSeen() {
        let allIDs = FeatureTipDefinitions.all.map(\.id)
        seenIDs.formUnion(allIDs)
        refreshHasUnseenTips()
        persistSeenIDs()
        recompute()
    }

    // MARK: - Selection

    /// Whether a tip is currently eligible to display, per its behavior.
    private func isEligible(_ tip: FeatureTip) -> Bool {
        guard !seenIDs.contains(tip.id) else { return false }
        switch tip.behavior {
        case .anchorVisible:
            return frames[tip.anchorID] != nil
        case .scoped(let scopeID, _):
            return activeScopes.contains(scopeID)
        }
    }

    /// The edge a scoped tip clamps to when its anchor is off-screen.
    private func edge(for tip: FeatureTip) -> FeatureTipEdge {
        guard case .scoped(_, let defaultEdge) = tip.behavior else { return .bottom }
        guard let last = lastFrames[tip.anchorID], viewportHeight > 0 else { return defaultEdge }
        return last.midY < viewportHeight / 2 ? .top : .bottom
    }

    /// Pick the highest-priority eligible tip and publish its position.
    private func recompute() {
        let candidate = FeatureTipDefinitions.all
            .filter(isEligible)
            .max { $0.priority < $1.priority }

        let newFrame = candidate.flatMap { frames[$0.anchorID] }
        let newEdge = candidate.map(edge) ?? .bottom

        let identityChanged = activeTip?.id != candidate?.id
        guard identityChanged || activeFrame != newFrame || fallbackEdge != newEdge else { return }

        if identityChanged {
            // Animate the tip appearing / swapping targets — crisp and bouncy.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                activeTip = candidate
                activeFrame = newFrame
                fallbackEdge = newEdge
            }
        } else {
            // Same tip following its target during a scroll — update position
            // without a per-tick spring so the bubble tracks smoothly.
            activeFrame = newFrame
            fallbackEdge = newEdge
        }
    }

    private func refreshHasUnseenTips() {
        hasUnseenTips = FeatureTipDefinitions.all.contains { !seenIDs.contains($0.id) }
    }

    private func persistSeenIDs() {
        defaults.set(Array(seenIDs), forKey: seenIDsKey)
    }

    // MARK: - Debug / Testing

    /// Clear all seen state so tips reappear (for manual testing).
    func resetSeenState() {
        seenIDs.removeAll()
        refreshHasUnseenTips()
        persistSeenIDs()
        recompute()
    }
}
