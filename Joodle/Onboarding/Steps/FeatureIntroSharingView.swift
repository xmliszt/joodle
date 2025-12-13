//
//  FeatureIntroSharingView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: Sharing options for year and individual days
struct FeatureIntroSharingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        FeatureIntroStepView(
            title: "Share your moments",
            description: "Share your entire year or individual day with friends",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Share"),
                    dots: [
                      TapDot(x: 446, y: 164),
                      TapDot(x: 82, y: 747)
                    ]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/ShareDay")
                ),
                ScreenshotItem(
                    image: Image("Onboarding/ShareYear")
                )
            ],
            buttonLabel: "Next",
            onContinue: {
                viewModel.completeStep(.featureIntroSharing)
            },
            onBack: {
                viewModel.goBack()
            }
        )
    }
}

// MARK: - Previews

#Preview("Sharing Step") {
    FeatureIntroSharingView(viewModel: OnboardingViewModel())
}
