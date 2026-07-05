//
//  StandalonePaywallView.swift
//  Joodle
//
//  Standalone paywall view presented as a bottom sheet
//

import SwiftUI
import StoreKit

struct StandalonePaywallView: View {
    let source: String
    var context: PaywallContext = .expired

    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var ltoManager = LimitedTimeOfferManager.shared
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
                        context: context,
                        useOnboardingStyle: false,
                        paywallSource: source,
                        onPurchaseComplete: {
                            Task { @MainActor in
                                await subscriptionManager.updateSubscriptionStatus()
                                dismiss()
                            }
                        },
                        onContinueFree: nil,
                        onRestoreComplete: {
                            Task { @MainActor in
                                await subscriptionManager.updateSubscriptionStatus()
                                dismiss()
                            }
                        }
                    ))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.appFont(size: 15, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        // The paywall commits to a dark, premium look — the live feature demos
        // are designed against dark, and it reads as more premium than the
        // adaptive app chrome.
        .preferredColorScheme(.dark)
        .postHogScreenView("Paywall - Standalone")
        .onChange(of: ltoManager.isActive) { _, active in
            // The countdown hit zero under the open sheet — the offer is gone,
            // so the sheet goes with it. A purchase also flips isActive, but
            // that path dismisses via onPurchaseComplete after its own flow.
            if context == .limitedTimeOffer, !active, !subscriptionManager.isSubscribed {
                dismiss()
            }
        }
        .task {
            // Refresh subscription status from StoreKit before showing paywall
            await subscriptionManager.updateSubscriptionStatus()

            // The pay screen is pointless for someone who already has premium — dismiss it.
            // The trial-status sheet is the exception: a trial user DOES have premium access
            // (via the grace period), and seeing their own trial status is the whole point.
            if context == .expired, subscriptionManager.hasPremiumAccess {
                dismiss()
                return
            }

            // The offer sheet stays for grace-period trial users — the trial
            // shouldn't block buying the discounted plan early. Only a real
            // purchase (subscription or lifetime) makes it pointless.
            if context == .limitedTimeOffer, subscriptionManager.isSubscribed {
                dismiss()
                return
            }

            isCheckingSubscription = false
            AnalyticsManager.shared.trackPaywallViewed(source: source)
        }
    }
}

#Preview {
    StandalonePaywallView(source: "preview")
}
