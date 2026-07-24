//
//  TrialOfferFunnelTests.swift
//  JoodleTests
//
//  Unit tests for the claim-based trial funnel: phase resolution
//  (TrialOfferManager.resolvePhase) and free-limit grandfathering
//  (SubscriptionManager.resolveFreeJoodleLimit). Both are pure functions,
//  so no singletons, UserDefaults, or clocks are touched.
//

import Testing
import Foundation
@testable import Joodle

struct TrialOfferFunnelTests {

  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let day: TimeInterval = 24 * 60 * 60

  private func snapshot(
    isSubscribed: Bool = false,
    isLegacyInstall: Bool = false,
    legacyGraceActive: Bool = false,
    claimedTrialStart: Date? = nil,
    claimWindowEnd: Date? = nil,
    doodleCount: Int = 0,
    freeLimit: Int = 7
  ) -> TrialFunnelSnapshot {
    TrialFunnelSnapshot(
      isSubscribed: isSubscribed,
      isLegacyInstall: isLegacyInstall,
      legacyGraceActive: legacyGraceActive,
      claimedTrialStart: claimedTrialStart,
      claimWindowEnd: claimWindowEnd,
      doodleCount: doodleCount,
      freeLimit: freeLimit,
      now: now
    )
  }

  // MARK: - New installs

  @Test func newInstallUnderLimitIsDormant() {
    let phase = TrialOfferManager.resolvePhase(snapshot(doodleCount: 6))
    #expect(phase == .dormant)
  }

  @Test func newInstallAtLimitGetsOffer() {
    let phase = TrialOfferManager.resolvePhase(snapshot(doodleCount: 7))
    #expect(phase == .offerAvailable)
  }

  @Test func newInstallPastLimitGetsOffer() {
    let phase = TrialOfferManager.resolvePhase(snapshot(doodleCount: 12))
    #expect(phase == .offerAvailable)
  }

  // MARK: - Legacy installs (winback)

  @Test func legacyInstallGetsWinbackOfferRegardlessOfCount() {
    let phase = TrialOfferManager.resolvePhase(
      snapshot(isLegacyInstall: true, doodleCount: 0, freeLimit: 30)
    )
    #expect(phase == .offerAvailable)
  }

  @Test func legacyInstallMidAutoTrialIsTrialActiveNotOffer() {
    let phase = TrialOfferManager.resolvePhase(
      snapshot(isLegacyInstall: true, legacyGraceActive: true)
    )
    #expect(phase == .trialActive)
  }

  @Test func legacyInstallCanRunClaimedSecondTrial() {
    let phase = TrialOfferManager.resolvePhase(
      snapshot(isLegacyInstall: true, claimedTrialStart: now.addingTimeInterval(-2 * day))
    )
    #expect(phase == .trialActive)
  }

  // MARK: - Claim window

  @Test func openClaimWindowReportsEndDate() {
    let end = now.addingTimeInterval(2 * day)
    let phase = TrialOfferManager.resolvePhase(
      snapshot(claimWindowEnd: end, doodleCount: 7)
    )
    #expect(phase == .claimWindow(end: end))
  }

  @Test func lapsedClaimWindowIsOfferExpired() {
    let phase = TrialOfferManager.resolvePhase(
      snapshot(claimWindowEnd: now.addingTimeInterval(-1), doodleCount: 7)
    )
    #expect(phase == .postTrial(reason: .offerExpired))
  }

  @Test func claimedTrialOutranksLapsedClaimWindow() {
    // Claiming in the window's final minutes must not resurface as
    // "offer expired" once the window's end date passes.
    let phase = TrialOfferManager.resolvePhase(
      snapshot(
        claimedTrialStart: now.addingTimeInterval(-1 * day),
        claimWindowEnd: now.addingTimeInterval(-0.5 * day)
      )
    )
    #expect(phase == .trialActive)
  }

  // MARK: - Claimed trial lifecycle

  @Test func claimedTrialWithinSevenDaysIsActive() {
    let phase = TrialOfferManager.resolvePhase(
      snapshot(claimedTrialStart: now.addingTimeInterval(-6.9 * day))
    )
    #expect(phase == .trialActive)
  }

  @Test func claimedTrialAfterSevenDaysIsTrialEnded() {
    let phase = TrialOfferManager.resolvePhase(
      snapshot(claimedTrialStart: now.addingTimeInterval(-7.1 * day))
    )
    #expect(phase == .postTrial(reason: .trialEnded))
  }

  // MARK: - Subscribers

  @Test func subscriberIsConvertedRegardlessOfEverythingElse() {
    let phase = TrialOfferManager.resolvePhase(
      snapshot(
        isSubscribed: true,
        isLegacyInstall: true,
        claimedTrialStart: now.addingTimeInterval(-30 * day),
        claimWindowEnd: now.addingTimeInterval(-20 * day),
        doodleCount: 100
      )
    )
    #expect(phase == .converted)
  }

  // MARK: - Free limit grandfathering

  @Test func storedLimitAlwaysWins() {
    #expect(SubscriptionManager.resolveFreeJoodleLimit(storedLimit: 30, legacyGraceExists: false) == 30)
    #expect(SubscriptionManager.resolveFreeJoodleLimit(storedLimit: 7, legacyGraceExists: true) == 7)
  }

  @Test func unmigratedLegacyInstallDefaultsToThirty() {
    #expect(SubscriptionManager.resolveFreeJoodleLimit(storedLimit: 0, legacyGraceExists: true)
            == SubscriptionManager.legacyFreeJoodlesAllowed)
  }

  @Test func unmigratedFreshInstallDefaultsToSeven() {
    #expect(SubscriptionManager.resolveFreeJoodleLimit(storedLimit: 0, legacyGraceExists: false)
            == SubscriptionManager.baseFreeJoodlesAllowed)
  }
}
