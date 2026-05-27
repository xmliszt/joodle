//
//  FeatureTip.swift
//  Joodle
//
//  Model for a non-blocking feature-discovery tooltip — a subtle bubble that
//  points at a control to surface a newly-shipped feature to users who already
//  finished onboarding. Unlike the onboarding interactive tutorial it never
//  dims or blocks input; it disappears for good the moment the user taps the
//  target. See `FeatureTipManager` for eligibility/lifecycle.
//

import Foundation

/// A single discoverable feature hint.
struct FeatureTip: Identifiable {
    /// Stable identity used to persist the "seen" state. Never reuse across
    /// different features — once an id is marked seen it never shows again.
    let id: String

    /// Matches the `.featureTip(_:)` anchor attached to the target control.
    /// The manager only surfaces the tip while an anchor with this id is on
    /// screen, so the bubble can be positioned against the live frame.
    let anchorID: String

    /// Localizable message shown in the bubble. `LocalizedStringResource`
    /// literals are auto-extracted into `Localizable.xcstrings`, matching the
    /// existing `TooltipBubble` convention.
    let message: LocalizedStringResource

    /// Higher wins when several tips are eligible on the same screen — only one
    /// shows at a time.
    let priority: Int

    init(id: String, anchorID: String, message: LocalizedStringResource, priority: Int = 0) {
        self.id = id
        self.anchorID = anchorID
        self.message = message
        self.priority = priority
    }
}
