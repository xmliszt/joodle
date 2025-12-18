//
//  TutorialPreviews.swift
//  Joodle
//
//  Comprehensive preview catalog for tutorial development and debugging.
//

import SwiftUI

#if DEBUG

// MARK: - Full Tutorial Flow

#Preview("Full Tutorial Flow") {
    let viewModel = OnboardingViewModel()
    viewModel.firstJoodleData = PLACEHOLDER_DATA
    return InteractiveTutorialView(viewModel: viewModel)
}

// MARK: - Individual Steps (Full View)

#Preview("Step 1: Scrubbing") {
    let viewModel = OnboardingViewModel()
    viewModel.firstJoodleData = PLACEHOLDER_DATA
    return InteractiveTutorialView(
        viewModel: viewModel,
        singleStepMode: true,
        startingStepType: .scrubbing
    )
}

#Preview("Step 2: Draw and Edit") {
    let viewModel = OnboardingViewModel()
    viewModel.firstJoodleData = PLACEHOLDER_DATA
    return InteractiveTutorialView(
        viewModel: viewModel,
        singleStepMode: true,
        startingStepType: .drawAndEdit
    )
}

#Preview("Step 3: View Mode") {
    let viewModel = OnboardingViewModel()
    viewModel.firstJoodleData = PLACEHOLDER_DATA
    return InteractiveTutorialView(
        viewModel: viewModel,
        singleStepMode: true,
        startingStepType: .switchViewMode
    )
}

#Preview("Step 4: Year Switch") {
    let viewModel = OnboardingViewModel()
    viewModel.firstJoodleData = PLACEHOLDER_DATA
    return InteractiveTutorialView(
        viewModel: viewModel,
        singleStepMode: true,
        startingStepType: .switchYear
    )
}

#Preview("Step 5: Add Reminder") {
    let viewModel = OnboardingViewModel()
    viewModel.firstJoodleData = PLACEHOLDER_DATA
    return InteractiveTutorialView(
        viewModel: viewModel,
        singleStepMode: true,
        startingStepType: .addReminder
    )
}

// MARK: - Overlay Only (Fast Preview)

#Preview("Overlay: Scrubbing") {
    TutorialOverlayPreviewContainer(step: .scrubbing)
}

#Preview("Overlay: Draw and Edit") {
    TutorialOverlayPreviewContainer(step: .drawAndEdit)
}

#Preview("Overlay: View Mode Button") {
    TutorialOverlayPreviewContainer(step: .switchViewMode)
}

#Preview("Overlay: Year Switch") {
    TutorialOverlayPreviewContainer(step: .switchYear)
}

#Preview("Overlay: Reminder") {
    TutorialOverlayPreviewContainer(step: .addReminder)
}

// MARK: - Overlay Preview Container

/// Lightweight container for fast overlay iteration without full view hierarchy
struct TutorialOverlayPreviewContainer: View {
    let step: TutorialStepType

    var body: some View {
        let steps = TutorialSteps.singleStep(step)
        let coordinator = TutorialCoordinator(
            steps: steps,
            singleStepMode: true,
            onComplete: {}
        )

        // Inject mock frames
        let mockFrames = PreviewMockFrames.standard
        mockFrames.forEach { key, frame in
            coordinator.registerHighlightFrame(id: key, frame: frame)
        }

        return ZStack {
            // Simulated app background
            Color.backgroundColor

            // Simulated UI elements at expected positions
            MockUIElementsView(frames: mockFrames)

            // The actual overlay being tested
            TutorialOverlayView(coordinator: coordinator)
        }
        .ignoresSafeArea()
    }
}

/// Renders placeholder rectangles at mock frame positions for visual reference
struct MockUIElementsView: View {
    let frames: [String: CGRect]

