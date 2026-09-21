//
//  ScreenHardware.swift
//  Joodle
//
//  Facts about the physical display the scene is on: the cutout and the corner
//  radii. Keyed by model only where hardware genuinely differs from model to
//  model. Layout decisions never live here — those belong to `LayoutSpec`,
//  keyed by `LayoutClass`, so a new device only ever needs a hardware row.
//

import SwiftUI
import UIKit

/// The physical cutout in the display, resolved for the current scene.
enum ScreenCutout: Equatable {
  /// Nothing to hide behind: flat phones, iPads, the iPhone Duo inner display
  /// (its camera sits under the screen).
  case none
  case notch
  /// The Dynamic Island capsule, in scene coordinates.
  case dynamicIsland(CGRect)
  /// A round camera hole off to one side, in scene coordinates: the iPhone Duo
  /// cover display carries one in its trailing sensor bar. The floating canvas
  /// tucks into it the way it tucks behind an island.
  case cameraHole(CGRect)

  var dynamicIslandFrame: CGRect? {
    if case .dynamicIsland(let frame) = self { return frame }
    return nil
  }

  var hasDynamicIsland: Bool { dynamicIslandFrame != nil }

  /// The opaque region a collapsed floating container can hide in, if any.
  var concealingFrame: CGRect? {
    switch self {
    case .dynamicIsland(let frame), .cameraHole(let frame): return frame
    case .none, .notch: return nil
    }
  }
}

enum ScreenHardware {

  // MARK: - Dynamic Island metrics
  //
  // To adapt a new island device: calibrate it with the Dynamic Island Lab
  // (Settings → Developer → Tools), then add one entry below. Models not
  // listed use `.baseline`.

  struct DynamicIslandMetrics: Equatable {
    /// Size of the island cutout capsule.
    var pillSize = CGSize(width: 126, height: 36.67)
    /// Distance from the top screen edge to the top of the cutout.
    var topOffsetPt: CGFloat = 11

    /// iPhone 14 Pro through 16 lineups. Minor per-model variations exist
    /// (±3pt) but these values work well for alignment across all of them.
    static let baseline = DynamicIslandMetrics()

    /// Deviations from the baseline, keyed by model name (simulator prefix
    /// stripped, so hardware and simulator resolve identically).
    static let overridesByModel: [String: DynamicIslandMetrics] = [
      // iPhone 17 series — island sits 3pt lower.
      "iPhone 17": .init(topOffsetPt: 14),
      "iPhone 17 Pro": .init(topOffsetPt: 14),
      "iPhone 17 Pro Max": .init(topOffsetPt: 14),

      // iPhone Air — island sits 9pt lower.
      "iPhone Air": .init(topOffsetPt: 20),

      // iPhone 18 Pro series — narrower 90pt pill, sits 3pt lower.
      "iPhone 18 Pro": .init(pillSize: CGSize(width: 90, height: 36.67), topOffsetPt: 14),
      "iPhone 18 Pro Max": .init(pillSize: CGSize(width: 90, height: 36.67), topOffsetPt: 14),
    ]
  }

  static func dynamicIslandMetrics(modelName: String) -> DynamicIslandMetrics {
    DynamicIslandMetrics.overridesByModel[modelName] ?? .baseline
  }

  // MARK: - Snapshot

  /// What the layout provider samples from UIKit; tests build it by hand.
  struct Snapshot: Equatable {
    /// Model name with the simulator prefix stripped.
    var modelName: String
    var idiom: UIUserInterfaceIdiom
    /// Symmetric corner radius the screen reports, nil when it doesn't answer.
    var reportedCornerRadius: CGFloat?
    /// Calibration override for the island pill (Dynamic Island Lab). While
    /// non-nil it wins over the metrics table and makes the device count as
    /// having an island.
    var dynamicIslandOverride: CGRect?

    static func current() -> Snapshot {
      let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first
#if DEBUG
      let islandOverride = LayoutDebugOverrides.shared.dynamicIslandFrame
#else
      let islandOverride: CGRect? = nil
#endif
      return Snapshot(
        modelName: UIDevice.normalizedModelName,
        idiom: UIDevice.current.userInterfaceIdiom,
        reportedCornerRadius: ScreenHardware.reportedCornerRadius(of: scene?.screen),
        dynamicIslandOverride: islandOverride
      )
    }
  }

  /// The radius the screen reports through the undocumented `_displayCornerRadius`
  /// key, assembled at runtime to keep the literal out of the binary.
  static func reportedCornerRadius(of screen: UIScreen?) -> CGFloat? {
    let key = ["Radius", "Corner", "display", "_"].reversed().joined()
    guard let screen, let radius = screen.value(forKey: key) as? CGFloat, radius > 0 else {
      return nil
    }
    return radius
  }

  // MARK: - iPhone Duo

  /// Measured on the iOS 27.1 simulator. The cover display is 466×678pt with a
  /// trailing sensor bar the system keeps as an 84pt safe-area inset (top inset
  /// 0); the camera hole sits in that bar. The inner display has no cutout.
  enum Duo {
    static let modelName = "iPhone Duo"
    static let coverCameraHole = CGRect(x: 396.3, y: 29.3, width: 43, height: 43)
    static let coverSafeArea = EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84)

