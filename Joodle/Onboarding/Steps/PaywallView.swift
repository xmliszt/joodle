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

    var body: some View {
        ZStack {
            PaywallContentView(configuration: PaywallConfiguration(
                useOnboardingStyle: true,
                onPurchaseComplete: {
                    viewModel.isPremium = true
                    viewModel.completeStep(.paywall)
                },
                onContinueFree: {
                    viewModel.isPremium = false
                    viewModel.completeStep(.paywall)
                },
                onRestoreComplete: {
                    viewModel.isPremium = true
                    viewModel.completeStep(.paywall)
                }
            ))
        }
        .postHogScreenView("Paywall")
        .overlay(alignment: .topTrailing) {
            Button {
                // Track paywall skipped
                AnalyticsManager.shared.trackPaywallDismissed(source: "onboarding", didPurchase: false)
                viewModel.isPremium = false
                viewModel.completeStep(.paywall)
            } label: {
                Text("Skip")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    PaywallView(viewModel: OnboardingViewModel())
        .environment(\.locale, Locale(identifier: "ja_JP"))
}
