//
//  LimitedTimeOfferManager.swift
//  Joodle
//
//  Drives the per-user limited-time offer: every non-owner gets a personal
//  `windowHours` window (starting when they first become eligible) to buy the
//  discounted lifetime SKU. The window anchor is a CloudKit private-database
//  record whose server-stamped creationDate survives reinstalls and ignores
//  device-clock changes, so the countdown genuinely expires per user.
//

import CloudKit
import Combine
import Foundation
import StoreKit
import UIKit

@MainActor
final class LimitedTimeOfferManager: ObservableObject {
  static let shared = LimitedTimeOfferManager()

  /// When this user first became eligible for the offer. Server-anchored via
  /// CloudKit when possible; local-only fallback when iCloud is unavailable.
  @Published private(set) var anchorDate: Date?

  /// Identifies this offer. A future different promo gets a new ID, which
  /// means a fresh anchor record and a fresh window per user. The v2 suffix
  /// re-arms the campaign for legacy users who already burned the original
  /// promo50 window — under the claim funnel they've earned a fresh chance
  /// once their trial question is settled.
  static let offerID = "lifetime-promo50-v2"
  static let windowHours: Double = 24

  private var anchorCacheKey: String { "lto_anchor_\(Self.offerID)" }
  private let dismissedCampaignKey = "lto_dismissed_campaign_id"

  private var foregroundObserver: AnyCancellable?
  /// Single-shot timer that nudges observers at the expiry instant so the
  /// banner/sheet disappear live, not on the next interaction.
  private var expiryTimer: Timer?
  private var isResolvingAnchor = false

  private init() {
    anchorDate = UserDefaults.standard.object(forKey: anchorCacheKey) as? Date

    foregroundObserver = NotificationCenter.default
      .publisher(for: UIApplication.willEnterForegroundNotification)
      .sink { [weak self] _ in
        Task { @MainActor [weak self] in await self?.refresh() }
      }

    Task { await refresh() }
  }

  deinit {
    expiryTimer?.invalidate()
    foregroundObserver?.cancel()
  }

  // MARK: - Derived State

  var endDate: Date? {
    anchorDate?.addingTimeInterval(Self.windowHours * 3600)
  }

  /// The discounted SKU being offered.
  var promoProduct: Product? { StoreKitManager.shared.lifetimePromoProduct }

  /// The full-price SKU — its live price is the strikethrough reference.
  var fullPriceProduct: Product? { StoreKitManager.shared.lifetimeProduct }

