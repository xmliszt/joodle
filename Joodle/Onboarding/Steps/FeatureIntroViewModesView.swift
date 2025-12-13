//
//  FeatureIntroViewModesView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: Toggle between regular and minimized view
struct FeatureIntroViewModesView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        FeatureIntroStepView(
            title: "Two ways to view",
            description: "Tap to switch between normal and minimized view. Normal view zooms in for better visibility and seletion. Minimized view gives you a glance at the entire year. Pinch with two fingers also work!",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Regular"),
                    dots: [TapDot(x: 517, y: 164)]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Minimized"),
                    dots: [TapDot(x: 517, y: 164)]
                )
            ],
            buttonLabel: "Next",
            onContinue: {
                viewModel.completeStep(.featureIntroViewModes)
            },
            onBack: {
                viewModel.goBack()
            }
        )
    }
}

// MARK: - Previews

#Preview("View Modes Step") {
    FeatureIntroViewModesView(viewModel: OnboardingViewModel())
}
