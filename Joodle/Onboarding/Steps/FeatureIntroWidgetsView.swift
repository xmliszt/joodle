//
//  FeatureIntroWidgetsView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: Widgets for home screen, lock screen, and standby
struct FeatureIntroWidgetsView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        FeatureIntroStepView(
            title: "Widgets everywhere",
            description: "Add Joodle to your home screen, lock screen, or even in StandBy mode",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/WidgetHomeScreen1")
                ),
                ScreenshotItem(
                    image: Image("Onboarding/WidgetHomeScreen2")
                ),
                ScreenshotItem(
                    image: Image("Onboarding/WidgetLockScreen")
                ),
                ScreenshotItem(
                    image: Image("Onboarding/WidgetStandby1"),
                    orientation: .landscape
                ),
                ScreenshotItem(
                    image: Image("Onboarding/WidgetStandby2"),
                    orientation: .landscape
                )
            ],
            buttonLabel: "Continue",
            onContinue: {
                viewModel.completeStep(.featureIntroWidgets)
            },
            onBack: {
                viewModel.goBack()
            }
        )
    }
}

// MARK: - Previews

#Preview("Widgets Step") {
    FeatureIntroWidgetsView(viewModel: OnboardingViewModel())
}
