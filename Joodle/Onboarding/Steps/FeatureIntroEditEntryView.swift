//
//  FeatureIntroEditEntryView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: How to edit Joodle and note for a day
struct FeatureIntroEditEntryView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    // Dot positions - adjust these in preview to match screenshot
    private let entryDot = TapDot(x: 400, y: 741)

    var body: some View {
        FeatureIntroStepView(
            title: "Create or edit a day entry",
            description: "Select any day to create or edit the Joodle, and add a note",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Entry"),
                    dot: entryDot
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
