//
//  TutorialStepConfig.swift
//  Joodle
//
//  Created by AI Assistant on 2025.
//

import SwiftUI

// MARK: - Tutorial Step Type

/// Defines the types of tutorial steps available
enum TutorialStepType: String, CaseIterable, Identifiable {
    case scrubbing
    case drawAndEdit       // Combined: open canvas + draw/edit (replaces openCanvas + drawOnCanvas)
    case switchViewMode
    case switchYear
    case addReminder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scrubbing: return "Browse Your Joodles"
        case .drawAndEdit: return "Draw and Edit Joodle"
        case .switchViewMode: return "Change View Mode"
        case .switchYear: return "Navigate Years"
        case .addReminder: return "Set a Reminder"
        }
    }

    var icon: String {
        switch self {
        case .scrubbing: return "hand.draw"
        case .drawAndEdit: return "paintbrush.pointed"
        case .switchViewMode: return "rectangle.compress.vertical"
        case .switchYear: return "calendar"
        case .addReminder: return "bell"
        }
    }
}

// MARK: - Tutorial Step Configuration

/// Configuration for a single tutorial step
struct TutorialStepConfig: Identifiable {
    let id: UUID = UUID()
    let type: TutorialStepType
    let highlightAnchor: TutorialHighlightAnchor
    let tooltip: TutorialTooltip
    let endCondition: TutorialEndCondition
    let prerequisiteSetup: TutorialPrerequisite?

    init(
        type: TutorialStepType,
        highlightAnchor: TutorialHighlightAnchor,
        tooltip: TutorialTooltip,
        endCondition: TutorialEndCondition,
        prerequisiteSetup: TutorialPrerequisite? = nil
    ) {
        self.type = type
        self.highlightAnchor = highlightAnchor
        self.tooltip = tooltip
        self.endCondition = endCondition
        self.prerequisiteSetup = prerequisiteSetup
    }
}

// MARK: - Highlight Anchor

/// Defines what UI element should be highlighted
enum TutorialHighlightAnchor: Equatable {
    case gridEntry(dateOffset: Int)           // Relative to today (0 = today, -1 = yesterday, etc.)
    case button(id: TutorialButtonId)         // Named button
    case gesture(type: GestureHintType)       // Gesture overlay (no cutout highlight)
    case drawingCanvas                        // The entire drawing canvas view
    case none                                  // No highlight, just dimmed overlay
}

/// Identifiers for buttons that can be highlighted
enum TutorialButtonId: String {
    case paintButton = "tutorial.paintButton"
    case viewModeButton = "tutorial.viewModeButton"
    case yearSelector = "tutorial.yearSelector"
    case bellIcon = "tutorial.bellIcon"
}

// MARK: - End Condition

/// Defines what action completes a tutorial step
enum TutorialEndCondition: Equatable {
    case scrubEnded
    case buttonTapped(id: TutorialButtonId)   // When a specific button is tapped
    case viewDismissed(viewId: String)
    case viewModeChanged(to: ViewMode)
    case pinchGestureCompleted
    case yearChanged
    case sheetDismissed
}

// MARK: - Prerequisite

/// Setup actions that need to happen before a step
enum TutorialPrerequisite {
    case ensureFutureYear
    case populateAnniversaryEntry
    case openEntryEditingView
    case clearSelectionAndScroll  // Deselect entry and scroll grid
}

// MARK: - Tooltip Configuration

/// Configuration for a tutorial tooltip
struct TutorialTooltip {
    let message: String
    let position: TooltipPosition
    let maxWidth: CGFloat

    init(
        message: String,
        position: TooltipPosition = .auto,
        maxWidth: CGFloat = 280
    ) {
        self.message = message
        self.position = position
        self.maxWidth = maxWidth
    }
}

/// Position of the tooltip relative to the highlight
enum TooltipPosition {
    case above
    case below
    case leading
    case trailing
    case auto  // Calculate based on available space
}

// MARK: - Gesture Hint Type

/// Types of gesture hints that can be displayed
enum GestureHintType: Equatable {
    case pinchOut
    case pinchIn
    case tapAndHold
    case swipe(direction: SwipeDirection)

    enum SwipeDirection {
        case up, down, left, right
    }
}
