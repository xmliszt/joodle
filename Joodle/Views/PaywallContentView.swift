//
//  PaywallContentView.swift
//  Joodle
//
//  Shared paywall content component used by both PaywallView and StandalonePaywallView
//

import SwiftUI
import StoreKit

// MARK: - Configuration

/// Configuration for PaywallContentView behavior and appearance
struct PaywallConfiguration {
  /// Whether to show the "Skip Super" toggle
  var showFreeVersionToggle: Bool = false
  
  /// Whether to use onboarding-style buttons
  var useOnboardingStyle: Bool = false
  
  /// Called when a purchase is completed successfully
  var onPurchaseComplete: (() -> Void)?
  
  /// Called when user chooses to continue with free version
  var onContinueFree: (() -> Void)?
  
  /// Called when restore is successful and user has active subscription
  var onRestoreComplete: (() -> Void)?
}

// MARK: - PaywallContentView

struct PaywallContentView: View {
  let configuration: PaywallConfiguration
  
  @StateObject private var storeManager = StoreKitManager.shared
  @ObservedObject private var debugLogger = PaywallDebugLogger.shared
  
  @State private var selectedProductID: String?
  @State private var isPurchasing = false
  @State private var showError = false
  @State private var useFreeVersion = false
  
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Header Section
        headerSection
          .paywallDebugGesture()
        
        // Features Section
        featuresSection
        
        // Pricing Section
        pricingSection
        
        // CTA Section
        ctaSection
        
