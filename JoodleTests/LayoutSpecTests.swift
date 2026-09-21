//
//  LayoutSpecTests.swift
//  JoodleTests
//
//  Pins the layout system's pure core: how a scene classifies, what hardware
//  facts resolve to for each known screen, and the tokens each class gets.
//

import CoreGraphics
import SwiftUI
import Testing
@testable import Joodle

struct LayoutSpecTests {

  // MARK: - Classification

  @Test func currentPhonesAreThePhoneClass() {
    #expect(LayoutPreset.iPhone17.context.layoutClass == .phone)
    #expect(LayoutPreset.iPhone17ProMax.context.layoutClass == .phone)
  }

  @Test func shortAndNarrowScreensAreCompact() {
    #expect(LayoutPreset.iPhoneSE.context.layoutClass == .compact)
    #expect(LayoutPreset.duoCover.context.layoutClass == .compact)
    #expect(LayoutPreset.splitViewThird.context.layoutClass == .compact)
  }

  @Test func duoInnerDisplayClassifiesByOrientation() {
    #expect(LayoutPreset.duoInnerLandscape.context.layoutClass == .wide)
    #expect(LayoutPreset.duoInnerPortrait.context.layoutClass == .regular)
  }

  @Test func iPadsAreRegularInPortraitBelowElevenInchesAndWideOtherwise() {
    #expect(LayoutPreset.iPadMini.context.layoutClass == .regular)
    #expect(LayoutPreset.iPadMini.rotated().context.layoutClass == .wide)
    #expect(LayoutPreset.iPadPro11.context.layoutClass == .wide)
    #expect(LayoutPreset.iPadPro13.context.layoutClass == .wide)
    #expect(LayoutPreset.iPadPro13.rotated().context.layoutClass == .wide)
  }

  // MARK: - Hardware: cutout

  @Test func islandDevicesGetACenteredPillFromTheMetricsTable() throws {
    let cutout = LayoutPreset.iPhone17.context.cutout
    let frame = try #require(cutout.dynamicIslandFrame)
    #expect(frame.width == 126)
    #expect(frame.origin.y == 14)  // iPhone 17 row: 3pt lower than baseline
    #expect(abs(frame.midX - 402 / 2) < 0.001)
  }

  @Test func unknownIslandModelsFallBackToBaselineMetrics() {
    let snapshot = ScreenHardware.Snapshot(
      modelName: "iPhone 99", idiom: .phone, reportedCornerRadius: 55, dynamicIslandOverride: nil)
    let cutout = ScreenHardware.cutout(topSafeAreaInset: 59, sceneWidth: 400, snapshot: snapshot)
    #expect(cutout.dynamicIslandFrame?.origin.y == 11)
  }

  @Test func notchAndFlatDevicesHaveNoIsland() {
    let snapshot = LayoutPreset.iPhoneSE.hardware
    #expect(ScreenHardware.cutout(topSafeAreaInset: 47, sceneWidth: 390, snapshot: snapshot) == .notch)
    #expect(LayoutPreset.iPhoneSE.context.cutout == .none)
  }

  @Test func debugOverrideWinsOverTheTable() {
    var snapshot = LayoutPreset.iPhoneSE.hardware
    let override = CGRect(x: 100, y: 12, width: 90, height: 36)
    snapshot.dynamicIslandOverride = override
    let cutout = ScreenHardware.cutout(topSafeAreaInset: 20, sceneWidth: 375, snapshot: snapshot)
    #expect(cutout == .dynamicIsland(override))
  }

  // MARK: - Hardware: corner radii

  @Test func reportedRadiusIsUsedSymmetrically() {
    let radii = LayoutPreset.iPhone17.context.cornerRadii
    #expect(radii == RectangleCornerRadii(uniform: 62))
    #expect(LayoutPreset.iPhone17.context.displayCornerRadius == 62)
  }

  @Test func flatPhonesAreFlooredToTheDesignRadius() {
    #expect(LayoutPreset.iPhoneSE.context.cornerRadii == RectangleCornerRadii(uniform: 30))
  }

  @Test func iPadsWithoutAReportedRadiusUseThePadFallback() {
    #expect(LayoutPreset.splitViewThird.context.cornerRadii == RectangleCornerRadii(uniform: 18))
  }

  @Test func duoCoverDisplayHasNearlySquareHingeSideCorners() {
    let radii = LayoutPreset.duoCover.context.cornerRadii
    #expect(radii.topLeading == 8)
    #expect(radii.bottomLeading == 8)
    #expect(radii.topTrailing == 59)
    #expect(radii.bottomTrailing == 59)
    #expect(LayoutPreset.duoCover.context.displayCornerRadius == 59)
  }

  @Test func duoInnerDisplayIsUniformInBothOrientations() {
    #expect(LayoutPreset.duoInnerLandscape.context.cornerRadii == RectangleCornerRadii(uniform: 55))
    #expect(LayoutPreset.duoInnerPortrait.context.cornerRadii == RectangleCornerRadii(uniform: 55))
  }

  @Test func insetRadiiNeverGoNegative() {
    let radii = RectangleCornerRadii(topLeading: 8, bottomLeading: 8, bottomTrailing: 59, topTrailing: 59)
      .inset(by: 14)
    #expect(radii.topLeading == 0)
    #expect(radii.topTrailing == 45)
  }

  // MARK: - Tokens

  @Test func everyClassResolvesToTheShippedPhoneLayoutForNow() {
    for preset in LayoutPreset.all {
      let spec = LayoutSpec.resolve(preset.context)
      #expect(spec.headerHeight == 100, "\(preset.name)")
      #expect(spec.gridHorizontalPadding == 40, "\(preset.name)")
      #expect(spec.splitAxis == .vertical, "\(preset.name)")
      #expect(spec.splitSnapPositions == [0.15, 0.5, 1.0], "\(preset.name)")
      #expect(spec.splitDefaultPosition == 0.5, "\(preset.name)")
      #expect(spec.splitDismissPosition == 0.6, "\(preset.name)")
    }
  }

  // MARK: - Floating canvas container

  @Test func islandDeviceContainerHugsTheCutout() {
    let context = LayoutPreset.iPhone17.context
    let metrics = LayoutSpec.resolve(context).canvasContainer(in: context)
    #expect(metrics.horizontalInset == 14)
    #expect(metrics.topOffset == 14)
    #expect(metrics.topContentInset == 36.67)
    #expect(metrics.collapsedSize == CGSize(width: 126, height: 36.67))
    #expect(metrics.expandedWidth == 402 - 28)
    #expect(metrics.cornerRadii == RectangleCornerRadii(uniform: 62 - 14))
    #expect(metrics.contentCornerRadius == 62 - 14 - 8)
  }

  @Test func flatDeviceContainerSitsBelowTheStatusBar() {
    let context = LayoutPreset.iPhoneSE.context
    let metrics = LayoutSpec.resolve(context).canvasContainer(in: context)
    #expect(metrics.horizontalInset == 10)
    #expect(metrics.topOffset == 20)
    #expect(metrics.topContentInset == 0)
    #expect(metrics.collapsedSize == .zero)
    #expect(metrics.expandedWidth == 375 - 20)
    #expect(metrics.contentCornerRadius == 30 - 10 - 8)
  }

  @Test func duoCoverContainerFollowsEachCorner() {
    let context = LayoutPreset.duoCover.context
    let metrics = LayoutSpec.resolve(context).canvasContainer(in: context)
    #expect(metrics.cornerRadii.topLeading == 0)  // 8pt hinge corner, 14pt inset
    #expect(metrics.cornerRadii.topTrailing == 59 - 14)
  }
}
