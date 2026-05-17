//
//  ShutterButton.swift
//  Joodle
//

import SwiftUI

enum ShutterButtonStyle {
  /// Liquid-glass outer container with drop shadow (used on Dynamic Island devices over fullscreen camera).
  case glass
  /// Transparent outer with 2pt white stroke (used on non-DI devices inside the black bottom sheet).
  case outline
}

struct ShutterButton: View {
  let style: ShutterButtonStyle
  let action: () -> Void

  private let outerDiameter: CGFloat = 72
  private let innerInset: CGFloat = 6

  var body: some View {
    Button(action: {
      Haptic.play(with: .medium)
      action()
    }) {
      ZStack {
        outerShape
        Circle()
          .fill(Color.appAccent)
          .padding(innerInset)
      }
      .frame(width: outerDiameter, height: outerDiameter)
    }
    .buttonStyle(ShutterPressStyle())
  }

  @ViewBuilder
  private var outerShape: some View {
    switch style {
    case .glass:
      if #available(iOS 26.0, *) {
        // Apply glass only to the outer ring — punch out the inner area so the
        // white inner circle isn't tinted by the glass material's specular/
        // tint layer.
        Circle()
          .fill(.clear)
          .glassEffect(.clear, in: Circle())
          .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 0)
      } else {
        Circle()
          .fill(.ultraThinMaterial)
          .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 0)
      }
    case .outline:
      Circle()
        .stroke(Color.white, lineWidth: 2)
    }
  }
}

private struct ShutterPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
      .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
  }
}
