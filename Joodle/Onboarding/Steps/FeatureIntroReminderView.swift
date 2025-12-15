//
//  FeatureIntroSharingView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: Reminders
struct FeatureIntroReminderView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        FeatureIntroStepView(
            title: "Never miss an anniversary",
            description: "Create a reminder for the current day, or any future date, so that you will never miss an important date again.",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Reminder1"),
                    dots: [
                      TapDot(x: 154, y: 747)
                    ]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Reminder2"),
                    dots: [
                      TapDot(x: 300, y: 1140)
                    ]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Reminder3"),
                    dots: [
                      TapDot(x: 154, y: 747)
                    ]
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
  FeatureIntroReminderView(viewModel: OnboardingViewModel())
}
