//
//  FeatureIntroStepView.swift
//  Joodle
//

import SwiftUI

/// A consistent layout wrapper for all feature introduction steps.
/// Layout: Back button (top-left) → Title → Screenshot Carousel → Description → CTA Button
struct FeatureIntroStepView: View {
    let title: String
    let description: String
    let screenshots: [ScreenshotItem]
    let buttonLabel: String
    let onContinue: () -> Void
    var onBack: (() -> Void)? = nil
    var autoScrollInterval: TimeInterval = 3.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                // Title at the top
                Text(title)
                    .font(.appTitle2(weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 16) // Space for back button

                // Screenshot carousel - takes available space
                ScreenshotCarouselView(
                    screenshots: screenshots,
                    autoScrollInterval: autoScrollInterval
                )

              
                VStack (spacing: 32) {
                  // Description below screenshots
                  Text(description)
                      .font(.appBody())
                      .foregroundColor(.secondary)
                      .multilineTextAlignment(.center)
                      .lineSpacing(4)
                      .padding(.horizontal, 24)

                  // Continue button at bottom
                  OnboardingButtonView(label: buttonLabel) {
                      onContinue()
                  }
                }
            }

            // Back button in top left corner
            if let onBack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "arrow.left")
                }
                .circularGlassButton(tintColor: .primary)
                .padding(.leading, 16)
                .padding(.top, 8)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Previews

#Preview("Basic Feature Intro") {
    FeatureIntroStepView(
        title: "Create or edit a day entry",
        description: "Select any day to create or edit the Joodle, and add a note",
        screenshots: [
            ScreenshotItem(
                image: Image("Onboarding/WidgetHomeScreen1")
            )
        ],
        buttonLabel: "Next",
        onContinue: {},
        onBack: {}
    )
}

#Preview("With Carousel") {
    FeatureIntroStepView(
        title: "Two ways to view",
        description: "Tap here to switch between regular and year-at-a-glance view",
        screenshots: [
            ScreenshotItem(
                image: Image("Onboarding/WidgetHomeScreen1")
            ),
            ScreenshotItem(
                image: Image("Onboarding/WidgetHomeScreen1")
            )
        ],
        buttonLabel: "Got it",
        onContinue: {},
        onBack: {}
    )
}

#Preview("Without Back Button") {
    FeatureIntroStepView(
        title: "Widgets everywhere",
        description: "Add Joodle to your home screen, lock screen, or standby",
        screenshots: [
            ScreenshotItem(image: Image("Onboarding/WidgetsHomeScreen1")),
            ScreenshotItem(image: Image("Onboarding/WidgetsLockScreen")),
            ScreenshotItem(
                image: Image("Onboarding/WidgetStandby1"),
                orientation: .landscape
            )
        ],
        buttonLabel: "Continue",
        onContinue: {}
    )
}

#Preview("Long Description") {
    FeatureIntroStepView(
        title: "Share your moments",
        description: "Share your entire year from the minimized view, or share individual days from the entry sheet",
        screenshots: [
            ScreenshotItem(
                image: Image("Onboarding/WidgetHomeScreen1")
            ),
            ScreenshotItem(
                image: Image("Onboarding/WidgetHomeScreen1")
            )
        ],
        buttonLabel: "Next",
        onContinue: {},
        onBack: {}
    )
}
