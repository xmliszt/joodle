//
//  LayoutContext.swift
//  Joodle
//
//  The container the app was actually given — scene size, safe area, corner
//  radii, cutout and size classes — published through the environment by
//  `layoutContextProvider()`. Views read this instead of `UIScreen.main` or
//  static `UIDevice` geometry, so a folded display, a multitasking window and
//  the Layout Lab's emulated devices all flow through one value.
//

import SwiftUI

/// Coarse shape class the layout tokens are keyed by. Derived from the
/// container, never from the device model.
enum LayoutClass: String, CaseIterable {
  /// Short or narrow: iPhone SE, iPhone Duo cover display, an iPad Split View third.
  case compact
  /// Every current iPhone slab. The layout the app shipped with.
  case phone
  /// Wide enough to cap the grid, still stacked: iPhone Duo inner display in portrait, iPad mini portrait.
  case regular
  /// Room for two columns: Duo inner display in landscape, iPads.
  case wide

  init(size: CGSize) {
    let width = size.width
    let height = size.height
    if width >= 800 || (width > height && width >= 700) {
      self = .wide
    } else if width >= 600 {
      self = .regular
    } else if height < 700 || width < 360 {
      self = .compact
    } else {
      self = .phone
    }
  }
}

/// Raw measurement of the scene, before hardware facts are attached.
struct LayoutProbe: Equatable {
  /// Full scene size, safe areas included.
  var size: CGSize
  var safeArea: EdgeInsets

  static let zero = LayoutProbe(size: .zero, safeArea: EdgeInsets())
}

struct LayoutContext: Equatable {
  /// Full scene size, safe areas included. The scene, not the screen: on a
  /// foldable or in a multitasking window the two differ.
  var size: CGSize
  var safeArea: EdgeInsets
  var cornerRadii: RectangleCornerRadii
  var cutout: ScreenCutout
  var horizontalSizeClass: UserInterfaceSizeClass?
  var verticalSizeClass: UserInterfaceSizeClass?

  var layoutClass: LayoutClass { LayoutClass(size: size) }

  var isLandscape: Bool { size.width > size.height }

  /// The largest corner radius, for surfaces that take one device-derived
  /// radius rather than hugging a specific corner.
  var displayCornerRadius: CGFloat { cornerRadii.maxRadius }

  /// Corner radii for content that fills the horizontally safe region. A
  /// corner that sits on a safe-area boundary rather than the screen edge
  /// (the Duo cover's sensor bar) has no hardware corner to echo, so it
  /// borrows the opposite side's radius and the region reads symmetric.
  var safeRegionCornerRadii: RectangleCornerRadii {
    var radii = cornerRadii
    if safeArea.trailing > 0 {
      radii.topTrailing = cornerRadii.topLeading
      radii.bottomTrailing = cornerRadii.bottomLeading
    }
    if safeArea.leading > 0 {
      radii.topLeading = cornerRadii.topTrailing
      radii.bottomLeading = cornerRadii.bottomTrailing
    }
    return radii
  }

  static func resolve(
    probe: LayoutProbe,
    hardware: ScreenHardware.Snapshot,
    horizontalSizeClass: UserInterfaceSizeClass?,
    verticalSizeClass: UserInterfaceSizeClass?
  ) -> LayoutContext {
    LayoutContext(
      size: probe.size,
      safeArea: probe.safeArea,
      cornerRadii: ScreenHardware.cornerRadii(
        sceneSize: probe.size, topSafeAreaInset: probe.safeArea.top, snapshot: hardware),
      cutout: ScreenHardware.cutout(
        topSafeAreaInset: probe.safeArea.top, sceneWidth: probe.size.width, snapshot: hardware),
      horizontalSizeClass: horizontalSizeClass,
      verticalSizeClass: verticalSizeClass
    )
  }

  /// Environment default outside a provider (previews, isolated tests): an
  /// iPhone 17-class portrait scene, so previews render at the shipped layout.
  static let placeholder = LayoutContext.resolve(
    probe: LayoutProbe(
      size: CGSize(width: 402, height: 874),
      safeArea: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)),
    hardware: ScreenHardware.Snapshot(
      modelName: "iPhone 17", idiom: .phone, reportedCornerRadius: 62, dynamicIslandOverride: nil),
    horizontalSizeClass: .compact,
    verticalSizeClass: .regular
  )
}

extension EnvironmentValues {
  @Entry var layoutContext: LayoutContext = .placeholder
}

/// Coordinate space the home screen defines on its root, so frames handed
/// between its children (the split's entry panel, the floating canvas) are
/// measured in the scene's own points. Unlike `.global`, it stays correct when
/// the whole screen is scaled inside the Layout Lab's stage.
enum LayoutSceneSpace {
  static let name = "joodle.layoutScene"
}
