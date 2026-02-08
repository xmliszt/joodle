//
//  TutorialOverlayView.swift
//  Joodle
//
//  Dimmed overlay with highlight cutout and tooltip for tutorial steps.
//

import SwiftUI

// MARK: - Tutorial Overlay View

struct TutorialOverlayView: View {
    @ObservedObject var coordinator: TutorialCoordinator

    private let dimOpacity: Double = 0.5
    private let highlightPadding: CGFloat = 8
    private let highlightCornerRadius: CGFloat = 32

    /// Whether the current step is the scrubbing step (needs pass-through for grid interaction)
    private var isScrubbingStep: Bool {
        coordinator.currentStep?.type == .scrubbing
    }

    var body: some View {
        ZStack {
            overlayContent

            // Tutorial completion overlay
            if coordinator.showingCompletion {
                TutorialCompletionView(isOnboarding: !coordinator.singleStepMode)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        GeometryReader { geometry in
            ZStack {
                if let step = coordinator.currentStep {
                    switch step.highlightAnchor {
                    case .button, .gridEntry, .drawingCanvas:
                        // Dimmed overlay with cutout for highlighted element
                        if let frame = coordinator.getHighlightFrame(for: step.highlightAnchor) {
                            let paddedFrame = frame.insetBy(
                                dx: -highlightPadding,
                                dy: -highlightPadding
                            )

                            // When user is actively scrubbing, hide the overlay entirely
                            // so they can freely browse the grid
                            if isScrubbingStep && coordinator.isUserScrubbing {
                                // No overlay - let user scrub freely
                                Color.clear
                                    .allowsHitTesting(false)
                            } else {
                                // Dimmed background with cutout
                                DimmedOverlayWithCutout(
                                    cutoutFrame: paddedFrame,
                                    cornerRadius: highlightCornerRadius,
                                    dimOpacity: dimOpacity
                                )
                                // For scrubbing step, allow all gestures to pass through to the grid
                                // For other steps, block gestures outside the cutout
                                .allowsHitTesting(!isScrubbingStep)
                                .contentShape(
                                    InvertedRoundedRectangle(
                                        cutoutFrame: paddedFrame,
                                        cornerRadius: highlightCornerRadius
                                    ),
                                    eoFill: true
                                )

                                // Pulsing highlight ring
                                HighlightRing(frame: paddedFrame, cornerRadius: highlightCornerRadius)

                                // Tooltip
                                TutorialTooltipView(
                                    tooltip: step.tooltip,
                                    highlightFrame: frame,
                                    screenSize: geometry.size
                                )
                            }
                        } else {
                            // Frame not yet available - show loading state
                            // But if scrubbing, don't show anything
                            if !(isScrubbingStep && coordinator.isUserScrubbing) {
                                Color.black.opacity(dimOpacity * 0.5)
                                    .allowsHitTesting(false)
                            }
                        }

                    case .gesture(let gestureType):
                        // Dimmed background for gesture hint visibility
                      ZStack {
                        Color.black.opacity(dimOpacity)
                              .allowsHitTesting(false)

                        
                        // Gesture hint animation
                        GestureHintOverlay(gestureType: gestureType)
                          .offset(y: -112)

                      
                        // Centered tooltip
                        TutorialTooltipView(
                            tooltip: step.tooltip,
                            highlightFrame: nil,
                            screenSize: geometry.size
                        )
                        .offset(y: -64)
                      }
                      

                    case .none:
                        // Just dimmed overlay with tooltip
                        Color.black.opacity(dimOpacity)
                            .allowsHitTesting(false)

                        TutorialTooltipView(
                            tooltip: step.tooltip,
                            highlightFrame: nil,
                            screenSize: geometry.size
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentStepIndex)
        .animation(.easeInOut(duration: 0.2), value: coordinator.isUserScrubbing)
        .opacity(coordinator.isActive ? 1 : 0)
    }
}

// MARK: - Tutorial Completion View

struct TutorialCompletionView: View {
    let isOnboarding: Bool

    @State private var checkmarkScale: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0

    init(isOnboarding: Bool = true) {
        self.isOnboarding = isOnboarding
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated checkmark with ring
                ZStack {
                    // Expanding rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.appAccent.opacity(0.3), lineWidth: 2)
                            .frame(width: 100, height: 100)
                            .scaleEffect(ringScale + CGFloat(index) * 0.2)
                            .opacity(ringOpacity - Double(index) * 0.1)
                    }

                    // Success circle background
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 100, height: 100)
                        .scaleEffect(checkmarkScale)

                    // Checkmark icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.appFont(size: 60, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(checkmarkScale)
                }

                // Completion text
                VStack(spacing: 8) {
                    Text("Tutorial Complete!")
                        .font(.appTitle2(weight: .bold))
                        .foregroundColor(.white)

                    // Only show "ready to start" message during onboarding
                    if isOnboarding {
                        Text("You're ready to start Joodling")
                            .font(.appSubheadline())
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            // Animate checkmark appearing
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
            }

            // Animate ring expansion
            withAnimation(.easeOut(duration: 1.0)) {
                ringScale = 1.5
                ringOpacity = 0.8
            }

            // Fade in text slightly after
            withAnimation(.easeIn(duration: 0.4).delay(0.3)) {
                textOpacity = 1.0
            }

            // Fade out rings
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                ringOpacity = 0
            }
        }
    }
}

// MARK: - Dimmed Overlay with Cutout

struct DimmedOverlayWithCutout: View {
    let cutoutFrame: CGRect
    let cornerRadius: CGFloat
    let dimOpacity: Double

    var body: some View {
        Canvas { context, size in
            // Draw the full dimmed rectangle
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(dimOpacity))
            )

            // Cut out the highlight area using clear blend mode
            context.blendMode = .clear
            context.fill(
                Path(
                    roundedRect: cutoutFrame,
                    cornerRadius: cornerRadius
                ),
                with: .color(.white)
            )
        }
    }
}

// MARK: - Inverted Rounded Rectangle (for hit testing)

struct InvertedRoundedRectangle: Shape {
    let cutoutFrame: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: cutoutFrame,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return path
    }
}

