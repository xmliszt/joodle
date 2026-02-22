//
//  ViewHeightPreferenceKey.swift
//  Joodle
//
//  Created by Li Yuxuan on 22/2/26.
//

import SwiftUI

/// A PreferenceKey for propagating a view's measured height up the view tree.
struct ViewHeightPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

extension View {
  /// Reads the rendered height of a view and writes it into `binding`.
  /// Uses a clear GeometryReader background so layout is unaffected.
  func readHeight(_ binding: Binding<CGFloat>) -> some View {
    self.background(
      GeometryReader { geo in
        Color.clear
          .preference(key: ViewHeightPreferenceKey.self, value: geo.size.height)
      }
    )
    .onPreferenceChange(ViewHeightPreferenceKey.self) { height in
      guard height > 0 else { return }
      // Defer out of the current layout pass so the animation context is
      // applied in a fresh frame — this is what makes the sheet resize animate
      // rather than snap when content height changes (e.g. prompt appearing).
      DispatchQueue.main.async {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
          binding.wrappedValue = height
        }
      }
    }
  }
}
