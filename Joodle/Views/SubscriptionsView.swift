//
//  SubscriptionsView.swift
//  Joodle
//
//  Created by Subscriptions View
//

import SwiftUI
import StoreKit

struct SubscriptionsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var storeManager = StoreKitManager.shared
  @StateObject private var subscriptionManager = SubscriptionManager.shared
  @State private var subscriptionGroupID: String?
  @State private var showRedeemCode = false
  @State private var showManagePlanSheet = false

  /// The current product comes directly from StoreKitManager for accuracy
  private var currentProduct: Product? {
    storeManager.currentProduct
  }

  var body: some View {
    ZStack {
      ScrollView {
        VStack(spacing: 24) {
          // Header
          headerSection

          // Current Plan Card (if subscribed and we know the product)
          if let product = currentProduct {
            currentPlanSection(product: product)
          }

          // Pending plan change banner
          if let pendingProductID = subscriptionManager.pendingPlanProductID,
             let pendingProduct = storeManager.products.first(where: { $0.id == pendingProductID }) {
            pendingPlanChangeBanner(newProduct: pendingProduct)
          }

          // Manage Subscription Button (show for all subscribed users including lifetime)
          if subscriptionManager.isSubscribed {
            manageSubscriptionButton
          }

          // Legal info
          legalLinksSection
        }
        .padding(.vertical, 20)
        .padding(.bottom, 40)
      }
    }
    .refreshable {
      await refreshSubscriptionStatus()
    }
    .navigationTitle("Joodle Pro")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      Task {
        await refreshSubscriptionStatus()
      }
    }
    .onChange(of: scenePhase) { oldPhase, newPhase in
      if newPhase == .active {
        // Refresh subscription status when returning from system subscription management
        Task {
          await refreshSubscriptionStatus()
        }
      }
    }
    .task {
      // Get the subscription group ID from any subscription product
      await loadSubscriptionGroupID()
    }
    .subscriptionStatusTask(for: subscriptionGroupID ?? "") { taskState in
      // This fires whenever subscription status changes, regardless of how sheet is dismissed
      guard subscriptionGroupID != nil else { return }

      Task {
        await refreshSubscriptionStatus()
      }
    }
    .offerCodeRedemption(isPresented: $showRedeemCode) { _ in
      Task {
        await storeManager.updatePurchasedProducts()
        await subscriptionManager.updateSubscriptionStatus()
      }
    }
  }

  // MARK: - Refresh Subscription Status

  /// Refreshes subscription status from StoreKit
  /// - Parameter forceSync: If true, calls AppStore.sync() to force sync with App Store servers.
  ///   Only use for manual "Restore Purchase" - it triggers Apple ID sign-in prompts.
  private func refreshSubscriptionStatus(forceSync: Bool = false) async {
    if forceSync {
      // Only call AppStore.sync() for manual restore - it triggers sign-in prompts
      do {
        try await AppStore.sync()
      } catch {
        print("AppStore.sync failed: \(error)")
      }
    }

    await subscriptionManager.updateSubscriptionStatus()
  }

  // MARK: - Load Subscription Group ID

  private func loadSubscriptionGroupID() async {
    // Get the subscription group ID from the first subscription product
    for product in storeManager.products {
      if let subscription = product.subscription {
        subscriptionGroupID = subscription.subscriptionGroupID
        return
      }
    }

    // If products aren't loaded yet, wait and try again
    if storeManager.products.isEmpty {
      await storeManager.loadProducts()
      for product in storeManager.products {
        if let subscription = product.subscription {
          subscriptionGroupID = subscription.subscriptionGroupID
          return
        }
      }
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 12) {
      GlossyCrownView(isSubscribed: subscriptionManager.hasPremiumAccess)

      if subscriptionManager.hasPremiumAccess && !GracePeriodManager.shared.isInGracePeriod {
        Text("Joodle Pro")
          .font(.appFont(size: 28, weight: .bold))

        if subscriptionManager.isLifetimeUser {
          Text("You own Joodle Pro forever. Thank you for your support!")
            .font(.appSubheadline())
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        } else {
          Text("You have full access to all features. Thank you for your support!")
            .font(.appSubheadline())
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }

        // Show trial, offer code, or cancellation status
        if let statusMessage = subscriptionManager.subscriptionStatusMessage {
          HStack(spacing: 6) {
            Image(systemName: statusIconName)
              .font(.appCaption2())
              .foregroundStyle(.appAccent)
            Text(statusMessage)
              .font(.appCaption())
          }
          .foregroundColor(.secondary)
          .padding(.horizontal, 20)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
              .fill(.appAccent.opacity(0.1))
          )
          .padding(.top, 8)
        }

      } else if GracePeriodManager.shared.isInGracePeriod {
        Text("Joodle Pro")
          .font(.appFont(size: 28, weight: .bold))

        let daysLeft = GracePeriodManager.shared.gracePeriodDaysRemaining
        Text("You have free access to all Pro features for \(daysLeft) more day\(daysLeft == 1 ? "" : "s").")
          .font(.appSubheadline())
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)

        HStack(spacing: 6) {
          Image(systemName: "clock.fill")
            .font(.appCaption2())
            .foregroundStyle(.appAccent)
          Text("Free access · \(daysLeft) day\(daysLeft == 1 ? "" : "s") left")
            .font(.appCaption())
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(.appAccent.opacity(0.1))
        )
        .padding(.top, 8)

      } else {
        Text("No active subscription")
          .font(.appSubheadline())
          .foregroundColor(.secondary)
      }
    }
    .padding(.top, 20)
  }

  // MARK: - Current Plan Section

  private func currentPlanSection(product: Product) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Your Current Plan")
        .font(.appCaption())
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)

      PricingCard(
        product: product,
        isSelected: true,
        badge: currentPlanBadge,
        isEligibleForIntroOffer: storeManager.isEligibleForIntroOffer,
        onSelect: {}
      )
      .padding(.horizontal, 20)
    }
  }

  // MARK: - Pending Plan Change Banner

  private func pendingPlanChangeBanner(newProduct: Product) -> some View {
    VStack(spacing: 8) {
      HStack(spacing: 10) {
        Image(systemName: "arrow.triangle.2.circlepath")
          .font(.appBody())
          .foregroundStyle(.appAccent)

        VStack(alignment: .leading, spacing: 3) {
          Text("Plan change scheduled")
            .font(.appCaption(weight: .medium))
            .foregroundColor(.primary)

          if let expirationDate = subscriptionManager.subscriptionExpirationDate {
            Text("Switching to \(newProduct.displayName) (\(newProduct.displayPrice)) on \(formatExpirationDateShort(expirationDate))")
              .font(.appCaption2())
              .foregroundColor(.secondary)
          } else {
            Text("Switching to \(newProduct.displayName) (\(newProduct.displayPrice)) at next renewal")
              .font(.appCaption2())
              .foregroundColor(.secondary)
          }
        }

        Spacer()
      }
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(.appAccent.opacity(0.08))
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .strokeBorder(.appAccent.opacity(0.2), lineWidth: 1)
          )
      )
    }
    .padding(.horizontal, 20)
  }

  private func formatExpirationDateShort(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  // MARK: - Manage Subscription Button

  /// Returns the appropriate label for the manage button based on subscription state
  private var manageButtonLabel: String {
    if subscriptionManager.willAutoRenew {
      return "Manage Subscription"
    } else {
      return "View All Plans"
    }
  }

  private var manageSubscriptionButton: some View {
    VStack(spacing: 12) {
      Button(action: {
        showManagePlanSheet = true
      }) {
        HStack {
          Text(manageButtonLabel)
            .font(.appBody())
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.appCaption())
            .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
          RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(.appBorder.opacity(0.3))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
      }
      .padding(.horizontal, 20)
      .sheet(isPresented: $showManagePlanSheet) {
        ManagePlanSheet()
      }

      if subscriptionManager.isLifetimeUser {
        // No disclaimer needed for lifetime users
      } else if subscriptionManager.hasRedeemedOfferCode && subscriptionManager.willAutoRenew {
        Text(pricingDisclaimerText(for: currentProduct, scenario: .promoCode))
          .font(.appCaption2())
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 32)
      } else if subscriptionManager.isInTrialPeriod && subscriptionManager.hasPendingOfferCode && subscriptionManager.willAutoRenew {
        // Trial with pending offer code - promo activates at next billing event (when trial ends)
        Text(pricingDisclaimerText(for: currentProduct, scenario: .trialWithPromo))
          .font(.appCaption2())
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 32)
      } else if subscriptionManager.isInTrialPeriod && subscriptionManager.willAutoRenew {
        Text(pricingDisclaimerText(for: currentProduct, scenario: .trial))
          .font(.appCaption2())
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 32)
      } else if !subscriptionManager.willAutoRenew {
        Text("You'll continue to have access to Joodle Pro until \(formatExpirationDate(subscriptionManager.subscriptionExpirationDate) ?? "your subscription expires"). After that, you'll lose access to all premium features. Re-subscribe to continue enjoying Joodle Pro after your current period ends.")
          .font(.appCaption2())
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 32)
      } else {
        if let renewalDate = subscriptionManager.subscriptionExpirationDate {
          Text("Your subscription will automatically renew on \(formatExpirationDate(renewalDate) ?? "the renewal date"). Manage your subscription, change plans, or cancel anytime.")
            .font(.appCaption2())
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 32)
        } else {
          Text("Manage your subscription, change plans, or cancel anytime.")
            .font(.appCaption2())
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 32)
        }
      }
    }
  }

  // MARK: - Legal Section
 
  private var legalLinksSection: some View {
    HStack(spacing: 0) {
      // Restore Purchases
      Button {
        Task {
          await storeManager.restorePurchases()
          await subscriptionManager.updateSubscriptionStatus()
        }
      } label: {
        Text("Restore Purchases")
          .font(.appCaption())
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      // Terms
      Link("Terms", destination: URL(string: "https://liyuxuan.dev/apps/joodle/terms-of-service")!)
        .font(.appCaption())
        .foregroundColor(.secondary)
      
      Spacer()
      
      // Privacy
      Link("Privacy", destination: URL(string: "https://liyuxuan.dev/apps/joodle/privacy-policy")!)
        .font(.appCaption())
        .foregroundColor(.secondary)
      
      Spacer()
      
      // Redeem
      Button {
        showRedeemCode = true
      } label: {
        Text("Redeem")
          .font(.appCaption())
          .foregroundColor(.secondary)
      }
    }
    .padding(.horizontal, 32)
    .padding(.bottom, 20)
  }

  // MARK: - Helper Methods

  /// Returns the appropriate badge text for the current plan
  private var currentPlanBadge: String? {
    if subscriptionManager.isLifetimeUser {
      return "LIFETIME"
    } else if subscriptionManager.hasRedeemedOfferCode {
      return "PROMO CODE"
    } else if subscriptionManager.isInTrialPeriod {
      // Show promo badge if there's a pending offer code (it replaces the trial)
      if subscriptionManager.hasPendingOfferCode {
        return "PROMO APPLIED"
      }
      return "FREE TRIAL"
    } else if GracePeriodManager.shared.isInGracePeriod {
      return "FREE ACCESS"
    }
    return nil
  }

  /// Returns the appropriate icon name for the current subscription status
  private var statusIconName: String {
    if subscriptionManager.isLifetimeUser {
      return "infinity"
    } else if subscriptionManager.hasRedeemedOfferCode {
      return "ticket.fill"
    } else if subscriptionManager.isInTrialPeriod {
      // Show ticket icon if there's also a pending offer code
      if subscriptionManager.hasPendingOfferCode {
        return "gift.fill"
      }
      return "clock.fill"
    } else {
      return "exclamationmark.triangle.fill"
    }
  }

  private func formatExpirationDate(_ date: Date?) -> String? {
    guard let date = date else { return nil }
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .short
    formatter.timeZone = TimeZone.current
    let timeZoneAbbreviation = formatter.timeZone.abbreviation() ?? ""
    return "\(formatter.string(from: date)) (\(timeZoneAbbreviation))"
  }

  private enum PricingScenario {
    case promoCode
    case trialWithPromo
    case trial
  }

  private func pricingDisclaimerText(for product: Product?, scenario: PricingScenario) -> String {
    guard let product = product else {
      // Fallback if product is unavailable
      switch scenario {
      case .promoCode:
        return "Your promo code offer will automatically convert to a paid subscription on \(formatExpirationDate(subscriptionManager.subscriptionExpirationDate) ?? "the expiration date"). Cancel anytime before then to avoid charges."
      case .trialWithPromo:
        return "You have a promo code applied. When your free trial ends, the promo period will activate. After the promo period ends, your subscription will convert to paid. Cancel anytime to avoid charges."
      case .trial:
        return "Your free trial will automatically convert to a paid subscription on \(formatExpirationDate(subscriptionManager.subscriptionExpirationDate) ?? "the expiration date"). Cancel anytime before then to avoid charges."
      }
    }

    let billingPeriod = product.id.contains("monthly") ? "month" : "year"
    let price = product.displayPrice

    switch scenario {
    case .promoCode:
      return "Your promo code offer will automatically convert to a paid subscription on \(formatExpirationDate(subscriptionManager.subscriptionExpirationDate) ?? "the expiration date"). After the promo period ends, your subscription will charge \(price) / \(billingPeriod). Cancel anytime before then to avoid charges."
    case .trialWithPromo:
      return "You have a promo code applied. When your free trial ends, the promo period will activate. After the promo period ends, your subscription will charge \(price) / \(billingPeriod). Cancel anytime to avoid charges."
    case .trial:
      return "Your free trial will automatically convert to a paid subscription on \(formatExpirationDate(subscriptionManager.subscriptionExpirationDate) ?? "the expiration date"). After the free trial period ends, your subscription will charge \(price) / \(billingPeriod). Cancel anytime before then to avoid charges."
    }
  }

  private func formatExpirationDateFull(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
    formatter.timeZone = TimeZone.current
    let timeZoneAbbreviation = formatter.timeZone.abbreviation() ?? TimeZone.current.identifier
    return "\(formatter.string(from: date)) (\(timeZoneAbbreviation))"
  }


}

