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
            description: "Tap to switch between regular and minimized view. Regular view zooms in for better visibility and seletion. Minimized view gives you a glance at the entire year.",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Regular"),
                    dot: TapDot(x: 672, y: 255)
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Minimized"),
                    dot: TapDot(x: 672, y: 255)
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
