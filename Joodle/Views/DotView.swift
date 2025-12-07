//
//  DotView.swift
//  Joodle
//
//  Created by Li Yuxuan on 11/8/25.
//

import SwiftUI

struct DotView: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: Params
    let size: CGFloat
    let highlighted: Bool
    let withEntry: Bool
    let dotStyle: DotStyle
    let scale: CGFloat

    // MARK: Computed dot color
    private var dotColor: Color {
        if highlighted { return .appSecondary }

        // Override base color if it is a present dot.
        if dotStyle == .present { return .appPrimary }
        if dotStyle == .future { return .textColor.opacity(0.15) }
        return .textColor
    }

    private var ringColor: Color {
        if highlighted { return .appSecondary }

        // Override base color if it is a present dot.
        if dotStyle == .present { return .appPrimary }
        if dotStyle == .future { return .textColor.opacity(0.15) }
        return .textColor
    }

    // MARK: view
    var body: some View {
        ZStack {
            // Base dot that maintains layout - fixed size container
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)

            // Visual dot that can scale without affecting layout
            if highlighted {
                if #available(iOS 26.0, *) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: size * scale, height: size * scale)
                        .glassEffect(.regular.tint(.appSecondary).interactive())
                        .animation(
                            .springFkingSatifying,
                            value: scale
                        )
                } else {
                    // Fallback on earlier versions
                    Circle()
                        .fill(dotColor)
                        .frame(width: size * scale, height: size * scale)
                        .animation(
                            .springFkingSatifying,
                            value: scale
                        )
                }
            } else {
                // Non-highlighted dot (no glass effect)
                Circle()
                    .fill(dotColor)
                    .frame(width: size * scale, height: size * scale)
                    .animation(
                        .springFkingSatifying,
                        value: scale
                    )
            }

            // Ring for entries - positioned absolutely
            if withEntry {
                Circle()
                    .stroke(ringColor, lineWidth: size * 0.15 * scale)
                    .frame(width: size * 1.5 * scale, height: size * 1.5 * scale)
                    .animation(
                        .springFkingSatifying,
                        value: scale
                    )
            }
        }
        // Use a fixed frame size to prevent layout changes
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack (spacing: 40) {
        DotView(
            size: 12,
            highlighted: false,
            withEntry: false,
            dotStyle: .past,
            scale: 1.0
        )
        DotView(
            size: 12,
            highlighted: false,
            withEntry: true,
            dotStyle: .past,
            scale: 1.0
        )
        DotView(
            size: 12,
            highlighted: false,
            withEntry: false,
            dotStyle: .present,
            scale: 1.0
        )
        DotView(
            size: 12,
            highlighted: false,
            withEntry: true,
            dotStyle: .present,
            scale: 1.0
        )
        DotView(
            size: 12,
            highlighted: true,
            withEntry: false,
            dotStyle: .present,
            scale: 2.0
        )
        DotView(
            size: 12,
            highlighted: true,
            withEntry: true,
            dotStyle: .present,
            scale: 2.0
        )
    }
}
