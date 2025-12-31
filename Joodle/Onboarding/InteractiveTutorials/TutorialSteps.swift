//
//  TutorialSteps.swift
//  Joodle
//
//  Central configuration for all tutorial steps.
//  Edit this file to add, remove, or reorder tutorial steps.
//

import Foundation

struct TutorialSteps {

    // MARK: - Full Onboarding Sequence

    /// All tutorial steps shown during onboarding flow
    static let onboarding: [TutorialStepConfig] = [
        // Step 1: Scrubbing - highlight only today's entry (user's doodle)
        TutorialStepConfig(
            type: .scrubbing,
            highlightAnchor: .gridEntry(dateOffset: 0),  // Today's entry only
            tooltip: TutorialTooltip(
                message: "Tap on your Joodle without releasing your finger, then start dragging to browse",
                position: .below
            ),
            endCondition: .scrubEnded
        ),

        // Step 2: Quick Switch to Today - double-tap center handle
        TutorialStepConfig(
            type: .quickSwitchToday,
            highlightAnchor: .button(id: .centerHandle),
            tooltip: TutorialTooltip(
                message: "Double-tap the handle to quickly jump to today's entry",
                position: .above
            ),
            endCondition: .doubleTapCompleted
        ),

        // Step 3a: Draw and Edit - tap paint button to open canvas
        TutorialStepConfig(
            type: .drawAndEdit,
            highlightAnchor: .button(id: .paintButton),
            tooltip: TutorialTooltip(
                message: "Tap to open the canvas",
                position: .above
            ),
            endCondition: .buttonTapped(id: .paintButton),
            prerequisiteSetup: .navigateToToday  // Simulates the double-tap effect from previous step
        ),

        // Step 3b: Draw and Edit - draw on canvas then dismiss
        TutorialStepConfig(
            type: .drawAndEdit,
            highlightAnchor: .drawingCanvas,
            tooltip: TutorialTooltip(
                message: "Draw or edit your Joodle, then tap ✓ to save",
                position: .below
            ),
            endCondition: .viewDismissed(viewId: "drawingCanvas")
        ),

        // Step 4a: Switch View Mode (button tap)
        TutorialStepConfig(
            type: .switchViewMode,
            highlightAnchor: .button(id: .viewModeButton),
            tooltip: TutorialTooltip(
                message: "Tap to switch to minimized view to see the whole year",
                position: .below
            ),
            endCondition: .viewModeChanged(to: .year)
        ),

        // Step 4b: Switch View Mode (pinch gesture)
        TutorialStepConfig(
            type: .switchViewMode,
            highlightAnchor: .gesture(type: .pinchOut),
            tooltip: TutorialTooltip(
                message: "Pinch outward to zoom back to normal view",
                position: .auto
            ),
            endCondition: .pinchGestureCompleted,
            prerequisiteSetup: .clearSelectionAndScroll
        ),

        // Step 5: Switch Year
        TutorialStepConfig(
            type: .switchYear,
            highlightAnchor: .button(id: .yearSelector),
            tooltip: TutorialTooltip(
                message: "Tap to select the future year",
                position: .below
            ),
            endCondition: .yearChanged
        ),

        // Step 6: Add Reminder
        TutorialStepConfig(
            type: .addReminder,
            highlightAnchor: .button(id: .bellIcon),
            tooltip: TutorialTooltip(
                message: "Tap to set an anniversary alarm. Anniversary alarm can only be set if it is today or in the future.",
                position: .above
            ),
            endCondition: .sheetDismissed,
            prerequisiteSetup: .populateAnniversaryEntry
        )
    ]

    // MARK: - Single Step Access

    /// Get tutorial configs for a single step type (for Settings tutorials)
    /// Note: Some step types like switchViewMode have multiple configs
    static func singleStep(_ type: TutorialStepType) -> [TutorialStepConfig] {
        onboarding.filter { $0.type == type }
    }

    /// Get the starting index for a specific step type in the onboarding array
    static func startingIndex(for type: TutorialStepType) -> Int {
        onboarding.firstIndex { $0.type == type } ?? 0
    }

    // MARK: - Step Counts

    /// Total number of steps in onboarding
    static var onboardingStepCount: Int {
        onboarding.count
    }

    /// Number of unique step types (for Settings tutorials list)
    static var uniqueStepTypeCount: Int {
        TutorialStepType.allCases.count
    }
}