  /// Whether the offer should currently be merchandised. Evaluated live, so
  /// it flips to false the instant the user's window closes.
  var isActive: Bool {
    // The clock only exists for users who could actually see the offer.
    guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return false }
    // Owners (subscription or lifetime) have nothing to buy.
    guard !SubscriptionManager.shared.isSubscribed else { return false }
    // The offer exists only once the trial question is settled: the claimed
    // trial ended, or the claim window lapsed unclaimed. Never mid-trial and
    // never while the claim offer is still on the table.
    guard TrialOfferManager.shared.isEligibleForPostTrialOffer else { return false }
    // Both SKUs must be purchasable/displayable right now.
    guard promoProduct != nil, fullPriceProduct != nil else { return false }
    guard let endDate, Date() < endDate else { return false }
    return true
  }

  /// Real discount derived from the two live prices (e.g. 50).
  var discountPercent: Int? {
    guard let promo = promoProduct, let full = fullPriceProduct, full.price > 0 else { return nil }
    let fraction = (full.price - promo.price) / full.price
    let percent = NSDecimalNumber(decimal: fraction * 100)
      .rounding(accordingToBehavior: NSDecimalNumberHandler(
        roundingMode: .plain, scale: 0,
        raiseOnExactness: false, raiseOnOverflow: false,
        raiseOnUnderflow: false, raiseOnDivideByZero: false
      )).intValue
    return percent > 0 ? percent : nil
  }

  var headline: String {
    if let percent = discountPercent {
      let formatted = (Double(percent) / 100).formatted(.percent)
      return String(localized: "Limited Time - \(formatted) Off")
    }
    return String(localized: "Limited Time Offer")
  }

  // MARK: - Dismissal (auto-present once per offer)

  private var dismissedCampaignId: String? {
    get { UserDefaults.standard.string(forKey: dismissedCampaignKey) }
    set { UserDefaults.standard.set(newValue, forKey: dismissedCampaignKey) }
  }

  /// Whether the offer sheet should pop up on its own. The Settings banner
  /// stays visible regardless — this only gates the one-time auto-presentation.
  var shouldAutoPresent: Bool {
    isActive && dismissedCampaignId != Self.offerID
  }

  /// Records that the user has seen the auto-presented sheet for this offer,
  /// so it won't pop again (they can still reopen it from the Settings banner).
  func markCurrentCampaignSeen() {
    dismissedCampaignId = Self.offerID
  }

  // MARK: - Refresh

  /// Ensures products are loaded and the window anchor exists for eligible
  /// users. Called on launch and on every foreground.
  func refresh() async {
    let storeManager = StoreKitManager.shared
    if storeManager.products.isEmpty {
      await storeManager.loadProducts()
    }

    // Don't start (or resolve) the clock for users who can't see the offer:
    // pre-onboarding, already an owner, the promo SKU isn't live yet, or the
    // trial question isn't settled — their window would burn out before they
    // were allowed to see it. Someone who unsubscribes later gets their
    // window from that point.
    guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
          !SubscriptionManager.shared.isSubscribed,
          TrialOfferManager.shared.isEligibleForPostTrialOffer,
          promoProduct != nil else {
      scheduleExpiry()
      return
    }

    await resolveAnchorIfNeeded()
    scheduleExpiry()
  }

  // MARK: - Anchor Resolution (CloudKit)

  private var anchorRecordID: CKRecord.ID {
    CKRecord.ID(recordName: "offerAnchor-\(Self.offerID)")
  }

  /// Resolves the window anchor, preferring the earliest date ever seen so
  /// neither a reinstall (CloudKit record survives) nor a re-fetch can extend
  /// a user's window. Falls back to a local-only anchor when iCloud is
  /// unavailable — resettable for that cohort, but never blocks the offer.
  private func resolveAnchorIfNeeded() async {
    guard !isResolvingAnchor else { return }
    isResolvingAnchor = true
    defer { isResolvingAnchor = false }

    let localAnchor = anchorDate

    do {
      let container = CKContainer.default()
      let status = try await container.accountStatus()
      guard status == .available else {
        if localAnchor == nil { setAnchor(Date()) }
        return
      }

      let database = container.privateCloudDatabase
      do {
        let record = try await database.record(for: anchorRecordID)
        let serverAnchor = record.creationDate ?? Date()
        setAnchor(min(localAnchor ?? .distantFuture, serverAnchor))
      } catch let error as CKError where error.code == .unknownItem {
        // First time on this Apple ID — create the anchor. CloudKit stamps
        // creationDate server-side, so the client never authors the time.
        // The offerID field also keeps the schema non-empty: CloudKit refuses
        // to promote a record type that has no custom fields.
        let record = CKRecord(recordType: "OfferAnchor", recordID: anchorRecordID)
        record["offerID"] = Self.offerID
        let saved = try await database.save(record)
        let serverAnchor = saved.creationDate ?? Date()
        setAnchor(min(localAnchor ?? .distantFuture, serverAnchor))
      }
    } catch {
      // Transient CloudKit/network failure: keep any local anchor; only
      // start a local window if none exists so the offer still functions.
      if localAnchor == nil { setAnchor(Date()) }
      debugPrint("🏷️ [LTO] Anchor resolution fell back to local: \(error)")
    }
  }

  private func setAnchor(_ date: Date) {
    anchorDate = date
    UserDefaults.standard.set(date, forKey: anchorCacheKey)
    scheduleExpiry()
  }

  // MARK: - Expiry

  private func scheduleExpiry() {
    expiryTimer?.invalidate()
    expiryTimer = nil

    guard let endDate else { return }
    let interval = endDate.timeIntervalSinceNow
    guard interval > 0 else {
      objectWillChange.send()
      return
    }

    expiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
      Task { @MainActor [weak self] in self?.objectWillChange.send() }
    }
  }

  // MARK: - Debug

  /// Wipes all local + CloudKit offer state, as if the user never saw it.
  /// Runtime-gated (not #if DEBUG) so the Developer console's funnel
  /// scenarios can reset the offer in TestFlight builds too.
  func debugClearAllState() {
    guard AppEnvironment.isActuallyNonProduction else { return }
    Task { try? await CKContainer.default().privateCloudDatabase.deleteRecord(withID: anchorRecordID) }
    UserDefaults.standard.removeObject(forKey: anchorCacheKey)
    dismissedCampaignId = nil
    anchorDate = nil
    expiryTimer?.invalidate()
    expiryTimer = nil
  }

  #if DEBUG
  /// Restarts a fresh window and re-arms the auto-present sheet.
  func debugRestartWindow() {
    Task { try? await CKContainer.default().privateCloudDatabase.deleteRecord(withID: anchorRecordID) }
    dismissedCampaignId = nil
    setAnchor(Date())
  }

  /// Moves the anchor so the window expires in ~2 minutes.
  func debugExpireSoon() {
    setAnchor(Date().addingTimeInterval(-Self.windowHours * 3600 + 120))
  }

  /// Clears the seen flag so the auto-present fires again on next launch.
  func debugResetSeenCampaign() {
    dismissedCampaignId = nil
  }
  #endif
}
