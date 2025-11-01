//
//  DotView.swift
//  GoodDay
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
            Circle()
                .fill(dotColor)
                .frame(width: size, height: size)
                .animation(
                    .springFkingSatifying,
                    value: highlighted
                )
            
            // Ring for entries - positioned absolutely
            if withEntry {
                Circle()
                    .stroke(ringColor, lineWidth: size * 0.15)
                    .frame(width: size * 1.5, height: size * 1.5)
                    .animation(
                        .springFkingSatifying,
                        value: highlighted
                    )
            }
        }
        // Use a fixed frame size to prevent layout changes
        .frame(width: size, height: size)
    }
}

#Preview {
    DotView(
        size: 12,
        highlighted: false,
        withEntry: false,
        dotStyle: .past
    )
    DotView(
        size: 12,
        highlighted: false,
        withEntry: true,
        dotStyle: .past
    )
    DotView(
        size: 12,
        highlighted: false,
        withEntry: false,
        dotStyle: .present
    )
    DotView(
        size: 12,
        highlighted: false,
        withEntry: true,
        dotStyle: .present
    )
    DotView(
        size: 12,
        highlighted: true,
        withEntry: false,
        dotStyle: .present
    )
    DotView(
        size: 12,
        highlighted: true,
        withEntry: true,
        dotStyle: .present
    )
}
