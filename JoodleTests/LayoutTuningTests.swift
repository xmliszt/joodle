//
//  LayoutTuningTests.swift
//  JoodleTests
//
//  The Layout Lab's override store: how overrides lay over the resolver, how
//  candidates round-trip, and the shape of the block copied for the agent.
//

import CoreGraphics
import Testing
@testable import Joodle

struct LayoutTuningTests {

  private let wide = LayoutPreset.duoInnerLandscape.context
  private var resolved: LayoutSpec { LayoutSpec.resolve(wide) }

  private func makeTuning() -> LayoutTuning {
    LayoutTuning(defaults: nil)
  }

  @Test func untouchedStoreLeavesTheResolverAlone() {
    let tuning = makeTuning()
    #expect(tuning.apply(resolved, for: .wide) == resolved)
    #expect(tuning.overrideCount(for: .wide) == 0)
  }

  @Test func overridesApplyOnlyToTheirClass() {
    let tuning = makeTuning()
    tuning.set(.headerHeight, to: 88, for: .wide)
    #expect(tuning.apply(resolved, for: .wide).headerHeight == 88)
    #expect(tuning.apply(resolved, for: .phone).headerHeight == 100)
    #expect(tuning.isOverridden(.headerHeight, for: .wide))
    #expect(!tuning.isOverridden(.headerHeight, for: .phone))
  }

  @Test func valueFallsBackToTheResolverWhenNotOverridden() {
    let tuning = makeTuning()
    #expect(tuning.value(of: .gridHorizontalPadding, for: .wide, resolved: resolved) == 40)
    tuning.set(.gridHorizontalPadding, to: 56, for: .wide)
    #expect(tuning.value(of: .gridHorizontalPadding, for: .wide, resolved: resolved) == 56)
    tuning.clear(.gridHorizontalPadding, for: .wide)
    #expect(tuning.value(of: .gridHorizontalPadding, for: .wide, resolved: resolved) == 40)
    #expect(tuning.overrideCount(for: .wide) == 0)
  }

  @Test func splitExpandedTokenDrivesTheSnapPositions() {
    let tuning = makeTuning()
    tuning.set(.splitExpandedPosition, to: 0.3, for: .wide)
    #expect(tuning.apply(resolved, for: .wide).splitSnapPositions == [0.3, 0.5, 1.0])
  }

  @Test func candidatesRoundTrip() {
    let tuning = makeTuning()
    tuning.set(.headerHeight, to: 88, for: .wide)
    tuning.saveCandidate("A", for: .wide)
    tuning.set(.headerHeight, to: 120, for: .wide)
    tuning.saveCandidate("B", for: .wide)
    #expect(tuning.activeCandidate[.wide] == "B")

    tuning.loadCandidate("A", for: .wide)
    #expect(tuning.apply(resolved, for: .wide).headerHeight == 88)
    #expect(tuning.activeCandidate[.wide] == "A")
    #expect(tuning.hasCandidate("B", for: .wide))
    #expect(!tuning.hasCandidate("C", for: .wide))
  }

  @Test func resetClearsOverridesButKeepsCandidates() {
    let tuning = makeTuning()
    tuning.set(.headerHeight, to: 88, for: .wide)
    tuning.saveCandidate("A", for: .wide)
    tuning.reset(.wide)
    #expect(tuning.overrideCount(for: .wide) == 0)
    #expect(tuning.activeCandidate[.wide] == nil)
    #expect(tuning.hasCandidate("A", for: .wide))
  }

  @Test func agentBlockListsOnlyChangedTokensWithTheirOldValues() {
    let tuning = makeTuning()
    tuning.set(.headerHeight, to: 88, for: .wide)
    tuning.set(.splitDefaultPosition, to: 0.38, for: .wide)
    tuning.set(.shutterBottomInset, to: 32, for: .wide)  // equals the resolver: must be omitted

    let block = tuning.agentBlock(
      for: .wide, resolved: resolved,
      stageName: "iPhone Duo · inner, landscape", stageSize: wide.size,
      hostName: "iPhone 17", hostSize: CGSize(width: 402, height: 874))

    #expect(block.contains("// Host: iPhone 17 (402×874) · Stage: iPhone Duo · inner, landscape (951×669) · Class: .wide"))
    #expect(block.contains("case .wide:"))
    #expect(block.contains("spec.headerHeight = 88"))
    #expect(block.contains("// was 100"))
    #expect(block.contains("spec.splitDefaultPosition = 0.38"))
    #expect(block.contains("// was 0.50"))
    #expect(!block.contains("shutterBottomInset"))
    #expect(block.contains("LayoutSpec.resolve(_:), case .wide"))
  }

  @Test func agentBlockSaysSoWhenNothingChanged() {
    let tuning = makeTuning()
    let block = tuning.agentBlock(
      for: .phone, resolved: LayoutSpec.resolve(LayoutPreset.iPhone17.context),
      stageName: "This device", stageSize: CGSize(width: 402, height: 874),
      hostName: "iPhone 17", hostSize: CGSize(width: 402, height: 874))
    #expect(block.contains("No changes for .phone"))
    #expect(!block.contains("case .phone:"))
  }

  @Test func tokenTableCoversEveryGroup() {
    for group in LayoutToken.Group.allCases {
      #expect(!group.tokens.isEmpty, "\(group.rawValue)")
    }
    #expect(Set(LayoutToken.Group.allCases.flatMap(\.tokens)).count == LayoutToken.allCases.count)
  }
}