// MARK: - Glossy Crown View

struct GlossyCrownView: View {
  let isSubscribed: Bool
  @State private var shimmerOffset: CGFloat = -1.5

  var body: some View {
    Image(systemName: "crown.fill")
      .font(.appFont(size: 50))
      .foregroundColor(isSubscribed ? .appAccent : .appBorder)
      .overlay {
        if isSubscribed {
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .white.opacity(0.5), location: 0.3),
              .init(color: .white.opacity(0.8), location: 0.5),
              .init(color: .white.opacity(0.5), location: 0.7),
              .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
          .frame(width: 30)
          .offset(x: shimmerOffset * 50)
          .blur(radius: 2)
          .mask {
            Image(systemName: "crown.fill")
              .font(.appFont(size: 50))
          }
        }
      }
      .onAppear {
        if isSubscribed {
          withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: false)
            .delay(0.5)
          ) {
            shimmerOffset = 1.5
          }
        }
      }
      .onChange(of: isSubscribed) { _, newValue in
        if newValue {
          shimmerOffset = -1.5
          withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: false)
            .delay(0.5)
          ) {
            shimmerOffset = 1.5
          }
        }
      }
  }
}

#if DEBUG
#Preview("Lifetime User") {
  NavigationStack {
    SubscriptionsView()
      .task {
        SubscriptionManager.shared.configureForPreview(
          subscribed: true,
          lifetime: true,
          productID: "dev.liyuxuan.joodle.pro.lifetime"
        )
        await SubscriptionManager.shared.loadProductsForPreview()
      }
  }
}

