//
//  SubscriptionExtensions.swift
//  Joodle
//
//  Created by Subscription Extensions
//

import Foundation
import SwiftUI

// MARK: - View Extensions

extension View {
    /// Shows a paywall if the user is not subscribed
    func requiresSubscription(isPresented: Binding<Bool>) -> some View {
        self.modifier(SubscriptionRequiredModifier(isPresented: isPresented))
    }
}

struct SubscriptionRequiredModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                SubscriptionPromptView()
            }
    }
}

// MARK: - Subscription Prompt View

/// A quick upgrade prompt view for showing when premium features are accessed
struct SubscriptionPromptView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isPurchasing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.accent)
                    .shadow(color: .accent.opacity(0.3), radius: 10)

                VStack(spacing: 12) {
                    Text("Upgrade to Joodle Super")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text("Unlock unlimited Joodles, all widgets, iCloud sync, and more!")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        handleUpgrade()
                    } label: {
                        if isPurchasing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                        } else {
                            Text("Upgrade Now")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPurchasing)

                    Button("Not Now") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func handleUpgrade() {
        isPurchasing = true

        Task {
            // Default to yearly product
            guard let product = storeManager.yearlyProduct ?? storeManager.products.first else {
                isPurchasing = false
                return
            }

            do {
                let transaction = try await storeManager.purchase(product)
                if transaction != nil {
                    await subscriptionManager.updateSubscriptionStatus()
                    dismiss()
                }
            } catch {
                print("Purchase failed: \(error)")
            }

            isPurchasing = false
        }
    }
}

// MARK: - Legacy Feature Gate (Deprecated - Use PremiumFeature instead)

/// Use this to gate features behind subscription
/// @available(*, deprecated, message: "Use PremiumFeature enum and PremiumAccessController instead")
struct FeatureGate {
    @MainActor
    static func checkAccess(
        for feature: Feature,
        showPaywall: @escaping () -> Void
    ) -> Bool {
        let manager = SubscriptionManager.shared

        switch feature {
        case .unlimitedJoodles:
            if !manager.hasUnlimitedJoodles {
                showPaywall()
                return false
            }

        case .allWidgets:
            if !manager.hasWidgets {
                showPaywall()
                return false
            }

        case .iCloudSync:
            if !manager.hasICloudSync {
                showPaywall()
                return false
            }

        case .allShareTemplates:
            if !manager.hasAllShareTemplates {
                showPaywall()
                return false
            }
        }

        return true
    }

    enum Feature {
        case unlimitedJoodles
        case allWidgets
        case iCloudSync
        case allShareTemplates
    }
}

// MARK: - Badge View for Premium Features (Legacy - Use PremiumFeatureBadge instead)

/// @available(*, deprecated, message: "Use PremiumFeatureBadge from PremiumFeature.swift instead")
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 10))
            Text("SUPER")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.yellow, .accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
}

#Preview {
    SubscriptionPromptView()
}
