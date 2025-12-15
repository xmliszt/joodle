//
//  FeatureIntroSharingView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: Color theme
struct FeatureIntroColorThemeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        FeatureIntroStepView(
            title: "Don't Like Orange?",
            description: "Choose from a variety of color themes to make Joodle truly yours!",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Theme1"),
                    dots: [
                      TapDot(x: 300, y: 693)
                    ]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Theme2")
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

#Preview {
  FeatureIntroColorThemeView(viewModel: OnboardingViewModel())
}