    var body: some View {
        ZStack {
            ForEach(Array(frames.keys.sorted()), id: \.self) { key in
                if let frame = frames[key] {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appSurface)
                        .frame(width: frame.width, height: frame.height)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                        .overlay(
                            Text(shortLabel(for: key))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        )
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
    }

    private func shortLabel(for key: String) -> String {
        if key.contains(".") {
            return String(key.split(separator: ".").last ?? "")
        }
        return String(key.prefix(10))
    }
}

// MARK: - Component Previews

#Preview("Tooltip - Above Highlight") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()

        // Mock highlight target
        Circle()
            .fill(Color.appAccent)
            .frame(width: 50, height: 50)
            .position(x: 196, y: 600)

        TutorialTooltipView(
            tooltip: TutorialTooltip(
                message: "This tooltip appears above the highlight area",
                position: .above
            ),
            highlightFrame: CGRect(x: 171, y: 575, width: 50, height: 50),
            screenSize: PreviewMockFrames.screenSize
        )
    }
}

#Preview("Tooltip - Below Highlight") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()

        Circle()
            .fill(Color.appAccent)
            .frame(width: 50, height: 50)
            .position(x: 196, y: 200)

        TutorialTooltipView(
            tooltip: TutorialTooltip(
                message: "This tooltip appears below the highlight area",
                position: .below
            ),
            highlightFrame: CGRect(x: 171, y: 175, width: 50, height: 50),
            screenSize: PreviewMockFrames.screenSize
        )
    }
}

#Preview("Tooltip - Auto Position") {
    VStack(spacing: 0) {
        // Near top - should go below
        ZStack {
            Color.gray.opacity(0.1)

            Circle()
                .fill(Color.appAccent)
                .frame(width: 40, height: 40)
                .position(x: 175, y: 60)

            TutorialTooltipView(
                tooltip: TutorialTooltip(message: "Near top → below", position: .auto),
                highlightFrame: CGRect(x: 155, y: 40, width: 40, height: 40),
                screenSize: CGSize(width: 350, height: 200)
            )
        }
        .frame(height: 200)

        Divider()

        // Near bottom - should go above
        ZStack {
            Color.gray.opacity(0.1)

            Circle()
                .fill(Color.appAccent)
                .frame(width: 40, height: 40)
                .position(x: 175, y: 140)

            TutorialTooltipView(
                tooltip: TutorialTooltip(message: "Near bottom → above", position: .auto),
                highlightFrame: CGRect(x: 155, y: 120, width: 40, height: 40),
                screenSize: CGSize(width: 350, height: 200)
            )
        }
        .frame(height: 200)
    }
}

// MARK: - Gesture Hints

#Preview("Gesture: All Types") {
    ScrollView {
        VStack(spacing: 40) {
            ForEach([
                GestureHintType.pinchOut,
                .pinchIn,
                .tapAndHold,
                .swipe(direction: .up),
                .swipe(direction: .left)
            ], id: \.self) { gestureType in
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 180)

                    GestureHintOverlay(gestureType: gestureType)
                }
            }
        }
        .padding()
    }
}

// MARK: - Dimmed Overlay

#Preview("Dimmed Overlay - Button Cutout") {
    ZStack {
        // Background content
        VStack {
            HStack {
                Spacer()
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 44, height: 44)
            }
            .padding()
            Spacer()
        }

        // Overlay with cutout
        DimmedOverlayWithCutout(
            cutoutFrame: CGRect(x: 320, y: 60, width: 60, height: 60),
            cornerRadius: 30,
            dimOpacity: 0.7
        )
    }
    .ignoresSafeArea()
}

#Preview("Dimmed Overlay - Grid Entry Cutout") {
    ZStack {
        // Background grid simulation
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: 7), spacing: 8) {
            ForEach(0..<35, id: \.self) { index in
                Circle()
                    .fill(index == 17 ? Color.appAccent : Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
        }
        .padding()

        // Overlay with cutout for center item
        DimmedOverlayWithCutout(
            cutoutFrame: CGRect(x: 168, y: 140, width: 56, height: 56),
            cornerRadius: 12,
            dimOpacity: 0.7
        )
    }
    .ignoresSafeArea()
}

// MARK: - Highlight Ring

#Preview("Highlight Ring Animation") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()

        // Target element
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.appAccent)
            .frame(width: 80, height: 80)
            .position(x: 196, y: 426)

        // Highlight ring
        HighlightRing(
            frame: CGRect(x: 148, y: 378, width: 96, height: 96),
            cornerRadius: 16
        )
    }
}

