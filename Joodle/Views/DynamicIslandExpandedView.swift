//
//  DynamicIslandExpandedView.swift
//  Joodle
//
//  Created by Li Yuxuan on 17/8/25.
//

import SwiftUI

struct DynamicIslandExpandedView<Content: View>: View {

  @Environment(\.colorScheme) private var colorScheme
  @Binding var isExpanded: Bool
  let content: Content
  let hidden: Bool
  let onDismiss: (() -> Void)?
  /// When non-nil, the visible rounded container registers itself as a
  /// tutorial highlight anchor under this ID, with its own concentric corner
  /// radius. Lets the tutorial overlay cutout hug the floating container
  /// exactly rather than the parent view's full-screen frame.
  let tutorialAnchorID: String?
  /// Whether tapping the backdrop outside the visible container fires
  /// `onDismiss`. Defaults to `true` (the daily "tap outside to save & close"
  /// affordance). The interactive tutorial disables it because dismissal is
  /// driven explicitly per step — an accidental backdrop tap there would close
  /// the canvas out of band and wedge the tutorial flow.
  let dismissOnTapOutside: Bool

  private let SHADOW_RADIUS: CGFloat = 16

  init(
    isExpanded: Binding<Bool>,
    @ViewBuilder content: () -> Content,
    hidden: Bool = false,
    onDismiss: (() -> Void)? = nil,
    tutorialAnchorID: String? = nil,
    dismissOnTapOutside: Bool = true
  ) {
    self._isExpanded = isExpanded
    self.content = content()
    self.hidden = hidden
    self.onDismiss = onDismiss
    self.tutorialAnchorID = tutorialAnchorID
    self.dismissOnTapOutside = dismissOnTapOutside
  }

  // MARK: - Layout adaptation
  //
  // On Dynamic Island devices the floating container hides behind the DI
  // cutout when collapsed. On notch / non-cutout devices there's no pill to
  // hide behind, so the container starts just below the top safe area and
  // collapses to zero size when hidden.

  /// Symmetric inset used as the horizontal padding between the container and
  /// the device's screen edges. Picked to keep the container corner radius
  /// concentric with the device's screen corners.
  private var containerHorizontalInset: CGFloat {
    if UIDevice.hasDynamicIsland {
      return UIDevice.dynamicIslandFrame.origin.y
    } else {
      return 10
    }
  }

  /// Y offset where the top edge of the floating container starts.
  private var containerTopOffset: CGFloat {
    if UIDevice.hasDynamicIsland {
      return UIDevice.dynamicIslandFrame.origin.y
    } else {
      // Land just below the notch / status bar area.
      return UIDevice.topSafeAreaInset
    }
  }

  /// Height reserved at the top of the container so the content doesn't draw
  /// under the DI cutout. Zero on non-DI devices since the container starts
  /// below the notch.
  private var topContentInset: CGFloat {
    UIDevice.hasDynamicIsland ? UIDevice.dynamicIslandSize.height : 0
  }

  /// Size of the collapsed container. On DI devices this matches the DI
  /// capsule so it tucks behind the cutout. On non-DI devices we collapse
  /// to zero — there's no cutout to align with.
  private var collapsedSize: CGSize {
    UIDevice.hasDynamicIsland ? UIDevice.dynamicIslandSize : .zero
  }

  /// Outer container corner radius, concentric with the device screen.
  private var containerCornerRadius: CGFloat {
    max(UIDevice.screenCornerRadius - containerHorizontalInset, 0)
  }

  /// Content clip corner radius — accounts for the 8pt inner padding.
  private var contentCornerRadius: CGFloat {
    max(containerCornerRadius - 8, 0)
  }

  private var expandedContentWidth: CGFloat {
    UIScreen.main.bounds.width - (containerHorizontalInset * 2)
  }

