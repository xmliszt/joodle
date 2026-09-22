//
//  LayoutPreviewModifier.swift
//  Joodle
//

#if DEBUG
import SwiftUI

/// Frames `content` as one screen shape: the given context and spec in the
/// environment, the preset's safe areas re-created around the content, the
/// cutout drawn over it and the whole thing masked to the preset's corners.
/// The Layout Lab's stage and the `layoutPreset` preview modifier both use it.
struct DeviceFrame<Content: View>: View {
  let context: LayoutContext
  let spec: LayoutSpec
  var showSafeAreas = false
  /// Whether the frame re-creates the safe areas around `content`. Off when
  /// the content hosts a NavigationStack: insets applied outside the stack
  /// don't reach the views inside it, so the caller applies
  /// `emulatedSafeArea` to the stack's root instead.
  var insetsContent = true
  @ViewBuilder let content: () -> Content

  var body: some View {
    ZStack(alignment: .topLeading) {
      content()
        .environment(\.layoutContext, context)
        .environment(\.layoutSpec, spec)
        .emulatedSafeArea(insetsContent ? context.safeArea : EdgeInsets())

      if showSafeAreas {
        safeAreaBands
      }

      if let cutout = context.cutout.concealingFrame {
        Capsule()
          .fill(.black)
          .frame(width: cutout.width, height: cutout.height)
          .offset(x: cutout.minX, y: cutout.minY)
          .allowsHitTesting(false)
      }
    }
    .frame(width: context.size.width, height: context.size.height)
    .clipShape(UnevenRoundedRectangle(cornerRadii: context.cornerRadii, style: .continuous))
  }

  private var safeAreaBands: some View {
    let tint = Color.red.opacity(0.18)
    return ZStack(alignment: .topLeading) {
      tint.frame(width: context.size.width, height: context.safeArea.top)
      tint.frame(width: context.size.width, height: context.safeArea.bottom)
        .offset(y: context.size.height - context.safeArea.bottom)
      tint.frame(width: context.safeArea.leading, height: context.size.height)
      tint.frame(width: context.safeArea.trailing, height: context.size.height)
        .offset(x: context.size.width - context.safeArea.trailing)
    }
    .allowsHitTesting(false)
  }
}

extension View {
  /// Re-creates a screen's safe areas around this view the way the window
  /// does: the view is proposed the safe region, and children that ignore
  /// safe areas extend under the insets.
  func emulatedSafeArea(_ insets: EdgeInsets) -> some View {
    self
      .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: insets.top) }
      .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: insets.bottom) }
      .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: insets.leading) }
      .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: insets.trailing) }
  }

  /// Previews this view as it lays out on `preset`. Pair with a preview
  /// device large enough to show the frame, or let the canvas scroll.
  func layoutPreset(_ preset: LayoutPreset) -> some View {
    let context = preset.context
    return DeviceFrame(context: context, spec: LayoutSpec.resolve(context)) { self }
  }
}
#endif
