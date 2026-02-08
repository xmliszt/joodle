//
//  TutorialDebugOverlay.swift
//  Joodle
//
//  Debug controls overlay for tutorial development and testing.
//

import SwiftUI

#if DEBUG

// MARK: - Tutorial Debug Overlay

struct TutorialDebugOverlay: View {
    @ObservedObject var coordinator: TutorialCoordinator
    @State private var isExpanded = false
    @State private var position: CGPoint = CGPoint(x: 60, y: 700)
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            debugContent
                .position(
                    x: min(max(40, position.x + dragOffset.width), geometry.size.width - 40),
                    y: min(max(100, position.y + dragOffset.height), geometry.size.height - 100)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            position.x += value.translation.width
                            position.y += value.translation.height
                            dragOffset = .zero
                        }
                )
        }
    }

    private var debugContent: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Toggle button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark.circle.fill" : "ladybug.fill")
                    .font(.appTitle2())
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }

            if isExpanded {
                debugPanel
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
            }
        }
    }

    // MARK: - Debug Panel

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Tutorial Debug")
                .font(.appHeadline())
                .foregroundColor(.white)

            Divider().background(Color.white.opacity(0.3))

            // Step info
            stepInfoSection

            Divider().background(Color.white.opacity(0.3))

            // Frame info
            frameInfoSection

            Divider().background(Color.white.opacity(0.3))

            // Navigation controls
            navigationControls

            Divider().background(Color.white.opacity(0.3))

            // Toggles
            togglesSection
        }
        .padding(12)
        .background(Color.black.opacity(0.9))
        .foregroundColor(.white)
        .cornerRadius(12)
        .frame(width: 240)
    }

    // MARK: - Step Info Section

    private var stepInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Step")
                    .font(.appCaption(weight: .bold))
                Spacer()
                Text("\(coordinator.currentStepIndex + 1) / \(coordinator.steps.count)")
                    .font(.caption.monospaced())
            }

            if let step = coordinator.currentStep {
                HStack {
                    Text("Type")
                        .font(.appCaption(weight: .bold))
                    Spacer()
                    Text(step.type.rawValue)
                        .font(.caption.monospaced())
                        .foregroundColor(.cyan)
                }

                HStack {
                    Text("Anchor")
                        .font(.appCaption(weight: .bold))
                    Spacer()
                    Text(anchorDescription(step.highlightAnchor))
                        .font(.caption.monospaced())
                        .foregroundColor(.yellow)
                }

                HStack {
                    Text("End")
                        .font(.appCaption(weight: .bold))
                    Spacer()
                    Text(endConditionDescription(step.endCondition))
                        .font(.caption.monospaced())
                        .foregroundColor(.green)
                        .lineLimit(1)
                }

                if let prerequisite = step.prerequisiteSetup {
                    HStack {
                        Text("Setup")
                            .font(.appCaption(weight: .bold))
                        Spacer()
                        Text(prerequisiteDescription(prerequisite))
                            .font(.caption.monospaced())
                            .foregroundColor(.orange)
                    }
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.appAccent)
                        .frame(width: geo.size.width * coordinator.progress, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Frame Info Section

    private var frameInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Highlight Frame")
                .font(.appCaption(weight: .bold))

            if let step = coordinator.currentStep,
               let frame = coordinator.getHighlightFrame(for: step.highlightAnchor) {
                HStack {
                    Text("Origin")
                    Spacer()
                    Text("(\(Int(frame.minX)), \(Int(frame.minY)))")
                        .font(.caption.monospaced())
                }
                .font(.appCaption())

                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(frame.width)) × \(Int(frame.height))")
                        .font(.caption.monospaced())
                }
                .font(.appCaption())
            } else {
                Text("No frame registered")
                    .font(.appCaption())
                    .foregroundColor(.orange)
            }

            // Registered frames count
            HStack {
                Text("Registered")
                Spacer()
                Text("\(coordinator.highlightFrames.count) frames")
                    .font(.caption.monospaced())
            }
            .font(.appCaption())
            .foregroundColor(.gray)
        }
    }

    // MARK: - Navigation Controls

    private var navigationControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    if coordinator.currentStepIndex > 0 {
                        withAnimation {
                            coordinator.currentStepIndex -= 1
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.appCaption())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                }
                .disabled(coordinator.isFirstStep)
                .opacity(coordinator.isFirstStep ? 0.5 : 1)

                Button {
                    coordinator.advance()
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.appCaption())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                }
                .disabled(coordinator.isLastStep)
                .opacity(coordinator.isLastStep ? 0.5 : 1)
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation {
                        coordinator.currentStepIndex = 0
                    }
                } label: {
                    Text("Reset")
                        .font(.appCaption())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(6)
                }

                Button {
                    coordinator.skipAll()
                } label: {
                    Text("Skip All")
                        .font(.appCaption())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Toggles Section

    private var togglesSection: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $coordinator.isActive) {
                Text("Show Overlay")
                    .font(.appCaption())
            }
            .toggleStyle(SwitchToggleStyle(tint: .appAccent))

            Toggle(isOn: $coordinator.showGestureHint) {
                Text("Gesture Hint")
                    .font(.appCaption())
            }
            .toggleStyle(SwitchToggleStyle(tint: .appAccent))
        }
    }

    // MARK: - Description Helpers

    private func anchorDescription(_ anchor: TutorialHighlightAnchor) -> String {
        switch anchor {
        case .button(let id):
            let shortId = id.rawValue.split(separator: ".").last ?? ""
            return "btn:\(shortId)"
        case .gridEntry(let offset):
            return "grid[\(offset)]"
        case .gesture(let type):
            switch type {
            case .pinchOut: return "pinch↔"
            case .pinchIn: return "pinch><"
            case .tapAndHold: return "tap+hold"
            case .swipe(let dir):
                switch dir {
                case .up: return "swipe↑"
                case .down: return "swipe↓"
                case .left: return "swipe←"
                case .right: return "swipe→"
                }
            }
        case .none:
            return "none"
        case .drawingCanvas:
          return "drawingCanvas"
        }
    }

    private func endConditionDescription(_ condition: TutorialEndCondition) -> String {
        switch condition {
        case .scrubEnded:
            return "scrubEnded"
        case .viewDismissed(let id):
            return "dismiss:\(id)"
        case .viewModeChanged(let mode):
            return "mode→\(mode == .now ? "now" : "year")"
        case .pinchGestureCompleted:
            return "pinchDone"
        case .yearChanged:
            return "yearChanged"
        case .sheetDismissed:
            return "sheetClosed"
        case .buttonTapped(id: let id):
          return "buttonTapped:\(id)"
        case .doubleTapCompleted:
          return "doubleTap"
        }
    }

    private func prerequisiteDescription(_ prerequisite: TutorialPrerequisite) -> String {
        switch prerequisite {
        case .ensureFutureYear:
            return "futureYear"
        case .populateAnniversaryEntry:
            return "addAnniv"
        case .openEntryEditingView:
            return "openEntry"
        case .clearSelectionAndScroll:
            return "clearSelection"
        case .navigateToToday:
            return "navToday"
        }
    }
}

