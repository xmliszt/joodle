//
//  FeatureIntroYearSwitchingView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: Year switching and anniversary countdown
struct FeatureIntroYearSwitchingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        FeatureIntroStepView(
            title: "Plan your anniversaries",
            description: "Tap the year to switch and add future entries to countdown to your special days.",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Entry"),
                    dots: [TapDot(x: 100, y: 164)]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Countdown1"),
                    dots: [TapDot(x: 128, y: 230)]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Countdown2")
                )
            ],
            buttonLabel: "Next",
            onContinue: {
                viewModel.completeStep(.featureIntroYearSwitching)
            },
            onBack: {
                viewModel.goBack()
            }
        )
    }
}

// MARK: - Previews

#Preview("Year Switching Step") {
    FeatureIntroYearSwitchingView(viewModel: OnboardingViewModel())
}
