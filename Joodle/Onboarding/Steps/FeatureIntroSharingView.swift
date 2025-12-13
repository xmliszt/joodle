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
                    image: Image("Onboarding/Sharing"),
                    dots: [
                      TapDot(x: 583, y: 255),
                      TapDot(x: 126, y: 880)
                    ]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/SharingDay"),
                    dots: []
                ),
                ScreenshotItem(
                    image: Image("Onboarding/SharingYear"),
                    dots: []
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
