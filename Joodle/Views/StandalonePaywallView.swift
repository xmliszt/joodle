//
//  StandalonePaywallView.swift
//  Joodle
//
//  Standalone paywall view presented as a bottom sheet
//

import SwiftUI
import StoreKit

struct StandalonePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isPurchasing = false
    @State private var isCheckingSubscription = true

    var body: some View {
        NavigationStack {
            ZStack {
                if isCheckingSubscription {
                    // Show loading while checking subscription status
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    PaywallContentView(configuration: PaywallConfiguration(
                        useOnboardingStyle: false,
                        onPurchaseComplete: {
                            Task {
                                await subscriptionManager.updateSubscriptionStatus()
                                dismiss()
                            }
                        },
                        onContinueFree: nil,
                        onRestoreComplete: {
                            Task {
                                await subscriptionManager.updateSubscriptionStatus()
                                dismiss()
                            }
                        }
                    ))
                }
            }
        }
        .task {
            // Refresh subscription status from StoreKit before showing paywall
            await subscriptionManager.updateSubscriptionStatus()

            // If user is already subscribed, dismiss immediately
            if subscriptionManager.isSubscribed {
                dismiss()
                return
            }

            isCheckingSubscription = false
        }
    }
}

#Preview {
    StandalonePaywallView()
}
