//
//  TutorialCoordinator.swift
//  Joodle
//
//  State management for tutorial flow.
//

import SwiftUI
import Combine

// MARK: - Notifications

extension Notification.Name {
    static let tutorialPrerequisiteNeeded = Notification.Name("tutorialPrerequisiteNeeded")
    static let tutorialStepCompleted = Notification.Name("tutorialStepCompleted")
    static let tutorialDoubleTapCompleted = Notification.Name("tutorialDoubleTapCompleted")
}

// MARK: - Tutorial Coordinator

@MainActor
class TutorialCoordinator: ObservableObject {

    // MARK: - Published State

    @Published var currentStepIndex: Int = 0
    @Published var isActive: Bool = true
    @Published private(set) var highlightFrames: [String: CGRect] = [:]
    @Published var showGestureHint: Bool = false
    @Published var showingCompletion: Bool = false
    @Published var isUserScrubbing: Bool = false  // Hide highlight overlay when user is scrubbing

    // MARK: - Configuration

    let steps: [TutorialStepConfig]
    let singleStepMode: Bool
    private let onComplete: () -> Void

    // MARK: - Computed Properties

    var currentStep: TutorialStepConfig? {
        guard currentStepIndex >= 0 && currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    var isLastStep: Bool {
        currentStepIndex >= steps.count - 1
    }

    var isFirstStep: Bool {
        currentStepIndex == 0
    }

    var progress: Double {
        guard steps.count > 0 else { return 0 }
        return Double(currentStepIndex + 1) / Double(steps.count)
    }

    // MARK: - Init

    init(
        steps: [TutorialStepConfig],
        startingIndex: Int = 0,
        singleStepMode: Bool = false,
        onComplete: @escaping () -> Void
    ) {
        self.steps = steps
        self.currentStepIndex = min(startingIndex, max(0, steps.count - 1))
        self.singleStepMode = singleStepMode
        self.onComplete = onComplete
    }

    // MARK: - Navigation Actions

    /// Advance to the next step or complete if on last step
    func advance() {
        Haptic.play(with: .light)

        // In singleStepMode, we still play through all steps in the array before completing
        // This allows multi-step tutorials (like drawAndEdit with 2 steps) to work correctly
        if isLastStep {
            complete()
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStepIndex += 1
                showGestureHint = false
            }
            executePrerequisiteIfNeeded()
        }

        // Post notification for any listeners
        NotificationCenter.default.post(
            name: .tutorialStepCompleted,
            object: nil,
            userInfo: ["stepIndex": currentStepIndex - 1]
        )
    }

    /// Go back to the previous step
    func goBack() {
        guard !isFirstStep else { return }
        Haptic.play(with: .light)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStepIndex -= 1
            showGestureHint = false
        }
    }

    /// Complete the tutorial
    func complete() {
        Haptic.play(with: .medium)

        // Show completion indication first
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showingCompletion = true
        }

        // After showing completion, deactivate and call onComplete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.isActive = false
                self?.showingCompletion = false
            }

            // Small delay to allow animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.onComplete()
            }
        }
    }

    /// Skip all remaining steps and complete (bypasses completion animation)
    func skipAll() {
        Haptic.play(with: .light)

        // Skip the completion animation for faster exit
        withAnimation(.easeOut(duration: 0.3)) {
            isActive = false
        }

        // Small delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onComplete()
        }
    }

    // MARK: - Frame Registration

    /// Register the frame of a highlight anchor
    func registerHighlightFrame(id: String, frame: CGRect) {
        // Only update if frame actually changed to avoid unnecessary redraws
        if highlightFrames[id] != frame {
            highlightFrames[id] = frame
        }
    }

    /// Remove a registered frame
    func unregisterHighlightFrame(id: String) {
        highlightFrames.removeValue(forKey: id)
    }

    /// Get the highlight frame for a specific anchor
    func getHighlightFrame(for anchor: TutorialHighlightAnchor) -> CGRect? {
        switch anchor {
        case .button(let buttonId):
            return highlightFrames[buttonId.rawValue]
        case .gridEntry(let dateOffset):
            let key = "gridEntry.\(dateOffset)"
            return highlightFrames[key]
        case .drawingCanvas:
            return highlightFrames["drawingCanvas"]
        case .gesture, .none:
            return nil
        }
    }

    // MARK: - End Condition Checking

    /// Check if an event matches the current step's end condition
    func checkEndCondition(_ event: TutorialEvent) -> Bool {
        guard let step = currentStep else { return false }

        let shouldAdvance: Bool
        switch (step.endCondition, event) {
        case (.scrubEnded, .scrubEnded):
            shouldAdvance = true

        case (.buttonTapped(let expectedId), .buttonTapped(let actualId)):
            shouldAdvance = expectedId == actualId

        case (.viewDismissed(let expectedId), .viewDismissed(let actualId)):
            shouldAdvance = expectedId == actualId

        case (.viewModeChanged(let expectedMode), .viewModeChanged(let actualMode)):
            shouldAdvance = expectedMode == actualMode

        case (.pinchGestureCompleted, .pinchGestureCompleted):
            shouldAdvance = true

        case (.yearChanged, .yearChanged):
            shouldAdvance = true

        case (.sheetDismissed, .sheetDismissed):
            shouldAdvance = true

        case (.doubleTapCompleted, .doubleTapCompleted):
            shouldAdvance = true

        default:
            shouldAdvance = false
        }

        if shouldAdvance {
            advance()
        }

        return shouldAdvance
    }

    // MARK: - Private Methods

    private func executePrerequisiteIfNeeded() {
        guard let prerequisite = currentStep?.prerequisiteSetup else { return }

        // Post notification for prerequisite setup
        NotificationCenter.default.post(
            name: .tutorialPrerequisiteNeeded,
            object: nil,
            userInfo: ["prerequisite": prerequisite]
        )
    }
}

