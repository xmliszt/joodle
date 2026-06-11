//
//  FeatureTipDefinitions.swift
//  Joodle
//
//  Static catalogue of every feature-discovery tooltip, mirroring how
//  `ChangelogData` holds bundled changelog entries. Add one entry per feature
//  you want existing (already-onboarded) users to discover, then attach the
//  matching `.featureTip(_:)` modifier to the target control.
//

import Foundation

enum FeatureTipDefinitions {
    /// Stable anchor / tip identifiers. Kept in one place so the catalogue and
    /// the `.featureTip(_:)` call sites can't drift apart.
    enum AnchorID {
        static let cameraReference = "featureTip.cameraReference"
        /// The "Experimental Features" row in Settings' Labs section.
        static let wigglyExperimentRow = "featureTip.wigglyStrokes.experimentRow"
        /// The "Wiggly Strokes" toggle on the Experimental Features screen.
        static let wigglyToggle = "featureTip.wigglyStrokes.toggle"
        /// The Instagram quick-share button in `ShareCardSelectorView`.
        static let instagramShare = "featureTip.instagramShare"
    }

    /// Stable scope identifiers for `.scoped` tips. A scope is a whole screen
    /// whose visibility decides whether the tip is eligible (see
    /// `.featureTipScope(_:)`).
    enum ScopeID {
        static let settings = "featureTipScope.settings"
        static let experimentalFeatures = "featureTipScope.experimentalFeatures"
    }

    /// Shared key linking the two-stage Wiggly Strokes discovery so touching
    /// the toggle resolves both stages at once.
    private static let wigglyStrokesFeature = "wigglyStrokes"

    /// All defined tips. Order is irrelevant — `FeatureTipManager` selects by
    /// `priority`.
    static let all: [FeatureTip] = [
        FeatureTip(
            id: "featureTip.cameraReference",
            anchorID: AnchorID.cameraReference,
            featureKey: "cameraReference",
            message: "Take a photo as reference",
            priority: 0
        ),
        // Stage 1: guide the user from Settings into the Labs section.
        FeatureTip(
            id: "featureTip.wigglyStrokes.settingsEntry",
            anchorID: AnchorID.wigglyExperimentRow,
            featureKey: wigglyStrokesFeature,
            message: "Make your doodles wiggle",
            behavior: .scoped(scopeID: ScopeID.settings, defaultEdge: .bottom),
            priority: 5,
            showsAfterOnboarding: true
        ),
        // Stage 2: point at the toggle switch on the Experimental screen.
        FeatureTip(
            id: "featureTip.wigglyStrokes.toggleEntry",
            anchorID: AnchorID.wigglyToggle,
            featureKey: wigglyStrokesFeature,
            message: "Make your doodles wiggle",
            behavior: .scoped(scopeID: ScopeID.experimentalFeatures, defaultEdge: .bottom),
            horizontalTarget: .trailing,
            priority: 6,
            showsAfterOnboarding: true
        ),
        // Surface the Instagram quick-share path. The bubble points at the
        // Instagram share button, which is always on screen while the share
        // sheet is open (when Instagram is installed).
        FeatureTip(
            id: "featureTip.instagramShare",
            anchorID: AnchorID.instagramShare,
            featureKey: "instagramShare",
            message: "Share your doodle to Instagram",
            priority: 1,
            showsAfterOnboarding: true
        )
    ]
}
