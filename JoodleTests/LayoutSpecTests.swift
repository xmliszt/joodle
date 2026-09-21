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

  @Test func phoneAndCompactKeepTheShippedLayout() {
    for preset in [LayoutPreset.iPhone17, .iPhone17ProMax, .iPhoneSE, .duoCover, .splitViewThird] {
      let spec = LayoutSpec.resolve(preset.context)
      #expect(spec == LayoutSpec(), "\(preset.name)")
      #expect(spec.splitAxis == .vertical, "\(preset.name)")
      #expect(spec.splitSnapPositions == [0.15, 0.5, 1.0], "\(preset.name)")
      #expect(spec.gridMaxWidth == 0, "\(preset.name)")
      #expect(spec.canvasContainerMaxWidth == 0, "\(preset.name)")
    }
  }

  @Test func regularStaysStackedButCapsTheGridAndContainer() {
    let spec = LayoutSpec.resolve(LayoutPreset.duoInnerPortrait.context)
    #expect(spec.splitAxis == .vertical)
    #expect(spec.gridMaxWidth == 520)
    #expect(spec.canvasContainerMaxWidth == 400)
    #expect(LayoutSpec.resolve(LayoutPreset.iPadMini.context) == spec)
  }

  @Test func wideSplitsSideBySide() {
    let spec = LayoutSpec.resolve(LayoutPreset.duoInnerLandscape.context)
    #expect(spec.splitAxis == .horizontal)
    #expect(spec.splitSnapPositions == [0.35, 0.5, 1.0])
    #expect(spec.splitDismissPosition == 0.75)
    #expect(spec.gridMaxWidth == 520)
    #expect(LayoutSpec.resolve(LayoutPreset.iPadPro13.rotated().context).splitAxis == .horizontal)
  }

  @Test func splitAxisValueMirrorsTheAxis() {
    var spec = LayoutSpec()
    #expect(spec.splitAxisValue == 0)
    spec.splitAxisValue = 1
    #expect(spec.splitAxis == .horizontal)
    spec.splitAxisValue = 0
    #expect(spec.splitAxis == .vertical)
  }

  // MARK: - Grid padding cap

  @Test func gridPaddingIsUncappedOnPhones() {
    let spec = LayoutSpec.resolve(LayoutPreset.iPhone17.context)
    #expect(spec.gridHorizontalPadding(forContainerWidth: 402) == 40)
    #expect(spec.gridHorizontalPadding(forContainerWidth: 951) == 40)
  }

  @Test func gridPaddingGrowsToHoldTheCap() {
    let spec = LayoutSpec.resolve(LayoutPreset.duoInnerPortrait.context)
    #expect(spec.gridHorizontalPadding(forContainerWidth: 669) == 74.5)  // (669 - 520) / 2
    // A narrow column keeps the plain padding rather than going below it.
    #expect(spec.gridHorizontalPadding(forContainerWidth: 475) == 40)
  }

  // MARK: - Floating canvas container

  @Test func islandDeviceContainerHugsTheCutout() {
    let context = LayoutPreset.iPhone17.context
    let metrics = LayoutSpec.resolve(context).canvasContainer(in: context)
    #expect(metrics.horizontalInset == 14)
    #expect(metrics.topOffset == 14)
    #expect(metrics.topContentInset == 36.67)
    #expect(metrics.collapsedSize == CGSize(width: 126, height: 36.67))
    #expect(metrics.expandedWidth == 374)  // 402 - 2 × 14
    #expect(metrics.cornerRadii == RectangleCornerRadii(uniform: 48))  // 62 - 14
    #expect(metrics.contentCornerRadius == 40)  // 48 - 8
  }

  @Test func flatDeviceContainerSitsBelowTheStatusBar() {
    let context = LayoutPreset.iPhoneSE.context
    let metrics = LayoutSpec.resolve(context).canvasContainer(in: context)
    #expect(metrics.horizontalInset == 10)
    #expect(metrics.topOffset == 20)
    #expect(metrics.topContentInset == 0)
    #expect(metrics.collapsedSize == .zero)
    #expect(metrics.expandedWidth == 355)  // 375 - 2 × 10
    #expect(metrics.contentCornerRadius == 12)  // 30 - 10 - 8
  }

  @Test func duoCoverContainerFollowsEachCorner() {
    let context = LayoutPreset.duoCover.context
    let metrics = LayoutSpec.resolve(context).canvasContainer(in: context)
    // The Duo has no row in the island table yet, so the baseline 11pt offset
    // is the inset: the 8pt hinge corner collapses, the 59pt outer corner keeps 48.
    #expect(metrics.cornerRadii.topLeading == 0)
    #expect(metrics.cornerRadii.topTrailing == 48)
  }

  @Test func wideContainerFloatsCenteredAtTheCap() {
    let context = LayoutPreset.duoInnerLandscape.context
    let spec = LayoutSpec.resolve(context)
    let metrics = spec.canvasContainer(in: context)
    #expect(metrics.expandedWidth == 400)
    #expect(metrics.horizontalInset == 275.5)  // (951 - 400) / 2
    #expect(metrics.cornerRadii == RectangleCornerRadii(uniform: spec.canvasContainerFloatingCornerRadius))
    #expect(metrics.contentCornerRadius == spec.canvasContainerFloatingCornerRadius - 8)
    #expect(metrics.topOffset == context.safeArea.top)
    #expect(metrics.collapsedSize == .zero)
  }

  @Test func capWiderThanTheSceneIsIgnored() {
    var spec = LayoutSpec.resolve(LayoutPreset.iPhone17.context)
    spec.canvasContainerMaxWidth = 900
    let metrics = spec.canvasContainer(in: LayoutPreset.iPhone17.context)
    #expect(metrics.expandedWidth == 374)
    #expect(metrics.horizontalInset == 14)
  }
}