// MARK: - Previews

#Preview("Debug Overlay - Collapsed") {
    let coordinator = TutorialCoordinator(
        steps: TutorialSteps.onboarding,
        singleStepMode: false,
        onComplete: {}
    )

    // Inject some mock frames
    coordinator.registerHighlightFrame(
        id: "gridEntry.0",
        frame: CGRect(x: 172, y: 320, width: 48, height: 48)
    )

    return ZStack {
        Color.backgroundColor.ignoresSafeArea()

        VStack {
            HStack {
                Spacer()
                TutorialDebugOverlay(coordinator: coordinator)
            }
            Spacer()
        }
    }
}

#Preview("Debug Overlay - Expanded") {
    struct ExpandedPreview: View {
        @StateObject private var coordinator = TutorialCoordinator(
            steps: TutorialSteps.onboarding,
            singleStepMode: false,
            onComplete: {}
        )

        var body: some View {
            ZStack {
                Color.backgroundColor.ignoresSafeArea()

                VStack {
                    HStack {
                        Spacer()
                        TutorialDebugOverlay(coordinator: coordinator)
                    }
                    Spacer()
                }
            }
            .onAppear {
                // Inject mock frames
                coordinator.registerHighlightFrame(
                    id: "gridEntry.0",
                    frame: CGRect(x: 172, y: 320, width: 48, height: 48)
                )
                coordinator.registerHighlightFrame(
                    id: TutorialButtonId.paintButton.rawValue,
                    frame: CGRect(x: 340, y: 520, width: 44, height: 44)
                )
            }
        }
    }

    return ExpandedPreview()
}

#Preview("Debug Overlay - Mid Tutorial") {
    let coordinator = TutorialCoordinator(
        steps: TutorialSteps.onboarding,
        startingIndex: 3,
        singleStepMode: false,
        onComplete: {}
    )

    coordinator.registerHighlightFrame(
        id: TutorialButtonId.yearSelector.rawValue,
        frame: CGRect(x: 60, y: 70, width: 80, height: 44)
    )

    return ZStack {
        Color.backgroundColor.ignoresSafeArea()

        VStack {
            HStack {
                Spacer()
                TutorialDebugOverlay(coordinator: coordinator)
            }
            Spacer()
        }
    }
}

#endif
