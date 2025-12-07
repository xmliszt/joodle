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
  @StateObject private var storeManager = StoreKitManager.shared
  @StateObject private var subscriptionManager = SubscriptionManager.shared
  @State private var currentProduct: Product?
  
  var body: some View {
    ZStack {
      ScrollView {
        VStack(spacing: 24) {
          // Header
          headerSection
          
          // Current Plan Card (if subscribed)
          if let product = currentProduct {
            currentPlanSection(product: product)
          }
          
          // Manage Subscription Button
          if subscriptionManager.isSubscribed  {
            manageSubscriptionButton
          }
          
          // Legal info
          legalSection
        }
        .padding(.vertical, 20)
        .padding(.bottom, 40)
      }
      
      if storeManager.isLoading {
        Color.black.opacity(0.3)
          .ignoresSafeArea()
        ProgressView()
          .scaleEffect(1.5)
      }
    }
    .navigationTitle("Joodle Super")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      detectCurrentProduct()
      Task {
        await storeManager.updatePurchasedProducts()
        await subscriptionManager.updateSubscriptionStatus()
        detectCurrentProduct()
      }
    }
  }
  
  // MARK: - Header Section
  
  private var headerSection: some View {
    VStack(spacing: 12) {
      Image(systemName: "crown.fill")
        .font(.system(size: 50))
        .foregroundColor(subscriptionManager.isSubscribed ? .accent : .appBorder)
      
      
      if subscriptionManager.isSubscribed {
        Text("Joodle Super")
          .font(.system(size: 28, weight: .bold))
        
        Text("You have full access to all premium features. Thank you for your support!")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
        
        // Show trial or cancellation status
        if let statusMessage = subscriptionManager.subscriptionStatusMessage {
          HStack(spacing: 6) {
            Image(systemName: subscriptionManager.isInTrialPeriod ? "clock.fill" : "exclamationmark.triangle.fill")
              .font(.caption2)
              .foregroundStyle(.accent)
            Text(statusMessage)
              .font(.caption)
          }
          .foregroundColor(.secondary)
          .padding(.horizontal, 20)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
              .fill(.accent.opacity(0.1))
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
        badge: subscriptionManager.isInTrialPeriod ? "FREE TRIAL" : nil,
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
      
      if subscriptionManager.isInTrialPeriod {
        Text("Your free trial will automatically convert to a paid subscription on \(subscriptionManager.subscriptionExpirationDate?.formatted(date: .long, time: .omitted) ?? "the expiration date"). Cancel anytime before then to avoid charges.")
          .font(.caption2)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
          .padding(.horizontal, 32)
      } else if !subscriptionManager.willAutoRenew {
        Text("You'll continue to have access to Joodle Super until \(subscriptionManager.subscriptionExpirationDate?.formatted(date: .long, time: .omitted) ?? "your subscription expires"). After that, you'll lose access to all premium features. Re-subscribe to continue enjoying Joodle Super after your current period ends.")
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
  
  // MARK: - Legal Section
  
  private var legalSection: some View {
    HStack(spacing: 16) {
      Link("Terms of Service", destination: URL(string: "https://joodle.liyuxuan.dev/terms-of-service")!)
      Text("•")
      Link("Privacy Policy", destination: URL(string: "https://joodle.liyuxuan.dev/privacy-policy")!)
    }
    .font(.caption2)
    .foregroundColor(.secondary)
    .padding(.top, 8)
  }
  
  // MARK: - Helper Methods
  
  private func detectCurrentProduct() {
    // Find which product the user is currently subscribed to
    for productID in storeManager.purchasedProductIDs {
      if let product = storeManager.products.first(where: { $0.id == productID }) {
        currentProduct = product
        return
      }
    }
    currentProduct = nil
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
      } catch {
        print("Failed to show manage subscriptions: \(error)")
      }
    }
  }
}

#Preview {
  NavigationStack {
    SubscriptionsView()
  }
}
