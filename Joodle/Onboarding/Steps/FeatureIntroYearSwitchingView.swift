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
            title: "Plan ahead",
            description: "Tap the year to switch and add future events to countdown",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Entry"),
                    dot: TapDot(x: 150, y: 250)
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Countdown1"),
                    dot: TapDot(x: 170, y: 325)
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Countdown2"),
                    dots: []
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
