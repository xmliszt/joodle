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

          // Manage Subscription Button
          if subscriptionManager.isSubscribed {
            manageSubscriptionButton
          }

          // Legal info
          legalSection
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
      GlossyCrownView(isSubscribed: subscriptionManager.isSubscribed)

      if subscriptionManager.isSubscribed {
        Text("Joodle Pro")
          .font(.system(size: 28, weight: .bold))

        Text("You have full access to all features. Thank you for your support!")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)

        // Show trial, offer code, or cancellation status
        if let statusMessage = subscriptionManager.subscriptionStatusMessage {
          HStack(spacing: 6) {
            Image(systemName: statusIconName)
              .font(.caption2)
              .foregroundStyle(.appAccent)
            Text(statusMessage)
              .font(.caption)
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

      } else {
        Text("No active subscription")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
    .padding(.top, 20)
  }

  // MARK: - Current Plan Section

  private func currentPlanSection(product: Product) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Your Current Plan")
        .font(.caption)
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

  // MARK: - Manage Subscription Button

  private var manageSubscriptionButton: some View {
    VStack(spacing: 12) {
      Button(action: {
        openSubscriptionManagement()
      }) {
        HStack {
          Text(subscriptionManager.willAutoRenew ? "Manage Subscription" : "Re-subscribe")
            .font(.body)
            .foregroundColor(.primary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption)
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

      if subscriptionManager.hasRedeemedOfferCode && subscriptionManager.willAutoRenew {
        Text("Your promo code offer will automatically convert to a paid subscription on \(formatExpirationDate(subscriptionManager.subscriptionExpirationDate) ?? "the expiration date"). Cancel anytime before then to avoid charges.")
          .font(.caption2)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 32)
      } else if subscriptionManager.isInTrialPeriod && subscriptionManager.hasPendingOfferCode && subscriptionManager.willAutoRenew {
        // Trial with pending offer code - promo activates at next billing event (when trial ends)
        Text("You have a promo code applied. When your free trial ends, the promo period will activate. After the promo period ends, your subscription will convert to paid. Cancel anytime to avoid charges.")
          .font(.caption2)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 32)
      } else if subscriptionManager.isInTrialPeriod && subscriptionManager.willAutoRenew {
        Text("Your free trial will automatically convert to a paid subscription on \(formatExpirationDate(subscriptionManager.subscriptionExpirationDate) ?? "the expiration date"). Cancel anytime before then to avoid charges.")
          .font(.caption2)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 32)
      } else if !subscriptionManager.willAutoRenew {
        Text("You'll continue to have access to Joodle Pro until \(formatExpirationDate(subscriptionManager.subscriptionExpirationDate) ?? "your subscription expires"). After that, you'll lose access to all premium features. Re-subscribe to continue enjoying Joodle Pro after your current period ends.")
          .font(.caption2)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 32)
      } else {
        if let renewalDate = subscriptionManager.subscriptionExpirationDate {
          Text("Your subscription will automatically renew on \(formatExpirationDate(renewalDate) ?? "the renewal date"). Manage your subscription, change plans, or cancel anytime.")
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 32)
        } else {
          Text("Manage your subscription, change plans, or cancel anytime.")
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 32)
        }
      }
    }
  }

  // MARK: - Legal Section

  private var legalSection: some View {
    HStack(spacing: 16) {
      Link("Terms of Service", destination: URL(string: "https://liyuxuan.dev/apps/joodle/terms-of-service")!)
      Text("•")
      Link("Privacy Policy", destination: URL(string: "https://liyuxuan.dev/apps/joodle/privacy-policy")!)
    }
    .font(.caption2)
    .foregroundColor(.secondary)
    .padding(.top, 8)
  }

  // MARK: - Helper Methods

  /// Returns the appropriate badge text for the current plan
  private var currentPlanBadge: String? {
    if subscriptionManager.hasRedeemedOfferCode {
      return "PROMO CODE"
    } else if subscriptionManager.isInTrialPeriod {
      // Show promo badge if there's a pending offer code (it replaces the trial)
      if subscriptionManager.hasPendingOfferCode {
        return "PROMO APPLIED"
      }
      return "FREE TRIAL"
    }
    return nil
  }

  /// Returns the appropriate icon name for the current subscription status
  private var statusIconName: String {
    if subscriptionManager.hasRedeemedOfferCode {
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

  private func formatExpirationDateFull(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
    formatter.timeZone = TimeZone.current
    let timeZoneAbbreviation = formatter.timeZone.abbreviation() ?? TimeZone.current.identifier
    return "\(formatter.string(from: date)) (\(timeZoneAbbreviation))"
  }

  private func openSubscriptionManagement() {
    Task { @MainActor in
      do {
        // Get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes
          .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
          print("No active window scene found")
          return
        }

        try await AppStore.showManageSubscriptions(in: windowScene)

        // Refresh subscription status after the sheet is dismissed
        await refreshSubscriptionStatus()
      } catch {
        print("Failed to show manage subscriptions: \(error)")
      }
    }
  }
}

// MARK: - Glossy Crown View

struct GlossyCrownView: View {
  let isSubscribed: Bool
  @State private var shimmerOffset: CGFloat = -1.5

  var body: some View {
    Image(systemName: "crown.fill")
      .font(.system(size: 50))
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
              .font(.system(size: 50))
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

#Preview {
  NavigationStack {
    SubscriptionsView()
  }
}
