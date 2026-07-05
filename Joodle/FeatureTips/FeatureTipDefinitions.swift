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
        /// The "Customization" row in Settings.
        static let wigglyCustomizationRow = "featureTip.wigglyStrokes.customizationRow"
        /// The "Wiggly Strokes" toggle on the Customization screen.
        static let wigglyToggle = "featureTip.wigglyStrokes.toggle"
        /// The "Customization" row in Settings, guiding toward the rainbow theme.
        static let rainbowCustomizationRow = "featureTip.rainbow.customizationRow"
        /// The rainbow swatch in the Theme Color grid on the Customization screen.
        static let rainbowSwatch = "featureTip.rainbow.swatch"
        /// The Instagram quick-share button in `ShareCardSelectorView`.
        static let instagramShare = "featureTip.instagramShare"
    }

    /// Stable scope identifiers for `.scoped` tips. A scope is a whole screen
    /// whose visibility decides whether the tip is eligible (see
    /// `.featureTipScope(_:)`).
    enum ScopeID {
        static let settings = "featureTipScope.settings"
        static let customization = "featureTipScope.customization"
    }

    /// Shared key linking the two-stage Wiggly Strokes discovery so touching
    /// the toggle resolves both stages at once.
    private static let wigglyStrokesFeature = "wigglyStrokes"

    /// Shared key linking the two-stage rainbow theme discovery so selecting the
    /// rainbow swatch resolves both stages at once.
    private static let rainbowFeature = "rainbow"

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
        // Stage 1: guide the user from Settings into the Customization screen.
        // Pro only — don't send free users toward a toggle they can't enable.
        FeatureTip(
            id: "featureTip.wigglyStrokes.settingsEntry",
            anchorID: AnchorID.wigglyCustomizationRow,
            featureKey: wigglyStrokesFeature,
            message: "Make your doodles wiggle",
            behavior: .scoped(scopeID: ScopeID.settings, defaultEdge: .bottom),
            priority: 5,
            requiresPremium: true,
            showsAfterOnboarding: true
        ),
        // Stage 2: point at the toggle switch on the Customization screen.
        FeatureTip(
            id: "featureTip.wigglyStrokes.toggleEntry",
            anchorID: AnchorID.wigglyToggle,
            featureKey: wigglyStrokesFeature,
            message: "Make your doodles wiggle",
            behavior: .scoped(scopeID: ScopeID.customization, defaultEdge: .bottom),
            horizontalTarget: .trailing,
            priority: 6,
            requiresPremium: true,
            showsAfterOnboarding: true
        ),
        // Rainbow theme discovery (Pro only, lower priority than Wiggly Strokes
        // so it surfaces only once Wiggly has been resolved).
        // Stage 1: guide the user from Settings into the Customization screen.
        FeatureTip(
            id: "featureTip.rainbow.settingsEntry",
            anchorID: AnchorID.rainbowCustomizationRow,
            featureKey: rainbowFeature,
            message: "Try one color a month",
            behavior: .scoped(scopeID: ScopeID.settings, defaultEdge: .bottom),
            priority: 3,
            requiresPremium: true,
            showsAfterOnboarding: true
        ),
        // Stage 2: point at the rainbow swatch in the Theme Color grid.
        FeatureTip(
            id: "featureTip.rainbow.swatchEntry",
            anchorID: AnchorID.rainbowSwatch,
            featureKey: rainbowFeature,
            message: "Try one color a month",
            behavior: .scoped(scopeID: ScopeID.customization, defaultEdge: .bottom),
            priority: 4,
            requiresPremium: true,
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
