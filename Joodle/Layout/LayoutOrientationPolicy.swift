//
//  LayoutOrientationPolicy.swift
//  Joodle
//

import UIKit

/// Landscape is offered only where the layout has a wide class to show for
/// it: screens whose shorter side is at least 600pt (iPads, the iPhone Duo
/// inner display). Every other iPhone stays portrait, as it always has.
enum LayoutOrientationPolicy {
  static let minimumShortSideForLandscape: CGFloat = 600

  static func supportedOrientations(screenSize: CGSize) -> UIInterfaceOrientationMask {
    min(screenSize.width, screenSize.height) >= minimumShortSideForLandscape ? .all : .portrait
  }

  static func supportedOrientations(for window: UIWindow?) -> UIInterfaceOrientationMask {
    supportedOrientations(screenSize: window?.windowScene?.screen.bounds.size ?? .zero)
  }

  /// Asks UIKit to re-query the supported orientations. Needed when the scene
  /// moves between screens with different answers, such as folding the Duo
  /// from its inner display to the cover.
  static func refresh() {
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for window in windowScene.windows {
        window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
      }
    }
  }
}
