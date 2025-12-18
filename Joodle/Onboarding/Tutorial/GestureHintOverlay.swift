//
//  GestureHintOverlay.swift
//  Joodle
//
//  Animated gesture demonstration overlays for tutorial.
//

import SwiftUI

// MARK: - Gesture Hint Overlay

struct GestureHintOverlay: View {
    let gestureType: GestureHintType

    var body: some View {
        VStack(spacing: 24) {
            gestureAnimation

            Text(gestureDescription)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private var gestureAnimation: some View {
        switch gestureType {
        case .pinchOut:
            PinchGestureHint(direction: .out)
        case .pinchIn:
            PinchGestureHint(direction: .in)
        case .tapAndHold:
            TapAndHoldHint()
        case .swipe(let direction):
            SwipeHint(direction: direction)
        }
    }

    private var gestureDescription: String {
        switch gestureType {
        case .pinchOut:
            return "Pinch outward with two fingers"
        case .pinchIn:
            return "Pinch inward with two fingers"
        case .tapAndHold:
            return "Tap and hold"
        case .swipe(let direction):
            switch direction {
            case .up: return "Swipe up"
            case .down: return "Swipe down"
            case .left: return "Swipe left"
            case .right: return "Swipe right"
            }
        }
    }
}

// MARK: - Pinch Gesture Hint

struct PinchGestureHint: View {
    enum Direction { case `in`, out }

    let direction: Direction

    @State private var animationPhase: CGFloat = 0
    @State private var arrowOpacity: Double = 0.8

    private var startOffset: CGFloat { direction == .out ? 20 : 80 }
    private var endOffset: CGFloat { direction == .out ? 90 : 20 }

    private var currentOffset: CGFloat {
        startOffset + (endOffset - startOffset) * animationPhase
    }

    // For outward arrows - animate them moving outward too
    private var arrowOffset: CGFloat {
        direction == .out ? 20 + (40 * animationPhase) : 0
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left outward arrow (only for pinch out)
            if direction == .out {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white.opacity(arrowOpacity))
                    .offset(x: -arrowOffset)
                    .padding(.trailing, 8)
            }

            // Left finger
            FingerView(rotation: direction == .out ? 30 : -30)
                .offset(x: direction == .out ? -currentOffset / 2 : currentOffset / 2)

            // Right finger
            FingerView(rotation: direction == .out ? -30 : 30)
                .offset(x: direction == .out ? currentOffset / 2 : -currentOffset / 2)

            // Right outward arrow (only for pinch out)
            if direction == .out {
                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white.opacity(arrowOpacity))
                    .offset(x: arrowOffset)
                    .padding(.leading, 8)
            }
        }
        .onAppear {
            // Use a spring animation that feels more like expanding outward
            // Start at 0 and animate to 1 with a non-reversing loop for clearer outward feel
            animateOutward()
        }
    }

    private func animateOutward() {
        // Reset to start
        animationPhase = 0
        arrowOpacity = 0.8

        // Animate outward with spring for natural feel
        withAnimation(
            .spring(response: 0.8, dampingFraction: 0.6)
        ) {
            animationPhase = 1.0
        }

        // Fade out arrows at the end
        withAnimation(
            .easeOut(duration: 0.3)
            .delay(0.6)
        ) {
            arrowOpacity = 0.3
        }

        // Loop the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            animateOutward()
        }
    }
}

// MARK: - Tap and Hold Hint

struct TapAndHoldHint: View {
    @State private var scale: CGFloat = 1.0
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.6

    var body: some View {
        ZStack {
            // Expanding rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(ringScale + CGFloat(index) * 0.3)
                    .opacity(ringOpacity - Double(index) * 0.2)
            }

            // Hand icon
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
                .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                scale = 0.9
                ringScale = 1.5
                ringOpacity = 0.0
            }
        }
    }
}

// MARK: - Swipe Hint

struct SwipeHint: View {
    let direction: GestureHintType.SwipeDirection

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0

    private var baseOffset: CGFloat { -30 }
    private var targetOffset: CGFloat { 30 }

    var body: some View {
        ZStack {
            // Trail effect
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white.opacity(0.2))
                    .offset(swipeOffset(for: offset - CGFloat(index) * 10))
            }

            // Main hand
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
                .rotationEffect(handRotation)
                .offset(swipeOffset(for: offset))
                .opacity(opacity)
        }
        .onAppear {
            // Reset and animate
            offset = baseOffset
            opacity = 1.0

            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: false)
            ) {
                offset = targetOffset
            }

            // Fade out at end of swipe
            withAnimation(
                .easeIn(duration: 0.4)
                .delay(0.4)
                .repeatForever(autoreverses: false)
            ) {
                opacity = 0.3
            }
        }
    }

    private var handRotation: Angle {
        switch direction {
        case .up: return .degrees(0)
        case .down: return .degrees(180)
        case .left: return .degrees(-90)
        case .right: return .degrees(90)
        }
    }

    private func swipeOffset(for value: CGFloat) -> CGSize {
        switch direction {
        case .up: return CGSize(width: 0, height: -value)
        case .down: return CGSize(width: 0, height: value)
        case .left: return CGSize(width: -value, height: 0)
        case .right: return CGSize(width: value, height: 0)
        }
    }
}

// MARK: - Finger View

struct FingerView: View {
    let rotation: Double

    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 60, height: 60)
                .blur(radius: 10)

            // Finger icon
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 36))
                .foregroundColor(.white)
                .rotationEffect(.degrees(rotation))
        }
    }
}

// MARK: - Previews

#Preview("Pinch Out") {
    ZStack {
        Color.black.opacity(0.7).ignoresSafeArea()
        GestureHintOverlay(gestureType: .pinchOut)
    }
}

#Preview("Pinch In") {
    ZStack {
        Color.black.opacity(0.7).ignoresSafeArea()
        GestureHintOverlay(gestureType: .pinchIn)
    }
}

#Preview("Tap and Hold") {
    ZStack {
        Color.black.opacity(0.7).ignoresSafeArea()
        GestureHintOverlay(gestureType: .tapAndHold)
    }
}

#Preview("Swipe Up") {
    ZStack {
        Color.black.opacity(0.7).ignoresSafeArea()
        GestureHintOverlay(gestureType: .swipe(direction: .up))
    }
}

#Preview("Swipe Down") {
    ZStack {
        Color.black.opacity(0.7).ignoresSafeArea()
        GestureHintOverlay(gestureType: .swipe(direction: .down))
    }
}

#Preview("Swipe Left") {
    ZStack {
        Color.black.opacity(0.7).ignoresSafeArea()
        GestureHintOverlay(gestureType: .swipe(direction: .left))
    }
}

#Preview("Swipe Right") {
    ZStack {
        Color.black.opacity(0.7).ignoresSafeArea()
        GestureHintOverlay(gestureType: .swipe(direction: .right))
    }
}

#Preview("All Gestures") {
    ScrollView {
        VStack(spacing: 60) {
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
                        .frame(height: 200)

                    GestureHintOverlay(gestureType: gestureType)
                }
            }
        }
        .padding()
    }
}

// MARK: - Hashable Conformance for Preview

extension GestureHintType: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .pinchOut:
            hasher.combine("pinchOut")
        case .pinchIn:
            hasher.combine("pinchIn")
        case .tapAndHold:
            hasher.combine("tapAndHold")
        case .swipe(let direction):
            hasher.combine("swipe")
            hasher.combine(String(describing: direction))
        }
    }
}
