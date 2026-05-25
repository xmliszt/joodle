//
//  TutorialSteps.swift
//  Joodle
//
//  Central configuration for all tutorial steps.
//  Edit this file to add, remove, or reorder tutorial steps.
//

import Foundation

struct TutorialSteps {

    // MARK: - Onboarding Segments
    //
    // Onboarding is composed by concatenating segments in order. Splitting it
    // up keeps individual tutorials (like the camera sequence) reusable as a
    // single source of truth for both onboarding and Settings entry points.

    /// Steps that come before the camera-reference tutorial inside onboarding.
    private static let preCameraOnboardingSteps: [TutorialStepConfig] = [
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
        )
    ]

    /// Steps that come after the camera-reference tutorial inside onboarding.
    private static let postCameraOnboardingSteps: [TutorialStepConfig] = [
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

    // MARK: - Reusable Tutorial Sequences

    /// Move doodle to another date — Settings-only standalone tutorial.
    /// Deliberately left out of the onboarding flow; it's discoverable in the
    /// Learn Core Features list for users who want to learn it.
    static let moveDrawingSteps: [TutorialStepConfig] = [
        // Step A: long-press the doodle to open the context menu, then tap
        // "Move to Another Date".
        TutorialStepConfig(
            type: .moveDrawing,
            highlightAnchor: .entryDrawing,
            tooltip: TutorialTooltip(
                message: "Long press your doodle and tap the option to \"Move to Another Date\"",
                position: .above
            ),
            endCondition: .moveContextMenuOptionTapped,
            prerequisiteSetup: .prepareForMoveDrawing
        ),

        // Step B: pick a target date (move mode active, custom top-center
        // instruction shown).
        TutorialStepConfig(
            type: .moveDrawing,
            highlightAnchor: .none,
            endCondition: .drawingMoved
        )
    ]

    /// Camera reference tracing — open canvas → tap camera → capture → save & exit.
    /// (Tracing in between is optional; the user can save without drawing anything.)
    /// Reused both inside `onboarding` (right after drawAndEdit) and as a
    /// Settings-launched single tutorial.
    static let cameraReferenceSteps: [TutorialStepConfig] = [
        // Step A: Open the canvas via the paint button on the entry editing view.
        TutorialStepConfig(
            type: .cameraReference,
            highlightAnchor: .button(id: .paintButton),
            tooltip: TutorialTooltip(
                message: "Let's show you a camera trick — tap to open the canvas",
                position: .above
            ),
            endCondition: .buttonTapped(id: .paintButton),
            prerequisiteSetup: .prepareForCameraReference
        ),

        // Step B: On the open canvas, highlight the camera reference button.
        TutorialStepConfig(
            type: .cameraReference,
            highlightAnchor: .button(id: .cameraButton),
            tooltip: TutorialTooltip(
                message: "Tap to use your camera as a tracing reference",
                position: .below
            ),
            endCondition: .cameraLiveEntered
        ),

        // Step C: In live camera mode, highlight the shutter to capture a reference.
        TutorialStepConfig(
            type: .cameraReference,
            highlightAnchor: .button(id: .shutterButton),
            tooltip: TutorialTooltip(
                message: "Frame your subject, then tap the shutter to capture",
                position: .above
            ),
            endCondition: .cameraReferenceCaptured
        ),

        // Step D: Back on the canvas with the captured backdrop. Highlight the
        // whole canvas (not just the save button) so the user can actually
        // draw on top of the reference; the save button sits inside the cutout
        // so it remains tappable to end the step.
        TutorialStepConfig(
            type: .cameraReference,
            highlightAnchor: .drawingCanvas,
            tooltip: TutorialTooltip(
                message: "Trace over your reference if you like, then tap ✓ to save",
                position: .below
            ),
            endCondition: .viewDismissed(viewId: "drawingCanvas")
        )
    ]

    // MARK: - Full Onboarding Sequence

    /// All tutorial steps shown during onboarding flow.
    /// Composed from segments so reusable sequences (e.g. cameraReferenceSteps)
    /// stay a single source of truth between onboarding and Settings.
    static let onboarding: [TutorialStepConfig] =
        preCameraOnboardingSteps + cameraReferenceSteps + postCameraOnboardingSteps

    // MARK: - Single Step Access

    /// Get tutorial configs for a single step type (for Settings tutorials).
    /// Step types that aren't part of the onboarding flow (e.g. moveDrawing)
    /// are special-cased so Settings can still launch them standalone.
    static func singleStep(_ type: TutorialStepType) -> [TutorialStepConfig] {
        switch type {
        case .moveDrawing:
            return moveDrawingSteps
        default:
            return onboarding.filter { $0.type == type }
        }
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
