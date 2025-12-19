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
        VStack(spacing: 32) {
            gestureAnimation
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
}

// MARK: - Pinch Gesture Hint

struct PinchGestureHint: View {
    enum Direction { case `in`, out }

    let direction: Direction

    @State private var animationPhase: CGFloat = 0
    @State private var arrowOpacity: Double = 0.8

    private var startOffset: CGFloat { direction == .out ? 20 : 90 }
    private var endOffset: CGFloat { direction == .out ? 90 : 20 }

    private var currentOffset: CGFloat {
        startOffset + (endOffset - startOffset) * animationPhase
    }

    // For outward arrows - animate them moving outward too
    private var arrowOffset: CGFloat {
        direction == .out ? 16 + (16 * animationPhase) : -32 + (16 * animationPhase)
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
            } else if direction == .in {
              Image(systemName: "chevron.right")
                  .font(.system(size: 24, weight: .bold))
                  .foregroundColor(.white.opacity(arrowOpacity))
                  .offset(x: arrowOffset)
                  .padding(.trailing, 8)
            }

            // Left finger
            FingerView()
                .offset(x: -currentOffset / 2)

            // Right finger
            FingerView()
                .offset(x: currentOffset / 2)

            // Right outward arrow (only for pinch out)
            if direction == .out {
                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white.opacity(arrowOpacity))
                    .offset(x: arrowOffset)
                    .padding(.leading, 8)
            }  else if direction == .in {
              Image(systemName: "chevron.left")
                  .font(.system(size: 24, weight: .bold))
                  .foregroundColor(.white.opacity(arrowOpacity))
                  .offset(x: -arrowOffset)
                  .padding(.trailing, 8)
            }
        }
        .onAppear {
            // Use a spring animation that feels more like expanding outward
            // Start at 0 and animate to 1 with a non-reversing loop for clearer outward feel
          if direction == .out {
            animateOutward()
          } else if direction == .in {
            animateInward()
          }
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
            arrowOpacity = 0
        }

        // Loop the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            animateOutward()
        }
    }
  
  private func animateInward() {
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
          arrowOpacity = 0
      }

      // Loop the animation
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        animateInward()
      }
  }
}

// MARK: - Tap and Hold Hint

struct TapAndHoldHint: View {
    @State private var scale: CGFloat = 1.0
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.6
    @State private var isPressed: Bool = false

    var body: some View {
        ZStack {
            // Expanding rings (appear when "pressed")
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(ringScale + CGFloat(index) * 0.3)
                    .opacity(ringOpacity - Double(index) * 0.2)
            }

            // Finger pressing down icon
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
                .scaleEffect(scale)
                .offset(y: isPressed ? 5 : -10)
        }
        .onAppear {
            animateTapAndHold()
        }
    }

    private func animateTapAndHold() {
        // Reset state
        scale = 1.0
        ringScale = 1.0
        ringOpacity = 0.6
        isPressed = false

        // Animate finger pressing down
        withAnimation(.easeOut(duration: 0.3)) {
            isPressed = true
            scale = 0.9
        }

        // Animate rings expanding while held
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            ringScale = 1.8
            ringOpacity = 0.0
        }

        // Release and repeat
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeIn(duration: 0.2)) {
                isPressed = false
                scale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animateTapAndHold()
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

    /// Icon name based on swipe direction
    private var iconName: String {
        switch direction {
        case .up: return "hand.draw.fill"
        case .down: return "hand.draw.fill"
        case .left: return "hand.draw.fill"
        case .right: return "hand.draw.fill"
        }
    }

    var body: some View {
        ZStack {
            // Main hand
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.white)
                .rotationEffect(handRotation)
                .offset(swipeOffset(for: offset))
                .opacity(opacity)
        }
        .onAppear {
            animateSwipe()
        }
    }

    private func animateSwipe() {
        // Reset and animate
        offset = baseOffset
        opacity = 1.0

        withAnimation(
            .easeInOut(duration: 0.8)
        ) {
            offset = targetOffset
        }

        // Fade out at end of swipe
        withAnimation(
            .easeIn(duration: 0.3)
            .delay(0.5)
        ) {
            opacity = 0
        }

        // Loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            animateSwipe()
        }
    }

    private var handRotation: Angle {
        switch direction {
        case .up: return .degrees(-90)
        case .down: return .degrees(90)
        case .left: return .degrees(180)
        case .right: return .degrees(0)
        }
    }

    private var arrowIcon: String {
        switch direction {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }

    private var arrowOffset: CGSize {
        switch direction {
        case .up: return CGSize(width: 0, height: -60)
        case .down: return CGSize(width: 0, height: 60)
        case .left: return CGSize(width: -60, height: 0)
        case .right: return CGSize(width: 60, height: 0)
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
    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 60, height: 60)
                .blur(radius: 10)

            // Fingertip touch point
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
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
