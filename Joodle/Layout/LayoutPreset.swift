//
//  LayoutPreset.swift
//  Joodle
//
//  Screen shapes the Layout Lab emulates and the resolver tests exercise.
//  Dimensions are points. Hardware facts come from the CoreSimulator device
//  profiles; a preset stays `verified: false` until its frame and safe areas
//  have been checked against the real simulator.
//

#if DEBUG
import SwiftUI

struct LayoutPreset: Identifiable, Equatable {
  let id: String
  let name: String
  let size: CGSize
  let safeArea: EdgeInsets
  let modelName: String
  let idiom: UIUserInterfaceIdiom
  let reportedCornerRadius: CGFloat?
  let verified: Bool

  var probe: LayoutProbe {
    LayoutProbe(size: size, safeArea: safeArea)
  }

  var hardware: ScreenHardware.Snapshot {
    ScreenHardware.Snapshot(
      modelName: modelName, idiom: idiom, reportedCornerRadius: reportedCornerRadius,
      dynamicIslandOverride: nil)
  }

  var context: LayoutContext {
    LayoutContext.resolve(
      probe: probe,
      hardware: hardware,
      horizontalSizeClass: size.width >= 600 ? .regular : .compact,
      verticalSizeClass: size.height >= 600 ? .regular : .compact
    )
  }

  /// The same screen turned a quarter turn. Safe areas swap edges the way
  /// UIKit rotates them; the top inset moves to the sides on phones, which is
  /// how a landscape phone reports its cutout.
  func rotated() -> LayoutPreset {
    let rotatedSafeArea = idiom == .phone
      ? EdgeInsets(
          top: 0, leading: safeArea.top, bottom: max(safeArea.bottom, 21), trailing: safeArea.top)
      : EdgeInsets(
          top: safeArea.leading, leading: safeArea.bottom, bottom: safeArea.trailing,
          trailing: safeArea.top)
    return LayoutPreset(
      id: id + ".rotated",
      name: name + ", rotated",
      size: CGSize(width: size.height, height: size.width),
      safeArea: rotatedSafeArea,
      modelName: modelName,
      idiom: idiom,
      reportedCornerRadius: reportedCornerRadius,
      verified: false
    )
  }

  // MARK: - Catalogue

  static let iPhoneSE = LayoutPreset(
    id: "iphone-se", name: "iPhone SE (3rd gen)",
    size: CGSize(width: 375, height: 667),
    safeArea: EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0),
    modelName: "iPhone SE (3rd generation)", idiom: .phone, reportedCornerRadius: nil,
    verified: true)

  static let iPhone17 = LayoutPreset(
    id: "iphone-17", name: "iPhone 17",
    size: CGSize(width: 402, height: 874),
    safeArea: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
    modelName: "iPhone 17", idiom: .phone, reportedCornerRadius: 62,
    verified: true)

  static let iPhone17ProMax = LayoutPreset(
    id: "iphone-17-pro-max", name: "iPhone 17 Pro Max",
    size: CGSize(width: 440, height: 956),
    safeArea: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
    modelName: "iPhone 17 Pro Max", idiom: .phone, reportedCornerRadius: 62,
    verified: false)

  /// Cover display, measured on the simulator: no top inset, an 84pt trailing
  /// sensor bar holding the status items and a round camera hole, corners 8pt
  /// on the hinge side and 59pt on the outer side (`ScreenHardware` knows
  /// both by model).
  static let duoCover = LayoutPreset(
    id: "duo-cover", name: "iPhone Duo · cover",
    size: CGSize(width: 466, height: 678),
    safeArea: ScreenHardware.Duo.coverSafeArea,
    modelName: ScreenHardware.Duo.modelName, idiom: .phone, reportedCornerRadius: 59,
    verified: true)

  /// Inner display in its native landscape posture.
  static let duoInnerLandscape = LayoutPreset(
    id: "duo-inner-landscape", name: "iPhone Duo · inner, landscape",
    size: CGSize(width: 951, height: 669),
    safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
    modelName: "iPhone Duo", idiom: .phone, reportedCornerRadius: 55,
    verified: false)

  static let duoInnerPortrait = LayoutPreset(
    id: "duo-inner-portrait", name: "iPhone Duo · inner, portrait",
    size: CGSize(width: 669, height: 951),
    safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
    modelName: "iPhone Duo", idiom: .phone, reportedCornerRadius: 55,
    verified: false)

  static let iPadMini = LayoutPreset(
    id: "ipad-mini", name: "iPad mini",
    size: CGSize(width: 744, height: 1133),
    safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
    modelName: "iPad mini (A17 Pro)", idiom: .pad, reportedCornerRadius: 18,
    verified: false)

  static let iPadPro11 = LayoutPreset(
    id: "ipad-pro-11", name: "iPad Pro 11″",
    size: CGSize(width: 834, height: 1210),
    safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
    modelName: "iPad Pro (11-inch) (M5)", idiom: .pad, reportedCornerRadius: 18,
    verified: false)

  static let iPadPro13 = LayoutPreset(
    id: "ipad-pro-13", name: "iPad Pro 13″",
    size: CGSize(width: 1032, height: 1376),
    safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
    modelName: "iPad Pro (13-inch) (M5)", idiom: .pad, reportedCornerRadius: 18,
    verified: false)

  /// An iPad Split View third: the narrowest window the app can be given.
  static let splitViewThird = LayoutPreset(
    id: "split-view-third", name: "iPad Split View ⅓",
    size: CGSize(width: 320, height: 1133),
    safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
    modelName: "iPad mini (A17 Pro)", idiom: .pad, reportedCornerRadius: nil,
    verified: false)

  static let all: [LayoutPreset] = [
    iPhoneSE, iPhone17, iPhone17ProMax,
    duoCover, duoInnerLandscape, duoInnerPortrait,
    iPadMini, iPadMini.rotated(),
    iPadPro11, iPadPro11.rotated(),
    iPadPro13, iPadPro13.rotated(),
    splitViewThird,
  ]
}
#endif