// MARK: - Mock Data Store

#Preview("Mock Data Store") {
    struct PreviewContainer: View {
        @StateObject private var store = MockDataStore.previewStore(
            withUserDoodle: true,
            hasSelectedEntry: true
        )

        var body: some View {
            VStack(spacing: 16) {
                Text("Mock Data Store")
                    .font(.headline)

                Group {
                    Text("Year: \(store.selectedYear)")
                    Text("View Mode: \(store.viewMode == .now ? "Normal" : "Year")")
                    Text("Entries: \(store.entries.count)")
                    Text("Selected: \(store.selectedDateItem?.date.formatted() ?? "None")")
                }
                .font(.caption)

                Divider()

                // Entry list
                ForEach(store.entries) { entry in
                    HStack {
                        Text(entry.dateString)
                        Spacer()
                        if entry.hasDrawing {
                            Image(systemName: "scribble")
                        }
                        if !entry.body.isEmpty {
                            Image(systemName: "text.alignleft")
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal)
                }

                Spacer()

                // Actions
                HStack(spacing: 12) {
                    Button("Add Entry") {
                        let entry = MockDayEntry(
                            date: Date().addingTimeInterval(86400 * Double.random(in: 1...30)),
                            body: "Test entry"
                        )
                        store.addEntry(entry)
                    }

                    Button("Toggle Mode") {
                        store.viewMode = store.viewMode == .now ? .year : .now
                    }

                    Button("Reset") {
                        store.reset()
                    }
                }
                .font(.caption)
            }
            .padding()
        }
    }

    return PreviewContainer()
}

// MARK: - Tutorial Steps Configuration

#Preview("Tutorial Steps List") {
    List {
        Section("Onboarding Steps (\(TutorialSteps.onboarding.count))") {
            ForEach(Array(TutorialSteps.onboarding.enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(step.type.title)
                            .font(.subheadline.bold())
                    }

                    HStack {
                        Label {
                            Text(anchorDescription(step.highlightAnchor))
                        } icon: {
                            Image(systemName: "scope")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)

                        Spacer()

                        Label {
                            Text(endDescription(step.endCondition))
                        } icon: {
                            Image(systemName: "flag.checkered")
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                    }

                    Text(step.tooltip.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }

        Section("Step Types") {
            ForEach(TutorialStepType.allCases) { type in
                Label(type.title, systemImage: type.icon)
            }
        }
    }
}

// MARK: - Helper Functions

private func anchorDescription(_ anchor: TutorialHighlightAnchor) -> String {
    switch anchor {
    case .button(let id):
        let shortId = id.rawValue.split(separator: ".").last ?? ""
        return "Button: \(shortId)"
    case .gridEntry(let offset):
        return "Grid[\(offset)]"
    case .gesture(let type):
        switch type {
        case .pinchOut: return "Pinch Out"
        case .pinchIn: return "Pinch In"
        case .tapAndHold: return "Tap & Hold"
        case .swipe(let dir):
            switch dir {
            case .up: return "Swipe ↑"
            case .down: return "Swipe ↓"
            case .left: return "Swipe ←"
            case .right: return "Swipe →"
            }
        }
    case .drawingCanvas:
        return "Drawing Canvas"
    case .none:
        return "None"
    }
}

private func endDescription(_ condition: TutorialEndCondition) -> String {
    switch condition {
    case .scrubEnded: return "Scrub Ends"
    case .buttonTapped(let id):
        let shortId = id.rawValue.split(separator: ".").last ?? ""
        return "Tap: \(shortId)"
    case .viewDismissed(let id): return "Dismiss: \(id)"
    case .viewModeChanged(let mode): return "Mode → \(mode == .now ? "Normal" : "Year")"
    case .pinchGestureCompleted: return "Pinch Done"
    case .yearChanged: return "Year Changes"
    case .sheetDismissed: return "Sheet Closes"
    case .doubleTapCompleted: return "Double Tap"
    }
}

#endif
