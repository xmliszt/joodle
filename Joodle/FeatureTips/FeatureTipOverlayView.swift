//
//  FeatureTipOverlayView.swift
//  Joodle
//
//  Floating, hit-test-transparent overlay that renders the active feature tip:
//  a small bubble with a directional beak pointing at the target control. It
//  never blocks input (`.allowsHitTesting(false)`) — the user keeps full
//  control of the underlying UI. Positioning is derived from the anchor frame
//  published by `FeatureTipManager`.
//

import SwiftUI

struct FeatureTipOverlayView: View {
    @ObservedObject private var manager = FeatureTipManager.shared

    var body: some View {
        GeometryReader { geo in
            if let tip = manager.activeTip, let frame = manager.activeFrame {
                FeatureTipBubble(
                    message: tip.message,
                    targetFrame: frame,
                    screenSize: geo.size
                )
                .id(tip.id)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: manager.activeTip?.id)
    }
}

// MARK: - Bubble

private struct FeatureTipBubble: View {
    let message: LocalizedStringResource
    let targetFrame: CGRect
    let screenSize: CGSize

    @State private var bubbleSize: CGSize = .zero

    private let maxWidth: CGFloat = 240
    private let gap: CGFloat = 10          // distance between target edge and beak tip
    private let edgePadding: CGFloat = 16  // keep bubble this far from screen edges
    private let beakWidth: CGFloat = 18
    private let beakHeight: CGFloat = 9

    /// Place below the target when there's more room below; otherwise above.
    private var placeBelow: Bool {
        let spaceAbove = targetFrame.minY
        let spaceBelow = screenSize.height - targetFrame.maxY
        return spaceBelow >= spaceAbove
    }

    /// Horizontal center of the bubble, clamped to stay on screen.
    private var bubbleCenterX: CGFloat {
        let half = bubbleSize.width / 2
        let minX = edgePadding + half
        let maxX = screenSize.width - edgePadding - half
        guard minX <= maxX else { return screenSize.width / 2 }
        return min(max(targetFrame.midX, minX), maxX)
    }

    /// Vertical center of the whole bubble+beak stack.
    private var bubbleCenterY: CGFloat {
        let totalHeight = bubbleSize.height + beakHeight
        if placeBelow {
            return targetFrame.maxY + gap + totalHeight / 2
        } else {
            return targetFrame.minY - gap - totalHeight / 2
        }
    }

    /// Beak horizontal offset from the bubble center so it keeps pointing at the
    /// target even when the bubble is clamped to a screen edge.
    private var beakOffsetX: CGFloat {
        let raw = targetFrame.midX - bubbleCenterX
        let limit = max(0, bubbleSize.width / 2 - beakWidth)
        return min(max(raw, -limit), limit)
    }

    var body: some View {
        VStack(spacing: 0) {
            if placeBelow {
                beak(pointingUp: true)
            }

            Text(message)
                .font(.appBody())
                .foregroundColor(.appAccentContrast)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: maxWidth)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appAccent)
                )

            if !placeBelow {
                beak(pointingUp: false)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { bubbleSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in bubbleSize = newSize }
            }
        )
        .position(x: bubbleCenterX, y: bubbleCenterY)
    }

    private func beak(pointingUp: Bool) -> some View {
        BeakTriangle()
            .fill(Color.appAccent)
            .frame(width: beakWidth, height: beakHeight)
            .rotationEffect(.degrees(pointingUp ? 0 : 180))
            .offset(x: beakOffsetX)
    }
}

// MARK: - Beak Shape

/// Upward-pointing triangle; rotated 180° for downward beaks. Adapted from the
/// referenced tooltip gist.
private struct BeakTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))   // tip
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // bottom-right
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // bottom-left
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("Feature Tip - Below target") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()
        Circle()
            .fill(Color.appAccent)
            .frame(width: 44, height: 44)
            .position(x: 340, y: 120)

        FeatureTipBubble(
            message: "Try to use a photo as doodle reference",
            targetFrame: CGRect(x: 318, y: 98, width: 44, height: 44),
            screenSize: CGSize(width: 393, height: 852)
        )
    }
}

#Preview("Feature Tip - Above target") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()
        Circle()
            .fill(Color.appAccent)
            .frame(width: 44, height: 44)
            .position(x: 60, y: 760)

        FeatureTipBubble(
            message: "Try to use a photo as doodle reference",
            targetFrame: CGRect(x: 38, y: 738, width: 44, height: 44),
            screenSize: CGSize(width: 393, height: 852)
        )
    }
}
