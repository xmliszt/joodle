//
//  LayoutOrientationPolicyTests.swift
//  JoodleTests
//

import CoreGraphics
import Testing
import UIKit
@testable import Joodle

struct LayoutOrientationPolicyTests {

  @Test func phonesStayPortrait() {
    #expect(LayoutOrientationPolicy.supportedOrientations(screenSize: LayoutPreset.iPhone17.size) == .portrait)
    #expect(LayoutOrientationPolicy.supportedOrientations(screenSize: LayoutPreset.iPhoneSE.size) == .portrait)
    #expect(LayoutOrientationPolicy.supportedOrientations(screenSize: LayoutPreset.iPhone17ProMax.size) == .portrait)
  }

  @Test func duoCoverStaysPortraitAndInnerRotates() {
    #expect(LayoutOrientationPolicy.supportedOrientations(screenSize: LayoutPreset.duoCover.size) == .portrait)
    #expect(LayoutOrientationPolicy.supportedOrientations(screenSize: LayoutPreset.duoInnerLandscape.size) == .all)
    #expect(LayoutOrientationPolicy.supportedOrientations(screenSize: LayoutPreset.duoInnerPortrait.size) == .all)
  }

  @Test func iPadsRotate() {
    #expect(LayoutOrientationPolicy.supportedOrientations(screenSize: LayoutPreset.iPadMini.size) == .all)
    #expect(LayoutOrientationPolicy.supportedOrientations(screenSize: LayoutPreset.iPadPro13.size) == .all)
  }

  @Test func noWindowMeansPortrait() {
    #expect(LayoutOrientationPolicy.supportedOrientations(for: nil) == .portrait)
  }
}
