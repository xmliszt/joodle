//
//  FeatureIntroEditEntryView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: How to  scrub
struct FeatureIntroScrubView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        FeatureIntroStepView(
            title: "Scrub through your days",
            description: "Tap on an entry, hold it, and swipe to begin scrubbing through your memories.",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Scrub1"),
                    dots: [
                      TapDot(x: 286, y: 620)
                    ]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Scrub2"),
                    dots: [
                      TapDot(x: 158, y: 376)
                    ]
                )
            ],
            buttonLabel: "Next",
            onContinue: {
                viewModel.completeStep(.featureIntroScrubbing)
            },
            onBack: {
                viewModel.goBack()
            }
        )
    }
}

// MARK: - Previews

#Preview("Scrub step") {
  FeatureIntroScrubView(viewModel: OnboardingViewModel())
}
