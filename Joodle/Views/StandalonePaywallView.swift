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

    var body: some View {
        NavigationStack {
            ZStack {
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
}

#Preview {
    StandalonePaywallView()
}
