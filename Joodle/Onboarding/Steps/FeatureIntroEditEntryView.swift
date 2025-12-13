//
//  FeatureIntroEditEntryView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: How to edit Joodle and note for a day
struct FeatureIntroEditEntryView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        FeatureIntroStepView(
            title: "Create or edit a day entry",
            description: "Select any day to create or edit the Joodle, and add additional note to your story",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Entry"),
                    dots: [
                      TapDot(x: 675, y: 880),
                      TapDot(x: 160, y: 940)
                    ]
                )
            ],
            buttonLabel: "Next",
            onContinue: {
                viewModel.completeStep(.featureIntroEditEntry)
            },
            onBack: {
                viewModel.goBack()
            }
        )
    }
}

// MARK: - Previews

#Preview("Edit Entry Step") {
    FeatureIntroEditEntryView(viewModel: OnboardingViewModel())
}
