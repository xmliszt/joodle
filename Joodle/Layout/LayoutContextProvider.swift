//
//  LayoutContextProvider.swift
//  Joodle
//

import SwiftUI

extension View {
  /// Measures the scene this view is given and publishes `layoutContext` and
  /// `layoutSpec` to the subtree. Applied once, at the window root. It observes
  /// the geometry rather than wrapping the content in a `GeometryReader`, so it
  /// changes nothing about how the root lays out.
  func layoutContextProvider() -> some View {
    modifier(LayoutContextProviderModifier())
  }
}

private struct LayoutContextProviderModifier: ViewModifier {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  /// Seeded from the key window so the very first frame already has real
  /// geometry; `onGeometryChange` takes over from there.
  @State private var probe = LayoutProbe.fromKeyWindow()

  func body(content: Content) -> some View {
    let context = resolvedContext
    content
      .onGeometryChange(for: LayoutProbe.self) { proxy in
        let insets = proxy.safeAreaInsets
        return LayoutProbe(
          size: CGSize(
            width: proxy.size.width + insets.leading + insets.trailing,
            height: proxy.size.height + insets.top + insets.bottom),
          safeArea: insets
        )
      } action: { newProbe in
        // Zero shows up before the first layout and during scene teardown;
        // keep the last real measurement.
        guard newProbe.size.width > 0, newProbe.size.height > 0 else { return }
        probe = newProbe
      }
      .environment(\.layoutContext, context)
      .environment(\.layoutSpec, spec(for: context))
  }

  /// In debug builds the Layout Lab's live overrides sit between the resolver
  /// and the views, so tuning the device in hand shows up immediately.
  private func spec(for context: LayoutContext) -> LayoutSpec {
    let resolved = LayoutSpec.resolve(context)
#if DEBUG
    return LayoutTuning.shared.apply(resolved, for: context.layoutClass)
#else
    return resolved
#endif
  }

  private var resolvedContext: LayoutContext {
    guard probe.size.width > 0, probe.size.height > 0 else { return .placeholder }
    return LayoutContext.resolve(
      probe: probe,
      hardware: .current(),
      horizontalSizeClass: horizontalSizeClass,
      verticalSizeClass: verticalSizeClass
    )
  }
}

extension LayoutProbe {
  static func fromKeyWindow() -> LayoutProbe {
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first?.windows.first
    else { return .zero }
    let insets = window.safeAreaInsets
    return LayoutProbe(
      size: window.bounds.size,
      safeArea: EdgeInsets(
        top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right)
    )
  }
}
