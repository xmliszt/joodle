//
//  TutorialTooltipView.swift
//  Joodle
//
//  Tooltip component for tutorial steps.
//

import SwiftUI

// MARK: - Tutorial Tooltip View

struct TutorialTooltipView: View {
    let tooltip: TutorialTooltip
    let highlightFrame: CGRect?
    let screenSize: CGSize

    @State private var tooltipSize: CGSize = .zero

    // MARK: - Computed Properties

    private var calculatedPosition: TooltipPosition {
        guard tooltip.position == .auto, let frame = highlightFrame else {
            return tooltip.position == .auto ? .below : tooltip.position
        }

        let spaceAbove = frame.minY
        let spaceBelow = screenSize.height - frame.maxY

        // Prefer below if there's more space, otherwise above
        return spaceBelow > spaceAbove + 50 ? .below : .above
    }

    private var tooltipY: CGFloat {
        guard let frame = highlightFrame else {
            // Center vertically if no highlight
            return screenSize.height / 2
        }

        let padding: CGFloat = 16

        switch calculatedPosition {
        case .above:
            return frame.minY - tooltipSize.height - padding
        case .below:
            return frame.maxY + padding
        case .leading:
            return frame.midY - tooltipSize.height / 2
        case .trailing:
            return frame.midY - tooltipSize.height / 2
        case .auto:
            return frame.maxY + padding
        }
    }

    private var tooltipX: CGFloat {
        guard let frame = highlightFrame else {
            // Center horizontally if no highlight
            return screenSize.width / 2
        }

        let padding: CGFloat = 16

        switch calculatedPosition {
        case .above, .below, .auto:
            // Center horizontally relative to highlight, but clamp to screen
            let idealX = frame.midX
            let minX = padding + tooltipSize.width / 2
            let maxX = screenSize.width - padding - tooltipSize.width / 2
            return max(minX, min(idealX, maxX))
        case .leading:
            return frame.minX - tooltipSize.width / 2 - padding
        case .trailing:
            return frame.maxX + tooltipSize.width / 2 + padding
        }
    }

    // Arrow pointing direction (opposite of tooltip position)
    private var arrowDirection: ArrowDirection {
        switch calculatedPosition {
        case .above: return .down
        case .below: return .up
        case .leading: return .right
        case .trailing: return .left
        case .auto: return .up
        }
    }

    // MARK: - Body

    var body: some View {
        TooltipBubble(
            message: tooltip.message,
            arrowDirection: arrowDirection,
            maxWidth: tooltip.maxWidth
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        tooltipSize = geo.size
                    }
                    .onChange(of: geo.size) { _, newSize in
                        tooltipSize = newSize
                    }
            }
        )
        .position(x: tooltipX, y: tooltipY + tooltipSize.height / 2)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: highlightFrame)
    }
}

// MARK: - Arrow Direction

enum ArrowDirection {
    case up, down, left, right
}

// MARK: - Tooltip Bubble

struct TooltipBubble: View {
    let message: String
    let arrowDirection: ArrowDirection
    let maxWidth: CGFloat

    private let cornerRadius: CGFloat = 16
    private let backgroundColor = Color.appAccent

    var body: some View {
        Text(message)
            .font(.appBody())
            .foregroundColor(.appAccentContrast)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: maxWidth)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Previews

#Preview("Tooltip - Below") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()

        // Mock highlight target
        Circle()
            .fill(Color.appAccent)
            .frame(width: 50, height: 50)
            .position(x: 196, y: 200)

        TutorialTooltipView(
            tooltip: TutorialTooltip(
                message: "Tap and hold on your Joodle, then drag to browse",
                position: .below
            ),
            highlightFrame: CGRect(x: 171, y: 175, width: 50, height: 50),
            screenSize: CGSize(width: 393, height: 852)
        )
    }
}

#Preview("Tooltip - Above") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()

        // Mock highlight target
        Circle()
            .fill(Color.appAccent)
            .frame(width: 50, height: 50)
            .position(x: 196, y: 600)

        TutorialTooltipView(
            tooltip: TutorialTooltip(
                message: "Tap to set an anniversary alarm for this future date",
                position: .above
            ),
            highlightFrame: CGRect(x: 171, y: 575, width: 50, height: 50),
            screenSize: CGSize(width: 393, height: 852)
        )
    }
}

#Preview("Tooltip - Auto (Near Top)") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()

        Circle()
            .fill(Color.appAccent)
            .frame(width: 50, height: 50)
            .position(x: 196, y: 100)

        TutorialTooltipView(
            tooltip: TutorialTooltip(
                message: "Auto-positioned tooltip (should appear below)",
                position: .auto
            ),
            highlightFrame: CGRect(x: 171, y: 75, width: 50, height: 50),
            screenSize: CGSize(width: 393, height: 852)
        )
    }
}

#Preview("Tooltip - Auto (Near Bottom)") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()

        Circle()
            .fill(Color.appAccent)
            .frame(width: 50, height: 50)
            .position(x: 196, y: 750)

        TutorialTooltipView(
            tooltip: TutorialTooltip(
                message: "Auto-positioned tooltip (should appear above)",
                position: .auto
            ),
            highlightFrame: CGRect(x: 171, y: 725, width: 50, height: 50),
            screenSize: CGSize(width: 393, height: 852)
        )
    }
}

#Preview("Tooltip - Centered (No Highlight)") {
    ZStack {
        Color.black.opacity(0.7).ignoresSafeArea()

        TutorialTooltipView(
            tooltip: TutorialTooltip(
                message: "Pinch outward to zoom back to normal view",
                position: .auto
            ),
            highlightFrame: nil,
            screenSize: CGSize(width: 393, height: 852)
        )
    }
}

#Preview("Tooltip - Edge Clamping") {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()

        // Target near left edge
        Circle()
            .fill(Color.appAccent)
            .frame(width: 44, height: 44)
            .position(x: 30, y: 400)

        TutorialTooltipView(
            tooltip: TutorialTooltip(
                message: "This tooltip should not go off the left edge of the screen",
                position: .below
            ),
            highlightFrame: CGRect(x: 8, y: 378, width: 44, height: 44),
            screenSize: CGSize(width: 393, height: 852)
        )
    }
}

#Preview("Tooltip Bubble") {
    VStack(spacing: 40) {
        TooltipBubble(message: "Simple tooltip bubble", arrowDirection: .up, maxWidth: 200)
        TooltipBubble(message: "Another tooltip message", arrowDirection: .down, maxWidth: 250)
    }
    .padding()
}