  private var containerShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
  }

  /// Container backdrop: clear Liquid Glass that refracts the blurred
  /// backdrop behind the container, under a black gradient that stays solid
  /// at the top (so it still blends into the DI cutout) and fades out toward
  /// the bottom so the glass edge shows through. While collapsed — and on
  /// pre-iOS 26 — the container stays flat black so it conceals inside the
  /// island cutout.
  private var containerBackground: some View {
    ZStack {
      if #available(iOS 26.0, *) {
        Color.clear
          .glassEffect(.clear, in: containerShape)
      } else {
        Color.black
      }

      LinearGradient(
        stops: [
          .init(color: .black, location: 0),
          .init(color: .black, location: 0.45),
          .init(color: .black.opacity(0), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
      )

      // Solid cover while collapsed; fades out with the expand spring so the
      // glass bottom is only revealed once the container leaves the cutout.
      Color.black.opacity(isExpanded ? 0 : 1)
    }
  }

  var body: some View {
    ZStack {
      // Backdrop when expanded: a subtle dim instead of a blur material — the
      // container's clear Liquid Glass refracts what's behind it, and blurring
      // the backdrop would wash out that lensing. Keeping the content sharp
      // (just darkened for focus) lets the glass edge distortion read clearly.
      if isExpanded {
        Rectangle().fill(Color.black.opacity(0.15))
      }

      // Invisible container
      // Optional to set background to make content below opaque
      VStack {
        // Visible content
        VStack(spacing: 0) {
          // Top reserved space so content doesn't draw under the DI cutout.
          if topContentInset > 0 {
            Spacer()
              .frame(maxWidth: .infinity, maxHeight: topContentInset)
          }

          // The content
          content
            .frame(width: expandedContentWidth)
            .clipShape(RoundedRectangle(cornerRadius: contentCornerRadius, style: .continuous))
            .opacity(isExpanded ? 1 : 0)
            .scaleEffect(isExpanded ? 1 : 0)
            .animation(.springFkingSatifying, value: isExpanded)
        }
        .frame(
          width: isExpanded ? expandedContentWidth : collapsedSize.width,
          height: isExpanded ? nil : collapsedSize.height,
          alignment: .top)
        // Black at the top to blend into the dynamic island cutout, fading
        // into clear refractive glass toward the bottom when expanded.
        .background(containerBackground)
        // Corner radius matches border of the device
        .clipShape(containerShape)
        .tutorialHighlightAnchor(
          tutorialAnchorID ?? "",
          isEnabled: tutorialAnchorID != nil,
          cornerRadius: containerCornerRadius
        )
        // Subtle shadow to make it hovered
        .shadow(color: isExpanded ? .black.opacity(0.1) : .clear, radius: SHADOW_RADIUS, y: 10)
        // Animation: when collapse, no spring as that will not fully conceal it in the dynamic island area as it is bouncy
        .animation(.springFkingSatifying, value: isExpanded)
        // Tap gesture to absorb tap in the visible container to prevent dismiss
        .onTapGesture {}

        // Spacer to push the actual visible content to the top
        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // Move it so that it is at the position of dynamic island / below the notch
      .offset(y: containerTopOffset)
    }
    .ignoresSafeArea(.all, edges: .vertical)
    // Define hit zone
    .contentShape(RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius))
    // Only receive hit test when expanded. This must stay enabled even when
    // backdrop-tap dismiss is off: the container still needs to absorb taps in
    // the backdrop region (so they don't fall through to the view behind) and
    // to keep its own content — the canvas and its buttons — interactive.
    .allowsHitTesting(isExpanded)
    .animation(.springFkingSatifying, value: isExpanded)
    .onTapGesture {
      // The tutorial drives canvas dismissal explicitly per step, so a stray
      // backdrop tap must not close the canvas — but the tap is still absorbed
      // here (no fall-through to the grid behind).
      guard dismissOnTapOutside else { return }
      onDismiss?()
    }
    // Hide status bar when expanded
    .statusBarHidden(isExpanded)
    .if(self.hidden) { view in
      view.hidden()
    }
  }
}

#Preview("Shrinked View") {
  @Previewable @State var isExpanded = false
  ZStack {
    DynamicIslandExpandedView(
      isExpanded: $isExpanded,
      content: {
        Button("Tap me") {
          debugPrint("HELLO")
        }
      },
      hidden: false,
      onDismiss: {
        isExpanded = false
      }
    )
    Button("Toggle") {
      isExpanded.toggle()
    }
  }
}

#Preview("Expanded View") {
  @Previewable @State var isExpanded = true

  ZStack {
    DynamicIslandExpandedView(
      isExpanded: $isExpanded,
      content: {
        ZStack {
          Color.blue
          Text("HELLO WORLD")
        }
        .frame(height: 300)
      },
      hidden: false,
      onDismiss: {
        isExpanded = false
      })
    Button("Toggle") {
      isExpanded.toggle()
    }
  }
}

#Preview("Hidden View") {
  @Previewable @State var isExpanded = true

  ZStack {
    DynamicIslandExpandedView(
      isExpanded: $isExpanded,
      content: {
        ZStack {
          Color.blue
          Text("HELLO WORLD")
        }
        .frame(height: 300)
      },
      hidden: true,
      onDismiss: {
        isExpanded = false
      })
    Button("Toggle") {
      isExpanded.toggle()
    }
  }
}
