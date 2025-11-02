//
//  DrawingDisplayView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

struct DrawingDisplayView: View {
    let entry: DayEntry?
    let displaySize: CGFloat
    let dotStyle: DotStyle
    let accent: Bool
    let highlighted: Bool
    
    @State private var pathsWithMetadata: [PathWithMetadata] = []
    @State private var isVisible = false
    
    // Use shared cache for drawing paths
    private let pathCache = DrawingPathCache.shared
    
    private var foregroundColor: Color {
        if highlighted { return .appSecondary }
        if accent { return .appPrimary }
        
        // Override base color if it is a present dot.
        if dotStyle == .present { return .appPrimary }
        if dotStyle == .future { return .textColor.opacity(0.15) }
        return .textColor
    }
    
    var body: some View {
        Canvas { context, size in
            // Render at original canvas size (300x300) without scaling the paths
            for pathWithMetadata in pathsWithMetadata {
                let path = pathWithMetadata.path
                
                // Render based on original intent stored in metadata
                if pathWithMetadata.metadata.isDot {
                    context.fill(path, with: .color(foregroundColor))
                } else {
                    context.stroke(
                        path,
                        with: .color(foregroundColor),
                        style: StrokeStyle(
                            lineWidth: DRAWING_LINE_WIDTH * (displaySize <= 20 ? 2 : 1),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
        }
        .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
        .scaleEffect(displaySize / CANVAS_SIZE, anchor: .center)
        .frame(width: displaySize, height: displaySize)
        .clipped()
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .blur(radius: isVisible ? 0 : 5)
        .animation(.springFkingSatifying, value: isVisible)
        .onAppear {
            // Load data immediately and animate
            loadDrawingData()
            withAnimation(.springFkingSatifying) {
                isVisible = true
            }
        }
        .onChange(of: entry?.drawingData) { _, _ in
            // Load new data and animate immediately
            loadDrawingData()
            withAnimation(.springFkingSatifying) {
                isVisible = true
            }
        }
    }
    
    private func loadDrawingData() {
        guard let drawingData = entry?.drawingData else {
            pathsWithMetadata = []
            return
        }
        
        // Use cached paths with metadata to avoid repeated JSON decoding
        pathsWithMetadata = pathCache.getPathsWithMetadata(for: drawingData)
    }
}

#Preview {
    DrawingDisplayView(entry: nil, displaySize: 200, dotStyle: .present, accent: true, highlighted: true)
        .frame(width: 200, height: 200)
        .background(.gray.opacity(0.1))
}
