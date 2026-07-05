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
    let isAvailableForMove: Bool
    /// The dot's month (1-12), used to pick its color under the rainbow theme.
    /// `nil` falls back to the current month.
    let month: Int?

    init(size: CGFloat, highlighted: Bool, withEntry: Bool, dotStyle: DotStyle, scale: CGFloat, isAvailableForMove: Bool = false, month: Int? = nil) {
        self.size = size
        self.highlighted = highlighted
        self.withEntry = withEntry
        self.dotStyle = dotStyle
        self.scale = scale
        self.isAvailableForMove = isAvailableForMove
        self.month = month
    }

    // MARK: Computed dot color

    /// The month's rainbow color under the rainbow theme, otherwise the single
    /// accent color — matching how doodles resolve their color (see
    /// `DrawingDisplayView.foregroundColor`).
    private var accentColor: Color { Color.appDrawingColor(forMonth: month) }

    /// Base color for past/future dots: monochrome under solid themes, but the
    /// rainbow theme tints each day by its month so the months read apart even
    /// when a day is empty or holds only a note. Future dots keep their faded
    /// opacity — a faint month tint rather than a faint gray.
    private var baseColor: Color {
        UserPreferences.shared.accentColor.isRainbow ? accentColor : .textColor
    }

    private var dotColor: Color {
        if isAvailableForMove { return .appAccent.opacity(0.8) }
        if highlighted { return .appSecondary }

        if dotStyle == .present { return accentColor }
        if dotStyle == .future { return baseColor.opacity(0.15) }
        return baseColor
    }

    private var ringColor: Color {
        if highlighted { return .appSecondary }

        if dotStyle == .present { return accentColor }
        if dotStyle == .future { return baseColor.opacity(0.15) }
        return baseColor
    }
  
    private var computedSize: CGFloat {
        if withEntry { return size * 2 }
        return size
    }

    // MARK: view
    var body: some View {
        ZStack {
            // Base dot that maintains layout - fixed size container
            Circle()
                .fill(Color.clear)
                .frame(width: computedSize, height: computedSize)

            // Visual dot that can scale without affecting layout
            if highlighted {
                if #available(iOS 26.0, *) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: computedSize * scale, height: computedSize * scale)
                        .glassEffect(.regular.tint(.appSecondary).interactive())
                        .animation(
                            .springFkingSatifying,
                            value: scale
                        )
                } else {
                    // Fallback on earlier versions
                    Circle()
                        .fill(dotColor)
                        .frame(width: computedSize * scale, height: computedSize * scale)
                        .animation(
                            .springFkingSatifying,
                            value: scale
                        )
                }
            } else {
                // Non-highlighted dot (no glass effect)
                Circle()
                    .fill(dotColor)
                    .frame(width: computedSize * scale, height: computedSize * scale)
                    .animation(
                        .springFkingSatifying,
                        value: scale
                    )
            }

            // Ring for entries - positioned absolutely
            if withEntry {
                Circle()
                    .stroke(ringColor, lineWidth: size * 0.15 * scale)
                    .frame(width: computedSize * 1.5 * scale, height: computedSize * 1.5 * scale)
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
