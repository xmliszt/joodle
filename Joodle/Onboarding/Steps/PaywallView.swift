//
//  PaywallView.swift
//  Joodle
//
//  Created by Paywall View
//

import SwiftUI
import StoreKit

struct PaywallView: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @StateObject private var storeManager = StoreKitManager.shared
  @State private var selectedProductID: String? = nil
  @State private var isPurchasing = false
  @State private var showError = false
  @State private var useFreeVersion = false

  var body: some View {
    ZStack {
      ScrollView {
        VStack(spacing: 20) {
          // Header Section
          VStack(spacing: 8) {
            Text("Get Joodle Super")
              .font(.system(size: 34, weight: .bold))
              .multilineTextAlignment(.center)

            Text("Unleash your creativity with unlimited features")
              .font(.body)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
          .padding(.top, 24)
          .padding(.horizontal, 8)

          // Features Section
          VStack(alignment: .leading, spacing: 16) {
            FeatureRow(
              icon: "scribble.variable",
              title: "Unlimited doodles",
              description: "Draw as much as you want, no limits"
            )

            FeatureRow(
              icon: "square.grid.3x3.fill",
              title: "More widget options",
              description: "Access all exclusive widgets"
            )

            FeatureRow(
              icon: "checkmark.icloud.fill",
              title: "iCloud sync",
              description: "Sync across all your devices"
            )

            FeatureRow(
              icon: "square.and.arrow.up.fill",
              title: "More share templates",
              description: "Beautiful templates for sharing"
            )
          }
          .padding()

          // Pricing Section
          VStack(spacing: 16) {
            if storeManager.isLoading {
              ProgressView()
                .padding(.vertical, 40)
            } else if storeManager.products.isEmpty {
              Text("Unable to load plans")
                .foregroundColor(.secondary)
                .padding(.vertical, 40)
            } else {
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
          .padding(.horizontal, 24)

          // CTA Section
          VStack(spacing: 8) {
            VStack(spacing: 16) {
              // Toggle for free version
                Toggle(isOn: $useFreeVersion) {
                  Text("Skip Super")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .toggleStyle(.switch)
                .frame(width: 150)
              .padding(.horizontal, 48)

              // Main CTA Button
              if let selectedID = selectedProductID,
                 let product = storeManager.products.first(where: { $0.id == selectedID }) {
                VStack(spacing: 0) {
                  if useFreeVersion {
                    Button {
                      viewModel.isPremium = false
                      viewModel.completeStep(.paywall)
                    } label: {
                      Text("Continue for free")
                        .font(.headline)
                    }
                    .buttonStyle(OnboardingSecondaryButtonStyle())
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

                if !useFreeVersion {
                  Text("Then \(product.displayPrice) / \(product.id.contains("monthly") ? "month" : "year"). Cancel anytime.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, -8)
                }
              } else {
                if useFreeVersion {
                  Button {
                    viewModel.isPremium = false
                    viewModel.completeStep(.paywall)
                  } label: {
                    Text("Continue for free")
                      .font(.headline)
                  }
                  .buttonStyle(OnboardingSecondaryButtonStyle())
                } else {
                  Button {
                    // Select yearly by default
                    if let yearly = storeManager.yearlyProduct {
                      selectedProductID = yearly.id
                    }
                  } label: {
                    Text("Select a Plan")
                      .font(.headline)
                  }
                  .buttonStyle(OnboardingButtonStyle())
                }
              }
            }
            .padding(.horizontal, 24)

            // Restore Purchases
            Button {
              Task {
                await storeManager.restorePurchases()
                if storeManager.hasActiveSubscription {
                  viewModel.isPremium = true
                  viewModel.completeStep(.paywall)
                }
              }
            } label: {
              Text("Restore Purchases")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          // Legal Links
          HStack(spacing: 16) {
            Link("Terms of Service", destination: URL(string: "https://joodle.liyuxuan.dev/terms-of-service")!)
            Text("•")
            Link("Privacy Policy", destination: URL(string: "https://joodle.liyuxuan.dev/privacy-policy")!)
          }
          .font(.caption2)
          .foregroundColor(.secondary)
          .padding(.bottom, 20)
        }
      }
    }
    .navigationBarBackButtonHidden(true)
    .alert("Error", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      if let error = storeManager.errorMessage {
        Text(error)
      }
    }
    .onAppear {
      // Debug: Log StoreKit status
      print("📱 PaywallView appeared")
      print("📦 Products loaded: \(storeManager.products.count)")
      if storeManager.products.isEmpty {
        print("⚠️ No products loaded!")
        print("⚠️ Go to: Edit Scheme → Run → Options → StoreKit Configuration")
        print("⚠️ Select: SyncedProducts.storekit")
      }
    }
    .onChange(of: storeManager.products) { _, newProducts in
      // Auto-select yearly when products load
      if selectedProductID == nil, !newProducts.isEmpty {
        selectedProductID = storeManager.yearlyProduct?.id
      }
    }
    .onChange(of: storeManager.errorMessage) { _, newValue in
      showError = newValue != nil
    }
  }

  // MARK: - Helper Methods

  private func handlePurchase(_ product: Product) {
    isPurchasing = true

    Task {
      do {
        let transaction = try await storeManager.purchase(product)

        if transaction != nil {
          // Purchase successful
          viewModel.isPremium = true
          viewModel.completeStep(.paywall)
        }
      } catch {
        print("Purchase failed: \(error)")
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

// MARK: - Feature Row

struct FeatureRow: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 24))
        .foregroundColor(.accent)
        .frame(width: 40, height: 40)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
          .foregroundColor(.primary)

        Text(description)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .padding(.horizontal, 16)
  }
}

// MARK: - Pricing Card

struct PricingCard: View {
  let product: Product
  let isSelected: Bool
  let badge: String?
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      ZStack(alignment: .topTrailing) {
        VStack(spacing: 0) {
          HStack {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text(product.id.contains("yearly") ? "Joodle Super Yearly" : "Joodle Super Monthly")
                  .font(.title3.weight(.bold))
                  .foregroundColor(.primary)

                Spacer()

                // Selection indicator
                ZStack {
                  Circle()
                    .strokeBorder(isSelected ? .accent : .secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                  if isSelected {
                    Circle()
                      .fill(.accent)
                      .frame(width: 14, height: 14)
                  }
                }
              }

              HStack(alignment: .firstTextBaseline, spacing: 4) {
                if product.id.contains("yearly") {
                  Text(yearlyMonthlyPrice())
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                  Text("/ month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } else {
                  Text(product.displayPrice)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                  Text("/ month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
              }

              Text("Billed \(product.id.contains("yearly") ? "yearly" : "monthly") at \(product.displayPrice)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
          }
          .padding(20)
        }
        .background(
          RoundedRectangle(cornerRadius: 32)
            .fill(.appBorder.opacity(0.3))
            .overlay(
              RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(isSelected ? .accent : Color.clear, lineWidth: 2)
            )
        )

        // Badge - overlaid on top
        if let badge = badge {
          Text(badge)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
              Capsule()
                .fill(.accent)
            )
            .offset(x: -0, y: -12)
        }
      }
    }
    .buttonStyle(PlainButtonStyle())
  }

  private func yearlyMonthlyPrice() -> String {
    // Calculate monthly price from yearly
    let yearlyPrice = product.price
    let monthlyEquivalent = yearlyPrice / 12

    // Use the product's priceFormatStyle locale for consistent formatting
    return monthlyEquivalent.formatted(
      .currency(code: product.priceFormatStyle.currencyCode)
      .locale(product.priceFormatStyle.locale)
    )
  }
}

#Preview {
  PaywallView(viewModel: OnboardingViewModel())
    .environment(\.locale, Locale(identifier: "ja_JP"))
}
