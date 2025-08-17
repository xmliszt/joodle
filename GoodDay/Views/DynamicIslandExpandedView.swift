//
//  DynamicIslandExpandedView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 17/8/25.
//

import SwiftUI

struct DynamicIslandExpandedView<Content: View>: View {
    
    @Binding var isExpanded: Bool
    let content: Content
    let onDismiss: (() -> Void)?
    
    private let CONTAINER_MIN_HEIGHT: CGFloat = 200
    private let EDGE_PADDING: CGFloat = 10
    private let SHADOW_RADIUS: CGFloat = 16
    
    init(isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content, onDismiss: (() -> Void)? = nil) {
        self._isExpanded = isExpanded
        self.content = content()
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            // Backdrop that creates the blur effect when expanded
            if isExpanded {
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            
            // Invisible container
            // Optional to set background to make content below opaque
            VStack {
                // Visible content
                VStack {
                    // Safe Area on top so it doesn't get hidden by the island
                    Color.black
                        // Add 20 just to buffer to make sure things don't go behind dynamic island
                        // Apparently the size of the island is not the same on preview vs on actual phone 😡
                        .frame(maxWidth: .infinity, maxHeight: UIDevice.dynamicIslandSize.height + 20)
                    
                    // The content
                    content
                        .clipShape(RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius - EDGE_PADDING - 20))
                        .opacity(isExpanded ? 1 : 0)
                        .blur(radius: isExpanded ? 0 : 50)
                        .scaleEffect(isExpanded ? 1 : 0)
                        .animation(.springFkingSatifying, value: isExpanded)
                }
                .frame(
                    maxWidth: isExpanded ? .infinity : UIDevice.dynamicIslandSize.width,
                    minHeight: isExpanded ? CONTAINER_MIN_HEIGHT : UIDevice.dynamicIslandSize.height,
                    maxHeight: isExpanded ? nil : UIDevice.dynamicIslandSize.height,
                    alignment: .top)
                .padding(isExpanded ? 20 : 0)
                .clipped()
                // Black to blend into dynamic island cutout
                .background(.black)
                // Corner radius matches border of the device
                .cornerRadius(UIDevice.screenCornerRadius - EDGE_PADDING)
                // Subtle shadow to make it hovered
                .shadow(color: isExpanded ? .black.opacity(0.1) : .clear, radius: SHADOW_RADIUS, y: 10)
                // Animation: when collapse, no spring as that will not fully conceal it in the dynamic island area as it is bouncy
                .animation(isExpanded ? .springFkingSatifying : .easeOut, value: isExpanded)
                // Tap gesture to absorb tap in the visible container to prevent dismiss
                .onTapGesture {}
                
                // Spacer to push the actual visible content to the top
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(EDGE_PADDING)
            
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
        // Define hit zone
        .contentShape(Rectangle())
        // Only receive hit test when expanded
        .allowsHitTesting(isExpanded)
        .animation(.easeInOut, value: isExpanded)
        .onTapGesture {
            onDismiss?()
        }
        // Hide status bar when expanded
        .statusBarHidden(isExpanded)
    }
}

#Preview("Shrinked View") {
    @Previewable @State var isExpanded = false
    DynamicIslandExpandedView(
        isExpanded: $isExpanded,
        content: {
            Button("Tap me") {
                debugPrint("HELLO")
            }
        },
        onDismiss: {
            isExpanded = false
        }
    )
    Spacer()
    Button("Toggle") {
        isExpanded.toggle()
    }
}

#Preview("Expanded View") {
    @Previewable @State var isExpanded = true
    DynamicIslandExpandedView(
        isExpanded: $isExpanded,
        content: {
            ZStack {
                Color.blue
                Text("HELLO WORLD")
            }
            .frame(height: 300)
        }, onDismiss: {
            isExpanded = false
        })
    Spacer()
    Button("Toggle") {
        isExpanded.toggle()
    }
}