#Preview("Active Subscription") {
  NavigationStack {
    SubscriptionsView()
      .task {
        SubscriptionManager.shared.configureForPreview(
          subscribed: true,
          autoRenew: true,
          expiration: Date().addingTimeInterval(60 * 60 * 24 * 30),
          productID: "dev.liyuxuan.joodle.pro.yearly"
        )
        await SubscriptionManager.shared.loadProductsForPreview()
      }
  }
}

#Preview("Free Trial") {
  NavigationStack {
    SubscriptionsView()
      .task {
        SubscriptionManager.shared.configureForPreview(
          subscribed: true,
          trial: true,
          autoRenew: true,
          expiration: Date().addingTimeInterval(60 * 60 * 24 * 7),
          productID: "dev.liyuxuan.joodle.pro.yearly"
        )
        await SubscriptionManager.shared.loadProductsForPreview()
      }
  }
}

#Preview("Trial + Pending Promo") {
  NavigationStack {
    SubscriptionsView()
      .task {
        SubscriptionManager.shared.configureForPreview(
          subscribed: true,
          trial: true,
          autoRenew: true,
          pendingOfferCode: true,
          expiration: Date().addingTimeInterval(60 * 60 * 24 * 7),
          productID: "dev.liyuxuan.joodle.pro.yearly"
        )
        await SubscriptionManager.shared.loadProductsForPreview()
      }
  }
}