// MARK: - Tutorial Events

/// Events that can trigger step completion
enum TutorialEvent: Equatable {
    case scrubEnded
    case buttonTapped(id: TutorialButtonId)
    case viewDismissed(viewId: String)
    case viewModeChanged(to: ViewMode)
    case pinchGestureCompleted
    case yearChanged
    case sheetDismissed
    case doubleTapCompleted
}

// MARK: - Preview Extensions

#if DEBUG
extension TutorialCoordinator {
    /// Creates a coordinator pre-configured for preview with mock frames injected
    static func forPreview(
        step: TutorialStepType,
        mockFrames: [String: CGRect] = PreviewMockFrames.standard
    ) -> TutorialCoordinator {
        let steps = TutorialSteps.singleStep(step)
        let coordinator = TutorialCoordinator(
            steps: steps,
            startingIndex: 0,
            singleStepMode: true,
            onComplete: { print("Preview: Tutorial completed") }
        )

        // Inject mock frames so overlay renders correctly
        mockFrames.forEach { key, frame in
            coordinator.registerHighlightFrame(id: key, frame: frame)
        }

        return coordinator
    }

    /// Creates coordinator for full flow preview
    static func forFullFlowPreview(
        startingStep: TutorialStepType? = nil,
        mockFrames: [String: CGRect] = PreviewMockFrames.standard
    ) -> TutorialCoordinator {
        let startIndex = startingStep.map { TutorialSteps.startingIndex(for: $0) } ?? 0
        let coordinator = TutorialCoordinator(
            steps: TutorialSteps.onboarding,
            startingIndex: startIndex,
            singleStepMode: false,
            onComplete: { print("Preview: Tutorial completed") }
        )

        mockFrames.forEach { key, frame in
            coordinator.registerHighlightFrame(id: key, frame: frame)
        }

        return coordinator
    }
}

// MARK: - Preview Mock Frames

enum PreviewMockFrames {
    // Standard iPhone 15 Pro dimensions
    static let screenSize = CGSize(width: 393, height: 852)

    static let standard: [String: CGRect] = [
        // Header buttons
        TutorialButtonId.viewModeButton.rawValue: CGRect(x: 340, y: 70, width: 44, height: 44),
        TutorialButtonId.yearSelector.rawValue: CGRect(x: 60, y: 70, width: 80, height: 44),

        // Entry editing buttons
        TutorialButtonId.paintButton.rawValue: CGRect(x: 340, y: 520, width: 44, height: 44),
        TutorialButtonId.bellIcon.rawValue: CGRect(x: 30, y: 520, width: 44, height: 44),

        // Split view center handle
        TutorialButtonId.centerHandle.rawValue: CGRect(x: 166, y: 426, width: 60, height: 4),

        // Grid entries
        "gridEntry.0": CGRect(x: 172, y: 320, width: 48, height: 48), // Today
        "gridEntry.-1": CGRect(x: 116, y: 320, width: 48, height: 48), // Yesterday
        "gridEntry.1": CGRect(x: 228, y: 320, width: 48, height: 48), // Tomorrow
    ]

    // iPhone SE (smaller screen)
    static let iPhoneSE: [String: CGRect] = [
        TutorialButtonId.viewModeButton.rawValue: CGRect(x: 320, y: 60, width: 40, height: 40),
        TutorialButtonId.yearSelector.rawValue: CGRect(x: 50, y: 60, width: 70, height: 40),
        TutorialButtonId.paintButton.rawValue: CGRect(x: 320, y: 450, width: 40, height: 40),
        TutorialButtonId.bellIcon.rawValue: CGRect(x: 25, y: 450, width: 40, height: 40),
        "gridEntry.0": CGRect(x: 160, y: 280, width: 40, height: 40),
    ]

    // iPad Pro 11"
    static let iPadPro11: [String: CGRect] = [
        TutorialButtonId.viewModeButton.rawValue: CGRect(x: 780, y: 80, width: 50, height: 50),
        TutorialButtonId.yearSelector.rawValue: CGRect(x: 80, y: 80, width: 120, height: 50),
        TutorialButtonId.paintButton.rawValue: CGRect(x: 780, y: 700, width: 50, height: 50),
        TutorialButtonId.bellIcon.rawValue: CGRect(x: 40, y: 700, width: 50, height: 50),
        "gridEntry.0": CGRect(x: 420, y: 400, width: 60, height: 60),
    ]
}
#endif
