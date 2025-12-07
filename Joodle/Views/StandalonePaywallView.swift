//
//  StandalonePaywallView.swift
//  Joodle
//
//  Created by Standalone Paywall View
//

import SwiftUI
import StoreKit

struct StandalonePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Section
                        VStack(spacing: 8) {
                            Text("Get Joodle Super")
                                .font(.system(size: 34, weight: .bold))
                                .multilineTextAlignment(.center)

                            Text("Supercharge your creativity with unlimited features")
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
                                subtitle: "Draw as many as you want, no limits"
                            )

                            FeatureRow(
                                icon: "square.grid.3x3.fill",
                                title: "Home Screen Widgets",
                                subtitle: "Add Joodle widgets to your Home Screen"
                            )

                            FeatureRow(
                                icon: "checkmark.icloud.fill",
                                title: "iCloud sync",
                                subtitle: "Sync across all your devices"
                            )

                            FeatureRow(
                                icon: "square.and.arrow.up.fill",
                                title: "More share templates",
                                subtitle: "Beautiful templates for sharing"
                            )
                        }
                        .padding()

                        // Pricing Section
                        VStack(spacing: 16) {
                            if storeManager.isLoading {
                                ProgressView()
                                    .padding(.vertical, 40)
                            } else if storeManager.products.isEmpty {
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

                                    #if DEBUG
                                    // Debug info only shown in debug builds
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
                                    }
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.top, 8)
                                    #endif
                                }
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
                        VStack(spacing: 16) {
                            if let selectedID = selectedProductID,
                               let product = storeManager.products.first(where: { $0.id == selectedID }) {
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
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.accent)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                }
                                .disabled(isPurchasing)

                                Text("Then \(product.displayPrice) / \(product.id.contains("monthly") ? "month" : "year"). Cancel anytime.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
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

                            // Restore Purchases
                            Button {
                                Task {
                                    await storeManager.restorePurchases()
                                    if storeManager.hasActiveSubscription {
                                        await subscriptionManager.updateSubscriptionStatus()
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)

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

                if isPurchasing || storeManager.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
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
                // Debug: Log StoreKit status
                print("📱 StandalonePaywallView appeared")
                print("📦 Products loaded: \(storeManager.products.count)")
                print("📦 Is loading: \(storeManager.isLoading)")
                print("📦 Error message: \(storeManager.errorMessage ?? "none")")

                if selectedProductID == nil, !storeManager.products.isEmpty {
                    selectedProductID = storeManager.yearlyProduct?.id
                }

                if storeManager.products.isEmpty && !storeManager.isLoading {
                    print("⚠️ No products loaded!")
                    print("⚠️ If running in Xcode: Check Edit Scheme → Run → Options → StoreKit Configuration")
                    print("⚠️ If running in TestFlight: Products must be configured in App Store Connect")
                    print("⚠️ Expected product IDs: dev.liyuxuan.joodle.super.monthly, dev.liyuxuan.joodle.super.yearly")

                    // Try to reload products if none are loaded
                    Task {
                        await storeManager.loadProducts()
                    }
                }
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
    }

    // MARK: - Helper Methods

    private func handlePurchase(_ product: Product) {
        isPurchasing = true

        Task {
            do {
                let transaction = try await storeManager.purchase(product)

                if transaction != nil {
                    await subscriptionManager.updateSubscriptionStatus()
                    dismiss()
                }
            } catch {
                print("Purchase failed: \(error)")
                showError = true
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

#Preview {
    StandalonePaywallView()
}
