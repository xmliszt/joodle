//
//  HeaderButtonsView.swift
//  Joodle
//
//  Created by Li Yuxuan on 12/8/25.
//

import SwiftUI

struct HeaderButtonsView: View {
  // External bindings for integration with HeaderView
  let viewMode: ViewMode
  let onToggleViewMode: () -> Void
  let onSettingsAction: () -> Void
  @Namespace private var namespace

  private let spacing: CGFloat = 8

  var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer(spacing: spacing) {
        HStack(spacing: spacing) {
          // Settings Button (Left) - only visible when in year mode
          if viewMode == .year {
            Button(action: onSettingsAction) {
              Image(systemName: "gearshape")
            }
            .circularGlassButton()
            .glassEffectID("setting", in: namespace)
          }

          // Main Toggle Button (Right) - changes icon based on viewMode
          Button(action: onToggleViewMode) {
            Image(systemName: viewMode == .now ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
          }
          .circularGlassButton()
          .glassEffectID("view-mode", in: namespace)
        }
      }
      .animation(.springFkingSatifying, value: viewMode)
    } else {
      HStack(spacing: spacing) {
        // Settings Button (Left) - only visible when in year mode
        if viewMode == .year {
          Button(action: onSettingsAction) {
            Image(systemName: "gearshape")
          }
          .circularGlassButton()
          .transition(.opacity.combined(with: .scale).animation(.springFkingSatifying))
        }

        // Main Toggle Button (Right) - changes icon based on viewMode
        Button(action: onToggleViewMode) {
          Image(systemName: viewMode == .now ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        }
        .circularGlassButton()
      }
      .animation(.springFkingSatifying, value: viewMode)
    }

  }
}

#Preview {
  @Previewable @State var viewMode: ViewMode = .now

  VStack(spacing: 20) {
    HeaderButtonsView(
      viewMode: viewMode,
      onToggleViewMode: {
        viewMode = viewMode == .now ? .year : .now
      },
      onSettingsAction: {
        print("Settings tapped")
      }
    )

    Button("Toggle Mode") {
      viewMode = viewMode == .now ? .year : .now
    }
  }
  .padding()
}
