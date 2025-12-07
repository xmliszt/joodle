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
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                SubscriptionPromptView()
            }
    }
}

// MARK: - Subscription Prompt View

struct SubscriptionPromptView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProductID: String?
    @State private var isPurchasing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.3), radius: 10)

                VStack(spacing: 12) {
                    Text("Upgrade to Joodle Super")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text("Unlock unlimited doodles, all widgets, iCloud sync, and more!")
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

// MARK: - Doodle Limit Helper

extension SubscriptionManager {
    /// Check if user can create a new doodle based on their plan
    func canCreateDoodle(currentCount: Int) -> Bool {
        if hasUnlimitedDoodles {
            return true
        }

        return currentCount < doodlesPerYear
    }

    /// Get remaining doodles for free users
    func remainingDoodles(currentCount: Int) -> Int {
        if hasUnlimitedDoodles {
            return Int.max
        }

        return max(0, doodlesPerYear - currentCount)
    }

    /// Get count of doodles created in the past year
    func doodleCountThisYear(from entries: [DayEntry]) -> Int {
        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date())!

        return entries.filter { entry in
            entry.drawingData != nil && entry.createdAt >= oneYearAgo
        }.count
    }
}

// MARK: - Feature Gate Helper

/// Use this to gate features behind subscription
struct FeatureGate {
    @MainActor
    static func checkAccess(
        for feature: Feature,
        showPaywall: @escaping () -> Void
    ) -> Bool {
        let manager = SubscriptionManager.shared

        switch feature {
        case .unlimitedDoodles:
            if !manager.hasUnlimitedDoodles {
                showPaywall()
                return false
            }

        case .allWidgets:
            if !manager.hasAllWidgets {
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
        case unlimitedDoodles
        case allWidgets
        case iCloudSync
        case allShareTemplates
    }
}

// MARK: - Badge View for Premium Features

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
                        colors: [.yellow, .orange],
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
