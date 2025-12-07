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

    // Control whether to show the "Skip Super" toggle
    var showFreeVersionToggle: Bool = true

    var body: some View {
        ZStack {
            PaywallContentView(configuration: PaywallConfiguration(
                showFreeVersionToggle: showFreeVersionToggle,
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
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    PaywallView(viewModel: OnboardingViewModel(), showFreeVersionToggle: true)
        .environment(\.locale, Locale(identifier: "ja_JP"))
}
