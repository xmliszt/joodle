//
//  View.swift
//  Joodle
//
//  Created by Li Yuxuan on 14/8/25.
//

import SwiftUI

// MARK: - Circular Glass Button Style
struct CircularGlassButtonStyle: ViewModifier {
  let tintColor: Color?

  func body(content: Content) -> some View {
    if #available(iOS 26, *) {
      // iOS 26+: Use native glass background effect with circular shape
      content
        .font(.appFont(size: 18))
        .foregroundStyle(tintColor ?? Color.primary)
        .frame(width: 40, height: 40)
        .padding(2)
        .glassEffect(.regular.interactive())
        .clipShape(Circle())
    } else {
      // Pre-iOS 26: Use custom circular background style
      // Note: Using stable foregroundStyle instead of conditional modifier
      // to prevent view identity issues that cause flickering during animations
      // Also using drawingGroup() to render in a separate layer, preventing
      // flickering when parent view animates (e.g., split view sliding up)
      content
        .font(.appFont(size: 18))
        .foregroundStyle(tintColor ?? Color.primary)
        .frame(width: 40, height: 40)
        .background(.appSurface)
        .clipShape(Circle())
        .drawingGroup()
    }
  }
}

// MARK: - Device Rotation Detection
/// Custom view modifier to track device rotation and call our action
struct DeviceRotationViewModifier: ViewModifier {
  let action: (UIDeviceOrientation) -> Void

  func body(content: Content) -> some View {
    content
      .onAppear()
      .onReceive(
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
      ) { _ in
        action(UIDevice.current.orientation)
      }
  }
}

// MARK: - Shake Detection
/// Custom view modifier to detect shake gestures
struct ShakeDetectionViewModifier: ViewModifier {
  let action: () -> Void

  func body(content: Content) -> some View {
    content
      .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
        action()
      }
  }
}

extension View {
  func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
    self.modifier(DeviceRotationViewModifier(action: action))
  }

  func onShake(perform action: @escaping () -> Void) -> some View {
    self.modifier(ShakeDetectionViewModifier(action: action))
  }

  @ViewBuilder
  func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }

func circularGlassButton(tintColor: Color? = nil) -> some View {
    self.modifier(CircularGlassButtonStyle(tintColor: tintColor))
  }
}
