//
//  FeatureIntroSharingView.swift
//  Joodle
//

import SwiftUI

/// Feature introduction step: Shortcuts
struct FeatureIntroShortcutView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        FeatureIntroStepView(
            title: "Quick access right from your search bar, or via Siri",
            description: "Joodle supports Siri Shortcuts, which means you can summon it from the search bar, or even with your voice!",
            screenshots: [
                ScreenshotItem(
                    image: Image("Onboarding/Shortcut1")
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Shortcut2"),
                    dots: [
                      TapDot(x: 532, y: 728)
                    ]
                ),
                ScreenshotItem(
                    image: Image("Onboarding/Shortcut3")
                )
            ],
            buttonLabel: "Next",
            onContinue: {
                viewModel.completeStep(.featureIntroShortcuts)
            },
            onBack: {
                viewModel.goBack()
            }
        )
    }
}

// MARK: - Previews

#Preview {
  FeatureIntroShortcutView(viewModel: OnboardingViewModel())
}