#Preview("Promo Code Active") {
  NavigationStack {
    SubscriptionsView()
      .task {
        SubscriptionManager.shared.configureForPreview(
          subscribed: true,
          autoRenew: true,
          offerCode: true,
          expiration: Date().addingTimeInterval(60 * 60 * 24 * 30),
          productID: "dev.liyuxuan.joodle.pro.yearly"
        )
        await SubscriptionManager.shared.loadProductsForPreview()
      }
  }
}

#Preview("Cancelled (Expiring)") {
  NavigationStack {
    SubscriptionsView()
      .task {
        SubscriptionManager.shared.configureForPreview(
          subscribed: true,
          autoRenew: false,
          expiration: Date().addingTimeInterval(60 * 60 * 24 * 5),
          productID: "dev.liyuxuan.joodle.pro.yearly"
        )
        await SubscriptionManager.shared.loadProductsForPreview()
      }
  }
}

#Preview("Plan Change Pending") {
  NavigationStack {
    SubscriptionsView()
      .task {
        SubscriptionManager.shared.configureForPreview(
          subscribed: true,
          autoRenew: true,
          pendingPlanProductID: "dev.liyuxuan.joodle.pro.monthly",
          expiration: Date().addingTimeInterval(60 * 60 * 24 * 30),
          productID: "dev.liyuxuan.joodle.pro.yearly"
        )
        await SubscriptionManager.shared.loadProductsForPreview()
      }
  }
}

#Preview("Not Subscribed") {
  NavigationStack {
    SubscriptionsView()
      .task {
        SubscriptionManager.shared.configureForPreview()
        await SubscriptionManager.shared.loadProductsForPreview()
      }
  }
}
#endif