    /// Anything with a short side under 600pt is the cover; the inner display
    /// is 951×669pt.
    static func isCoverDisplay(sceneSize: CGSize) -> Bool {
      min(sceneSize.width, sceneSize.height) < 600
    }
  }

  // MARK: - Cutout

  /// Island devices report a top safe-area inset of at least 51pt, notch
  /// devices 44–50pt. The Duo is keyed by model: its cover has a camera hole
  /// in the sensor bar, its inner display nothing at all.
  static func cutout(
    topSafeAreaInset: CGFloat,
    sceneWidth: CGFloat,
    snapshot: Snapshot
  ) -> ScreenCutout {
    if let override = snapshot.dynamicIslandOverride {
      return .dynamicIsland(override)
    }
    if snapshot.modelName == Duo.modelName {
      // Only the cover has a cutout; `sceneWidth` alone can't tell the inner
      // display's portrait (669 wide) from a phone, so use the size class of
      // the width: the cover is 466pt across, the inner display never under 669.
      return sceneWidth < 600 ? .cameraHole(Duo.coverCameraHole) : .none
    }
    if topSafeAreaInset >= 51 {
      let metrics = dynamicIslandMetrics(modelName: snapshot.modelName)
      return .dynamicIsland(
        CGRect(
          x: (sceneWidth - metrics.pillSize.width) / 2,
          y: metrics.topOffsetPt,
          width: metrics.pillSize.width,
          height: metrics.pillSize.height
        )
      )
    }
    if topSafeAreaInset >= 44 {
      return .notch
    }
    return .none
  }

  // MARK: - Corner radii

  /// Design floor for flat-display phones (iPhone SE) that report a radius of
  /// 0. Concentric surfaces derive their rounding from the screen, and on a
  /// square display that would collapse them to sharp corners.
  static let flatPhoneDesignRadius: CGFloat = 30
  static let padFallbackRadius: CGFloat = 18

  /// Per-corner radii for the scene. Symmetric everywhere except the iPhone
  /// Duo cover display, whose hinge-side corners are nearly square.
  static func cornerRadii(
    sceneSize: CGSize,
    topSafeAreaInset: CGFloat,
    snapshot: Snapshot
  ) -> RectangleCornerRadii {
    if snapshot.modelName == Duo.modelName {
      return duoCornerRadii(sceneSize: sceneSize)
    }
    return RectangleCornerRadii(
      uniform: symmetricCornerRadius(
        sceneSize: sceneSize, topSafeAreaInset: topSafeAreaInset, snapshot: snapshot))
  }

  /// From the CoreSimulator device profile: cover display 466×678pt with 8pt
  /// corners on the hinge side (left, in the display's native orientation) and
  /// 59pt on the outer side; inner display 55pt all round. The cover is told
  /// apart by its size — anything larger is the inner display.
  private static func duoCornerRadii(sceneSize: CGSize) -> RectangleCornerRadii {
    guard Duo.isCoverDisplay(sceneSize: sceneSize) else { return RectangleCornerRadii(uniform: 55) }
    return RectangleCornerRadii(topLeading: 8, bottomLeading: 8, bottomTrailing: 59, topTrailing: 59)
  }

  static func symmetricCornerRadius(
    sceneSize: CGSize,
    topSafeAreaInset: CGFloat,
    snapshot: Snapshot
  ) -> CGFloat {
    let resolved: CGFloat
    if let reported = snapshot.reportedCornerRadius, reported > 0 {
      resolved = reported
    } else {
      resolved = estimatedCornerRadius(
        topSafeAreaInset: topSafeAreaInset, sceneHeight: sceneSize.height, idiom: snapshot.idiom)
    }
    if resolved <= 0, snapshot.idiom == .phone {
      return flatPhoneDesignRadius
    }
    return resolved
  }

  /// Safe-area heuristic for screens that don't report a radius.
  private static func estimatedCornerRadius(
    topSafeAreaInset: CGFloat,
    sceneHeight: CGFloat,
    idiom: UIUserInterfaceIdiom
  ) -> CGFloat {
    if idiom == .pad { return padFallbackRadius }
    if topSafeAreaInset >= 59 { return 55 }   // Dynamic Island devices
    if topSafeAreaInset >= 44 { return 39 }   // notch devices
    if topSafeAreaInset > 20 { return 39 }    // home indicator, no notch
    if idiom == .phone, sceneHeight >= 812 { return 39 }
    return 0
  }
}

// MARK: - RectangleCornerRadii helpers

extension RectangleCornerRadii {
  init(uniform radius: CGFloat) {
    self.init(
      topLeading: radius, bottomLeading: radius, bottomTrailing: radius, topTrailing: radius)
  }

  var maxRadius: CGFloat {
    max(topLeading, bottomLeading, bottomTrailing, topTrailing)
  }

  /// Radii of a shape inset from the screen edge by `inset`, so it stays
  /// concentric with the corners it hugs. Never negative.
  func inset(by inset: CGFloat) -> RectangleCornerRadii {
    RectangleCornerRadii(
      topLeading: max(topLeading - inset, 0),
      bottomLeading: max(bottomLeading - inset, 0),
      bottomTrailing: max(bottomTrailing - inset, 0),
      topTrailing: max(topTrailing - inset, 0)
    )
  }
}

// MARK: - Debug overrides

#if DEBUG
/// Live hardware overrides driven by the developer labs. Observable so the
/// layout provider re-resolves the moment a value changes.
@Observable
final class LayoutDebugOverrides {
  static let shared = LayoutDebugOverrides()

  /// Dynamic Island Lab: the pill frame to use instead of the metrics table.
  var dynamicIslandFrame: CGRect?
}
#endif
