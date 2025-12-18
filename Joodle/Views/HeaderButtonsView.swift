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
  let currentYear: Int
  let onToggleViewMode: () -> Void
  let onSettingsAction: () -> Void

  /// When true, adds tutorial highlight anchors to interactive elements
  var tutorialMode: Bool = false

  @Namespace private var namespace

  @State private var showingShareSheet = false

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

            // Share Button - only visible when in year mode
            Button(action: { showingShareSheet = true }) {
              Image(systemName: "square.and.arrow.up")
            }
            .circularGlassButton()
            .glassEffectID("share", in: namespace)
          }

          // Main Toggle Button (Right) - changes icon based on viewMode
          Button(action: onToggleViewMode) {
            Image(systemName: viewMode == .now ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
          }
          .circularGlassButton()
          .glassEffectID("view-mode", in: namespace)
          .applyIf(tutorialMode) { view in
            view.tutorialHighlightAnchor(.viewModeButton)
          }
        }
      }
      .animation(.springFkingSatifying, value: viewMode)
      .sheet(isPresented: $showingShareSheet) {
        ShareCardSelectorView(year: currentYear)
      }
    } else {
      HStack(spacing: spacing) {
        // Settings Button (Left) - only visible when in year mode
        if viewMode == .year {
          Button(action: onSettingsAction) {
            Image(systemName: "gearshape")
          }
          .circularGlassButton()
          .transition(.opacity.combined(with: .scale).animation(.springFkingSatifying))

          // Share Button - only visible when in year mode
          Button(action: { showingShareSheet = true }) {
            Image(systemName: "square.and.arrow.up")
          }
          .circularGlassButton()
          .transition(.opacity.combined(with: .scale).animation(.springFkingSatifying))
        }

        // Main Toggle Button (Right) - changes icon based on viewMode
        Button(action: onToggleViewMode) {
          Image(systemName: viewMode == .now ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        }
        .circularGlassButton()
        .applyIf(tutorialMode) { view in
          view.tutorialHighlightAnchor(.viewModeButton)
        }
      }
      .animation(.springFkingSatifying, value: viewMode)
      .sheet(isPresented: $showingShareSheet) {
        ShareCardSelectorView(year: currentYear)
      }
    }

  }
}

#Preview {
  @Previewable @State var viewMode: ViewMode = .now

  VStack(spacing: 20) {
    HeaderButtonsView(
      viewMode: viewMode,
      currentYear: 2025,
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

#Preview("Tutorial Mode") {
  @Previewable @State var viewMode: ViewMode = .now

  VStack(spacing: 20) {
    HeaderButtonsView(
      viewMode: viewMode,
      currentYear: 2025,
      onToggleViewMode: {
        viewMode = viewMode == .now ? .year : .now
      },
      onSettingsAction: {
        print("Settings tapped")
      },
      tutorialMode: true
    )

    Button("Toggle Mode") {
      viewMode = viewMode == .now ? .year : .now
    }
  }
  .padding()
}