// MARK: - Highlight Ring

struct HighlightRing: View {
    let frame: CGRect
    let cornerRadius: CGFloat

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulsing ring
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.appAccent.opacity(0.5), lineWidth: 3)
                .frame(width: frame.width, height: frame.height)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.8)

            // Inner steady ring
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .stroke(Color.appAccent, lineWidth: 2)
                .frame(width: frame.width - 4, height: frame.height - 4)
        }
        .position(x: frame.midX, y: frame.midY)
        .onAppear {
            withAnimation(
                .easeOut(duration: 1.2)
                .repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Overlay - Button Cutout") {
    let coordinator = TutorialCoordinator(
        steps: [
            TutorialStepConfig(
                type: .drawAndEdit,
                highlightAnchor: .button(id: .paintButton),
                tooltip: TutorialTooltip(
                    message: "Tap here to edit your Joodle",
                    position: .above
                ),
                endCondition: .viewDismissed(viewId: "drawingCanvas")
            )
        ],
        singleStepMode: true,
        onComplete: {}
    )

    // Inject mock frame
    coordinator.registerHighlightFrame(
        id: TutorialButtonId.paintButton.rawValue,
        frame: CGRect(x: 320, y: 500, width: 44, height: 44)
    )

    return ZStack {
        // Mock app background
        Color.backgroundColor.ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 44, height: 44)
                    .padding(.trailing, 29)
                    .padding(.bottom, 308)
            }
        }

        TutorialOverlayView(coordinator: coordinator)
    }
}

#Preview("Overlay - Grid Entry Cutout") {
    let coordinator = TutorialCoordinator(
        steps: [
            TutorialStepConfig(
                type: .scrubbing,
                highlightAnchor: .gridEntry(dateOffset: 0),
                tooltip: TutorialTooltip(
                    message: "Tap and hold on your Joodle, then drag to browse",
                    position: .below
                ),
                endCondition: .scrubEnded
            )
        ],
        singleStepMode: true,
        onComplete: {}
    )

    coordinator.registerHighlightFrame(
        id: "gridEntry.0",
        frame: CGRect(x: 172, y: 320, width: 48, height: 48)
    )

    return ZStack {
        Color.backgroundColor.ignoresSafeArea()

        // Mock grid
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: 7),
            spacing: 8
        ) {
            ForEach(0..<35, id: \.self) { index in
                Circle()
                    .fill(index == 17 ? Color.appAccent : Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.top, 100)

        TutorialOverlayView(coordinator: coordinator)
    }
}

#Preview("Overlay - Gesture Hint") {
    let coordinator = TutorialCoordinator(
        steps: [
            TutorialStepConfig(
                type: .switchViewMode,
                highlightAnchor: .gesture(type: .pinchOut),
                tooltip: TutorialTooltip(
                    message: "Pinch outward to zoom back to normal view",
                    position: .auto
                ),
                endCondition: .pinchGestureCompleted
            )
        ],
        singleStepMode: true,
        onComplete: {}
    )

    return ZStack {
        Color.backgroundColor.ignoresSafeArea()

        // Mock minimized grid
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(8), spacing: 4), count: 20),
            spacing: 4
        ) {
            ForEach(0..<200, id: \.self) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding()

        TutorialOverlayView(coordinator: coordinator)
    }
}

#Preview("Overlay - Inactive") {
    let coordinator = TutorialCoordinator(
        steps: TutorialSteps.onboarding,
        singleStepMode: false,
        onComplete: {}
    )
    coordinator.isActive = false

    return ZStack {
        Color.backgroundColor.ignoresSafeArea()
        Text("Overlay should be hidden")
        TutorialOverlayView(coordinator: coordinator)
    }
}

#Preview("Highlight Ring") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()

        HighlightRing(
            frame: CGRect(x: 147, y: 376, width: 100, height: 100),
            cornerRadius: 16
        )
    }
}
