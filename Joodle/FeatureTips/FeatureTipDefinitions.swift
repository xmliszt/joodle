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
    }

    /// All defined tips. Order is irrelevant — `FeatureTipManager` selects by
    /// `priority`.
    static let all: [FeatureTip] = [
        FeatureTip(
            id: "featureTip.cameraReference",
            anchorID: AnchorID.cameraReference,
            message: "Try to use a photo as doodle reference",
            priority: 0
        )
    ]
}