        // Legal Links
        legalLinksSection
      }
    }
    .alert("Error", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      if let error = storeManager.errorMessage {
        Text(error)
      }
    }
    .onAppear {
      handleOnAppear()
    }
    .onChange(of: storeManager.products) { _, newProducts in
      if selectedProductID == nil, !newProducts.isEmpty {
        selectedProductID = storeManager.yearlyProduct?.id
      }
    }
    .onChange(of: storeManager.errorMessage) { _, newValue in
      showError = newValue != nil
    }
  }
  
  // MARK: - Header Section
  
  private var headerSection: some View {
    VStack(spacing: 8) {
      Text("Get Joodle Super")
        .font(.system(size: 34, weight: .bold))
        .multilineTextAlignment(.center)
      
      Text("Supercharge your creativity with unlimited doodles and more!")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    .padding(.top, 24)
    .padding(.horizontal, 8)
  }
  
  // MARK: - Features Section
  
  private var featuresSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      FeatureRow(
        icon: "scribble.variable",
        title: "Unlimited Doodles",
        subtitle: "Draw as many as you want, no limits"
      )
      
      FeatureRow(
        icon: "square.grid.3x3.fill",
        title: "Widgets",
        subtitle: "Access to all Joodle widgets"
      )
      
      FeatureRow(
        icon: "checkmark.icloud.fill",
        title: "iCloud Sync",
        subtitle: "Sync across all your devices"
      )
      
      // TODO: Unhide when share templates feature is ready
      // FeatureRow(
      //     icon: "square.and.arrow.up.fill",
      //     title: "More share templates",
      //     subtitle: "Beautiful templates for sharing"
      // )
    }
    .padding()
  }
  
  // MARK: - Pricing Section
  
  private var pricingSection: some View {
    VStack(spacing: 16) {
      if storeManager.products.isEmpty {
        emptyProductsView
      } else {
        productCards
      }
    }
    .padding(.horizontal, 24)
  }
  
  private var emptyProductsView: some View {
    VStack(spacing: 12) {
      Text("Unable to load plans")
        .foregroundColor(.secondary)
      
      Text("Please check your internet connection and try again.")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
      
      Button {
        Task {
          await storeManager.loadProducts()
        }
      } label: {
        Label("Retry", systemImage: "arrow.clockwise")
          .font(.subheadline)
      }
      .buttonStyle(.bordered)
      
      // Debug info - shown when debug mode is enabled or in DEBUG builds
      if shouldShowDebugInfo {
        debugInfoView
      }
    }
    .padding(.vertical, 40)
  }
  
  private var shouldShowDebugInfo: Bool {
#if DEBUG
    return true
#else
    return debugLogger.isDebugModeEnabled
#endif
  }
  
  private var debugInfoView: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Debug Info:")
        .font(.caption2.bold())
      Text("Product IDs: dev.liyuxuan.joodle.super.monthly, dev.liyuxuan.joodle.super.yearly")
        .font(.caption2)
      if let error = storeManager.errorMessage {
        Text("Error: \(error)")
          .font(.caption2)
          .foregroundColor(.red)
      }
      
      Text("Tap header 3x for full debug view")
        .font(.caption2)
        .foregroundColor(.blue)
    }
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
    .padding(.top, 8)
  }
  
  private var productCards: some View {
    VStack(spacing: 16) {
      if let yearly = storeManager.yearlyProduct {
        PricingCard(
          product: yearly,
          isSelected: selectedProductID == yearly.id,
          badge: savingsBadgeText(),
          onSelect: {
            selectedProductID = yearly.id
          }
        )
      }
      
      if let monthly = storeManager.monthlyProduct {
        PricingCard(
          product: monthly,
          isSelected: selectedProductID == monthly.id,
          badge: nil,
          onSelect: {
            selectedProductID = monthly.id
          }
        )
      }
    }
  }
  
  // MARK: - CTA Section
  
  private var ctaSection: some View {
    VStack(spacing: 16) {
      // Toggle for free version (conditionally shown)
      if configuration.showFreeVersionToggle {
        Toggle(isOn: $useFreeVersion) {
          Text("Skip Super")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .tint(.accent)
        .frame(width: 150)
        .padding(.horizontal, 48)
      }
      
      VStack(spacing: 4) {
        // Main CTA Button
        mainCTAButton
        
        // Price disclaimer
        if !useFreeVersion,
           let selectedID = selectedProductID,
           let product = storeManager.products.first(where: { $0.id == selectedID }) {
          Text("Then \(product.displayPrice) / \(product.id.contains("monthly") ? "month" : "year"). Cancel anytime.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
      }
      
      // Restore Purchases
      restorePurchasesButton
    }
    .padding(.horizontal, 24)
  }
  
  @ViewBuilder
  private var mainCTAButton: some View {
    if let selectedID = selectedProductID,
       let product = storeManager.products.first(where: { $0.id == selectedID }) {
      if useFreeVersion {
        continueForFreeButton
      } else {
        purchaseButton(for: product)
      }
    } else {
      if useFreeVersion {
        continueForFreeButton
      } else {
        selectPlanButton
      }
    }
  }
  
  private var continueForFreeButton: some View {
    Group {
      if configuration.useOnboardingStyle {
        Button {
          configuration.onContinueFree?()
        } label: {
          Text("Continue for free")
            .font(.headline)
        }
        .buttonStyle(OnboardingSecondaryButtonStyle())
      } else {
        Button {
          configuration.onContinueFree?()
        } label: {
          Text("Continue for free")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.secondary.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(16)
        }
      }
    }
  }
  
  private func purchaseButton(for product: Product) -> some View {
    Group {
      if configuration.useOnboardingStyle {
        Button {
          handlePurchase(product)
        } label: {
          HStack {
            if isPurchasing {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
              Text("Start 7-Day Free Trial")
                .font(.headline)
            }
          }
        }
        .buttonStyle(OnboardingButtonStyle())
        .disabled(isPurchasing)
      } else {
        Button {
          handlePurchase(product)
        } label: {
          HStack {
            if isPurchasing {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
              Text("Start 7-Day Free Trial")
                .font(.headline)
            }
          }
        }
        .buttonStyle(OnboardingButtonStyle())
        .disabled(isPurchasing)
      }
    }
  }
  
  private var selectPlanButton: some View {
    Group {
      if configuration.useOnboardingStyle {
        Button {
          if let yearly = storeManager.yearlyProduct {
            selectedProductID = yearly.id
          }
        } label: {
          Text("Select a Plan")
            .font(.headline)
        }
        .buttonStyle(OnboardingButtonStyle())
      } else {
        Button {
          if let yearly = storeManager.yearlyProduct {
            selectedProductID = yearly.id
          }
        } label: {
          Text("Select a Plan")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accent)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
      }
    }
  }
  
  private var restorePurchasesButton: some View {
    Button {
      Task {
        await storeManager.restorePurchases()
        if storeManager.hasActiveSubscription {
          configuration.onRestoreComplete?()
        }
      }
    } label: {
      Text("Restore Purchases")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }
  
  // MARK: - Legal Links Section
  
  private var legalLinksSection: some View {
    HStack(spacing: 16) {
      Link("Terms of Service", destination: URL(string: "https://joodle.liyuxuan.dev/terms-of-service")!)
      Text("•")
      Link("Privacy Policy", destination: URL(string: "https://joodle.liyuxuan.dev/privacy-policy")!)
    }
    .font(.caption2)
    .foregroundColor(.secondary)
    .padding(.bottom, 20)
  }
  
  // MARK: - Helper Methods
  
  private func handleOnAppear() {
    debugLogger.log(.info, "PaywallContentView appeared")
    debugLogger.log(.debug, "Products count: \(storeManager.products.count)")
    
    if selectedProductID == nil, !storeManager.products.isEmpty {
      selectedProductID = storeManager.yearlyProduct?.id
    }
    
    if storeManager.products.isEmpty && !storeManager.isLoading {
      debugLogger.log(.warning, "No products loaded, attempting reload")
      Task {
        await storeManager.loadProducts()
      }
    }
  }
  
  private func handlePurchase(_ product: Product) {
    isPurchasing = true
    
    Task {
      do {
        let transaction = try await storeManager.purchase(product)
        
        if transaction != nil {
          configuration.onPurchaseComplete?()
        }
      } catch {
        debugLogger.logPurchaseFailed(productID: product.id, error: error)
      }
      
      isPurchasing = false
    }
  }
  
  private func savingsBadgeText() -> String? {
    if let percentage = storeManager.savingsPercentage() {
      return "SAVE \(percentage)%"
    }
    return "BEST VALUE"
  }
}

// MARK: - Preview

#Preview("Default Style") {
  PaywallContentView(configuration: PaywallConfiguration(
    showFreeVersionToggle: false,
    useOnboardingStyle: false
  ))
}

#Preview("Onboarding Style") {
  PaywallContentView(configuration: PaywallConfiguration(
    showFreeVersionToggle: true,
    useOnboardingStyle: true
  ))
}
