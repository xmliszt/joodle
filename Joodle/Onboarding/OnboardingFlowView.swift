import SwiftData
import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            // STARTING POINT
            DrawingEntryView(viewModel: viewModel)
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .drawingEntry:
                        // Should not happen via navigation, but handled for safety
                        DrawingEntryView(viewModel: viewModel)
                    case .valueProposition:
                        ValuePropView(viewModel: viewModel)
                    case .yearGridDemo:
                        InteractiveTutorialView(viewModel: viewModel)
                    case .handednessSetup:
                        HandednessSetupView(viewModel: viewModel)
                    case .featureIntroWidgets:
                        FeatureIntroWidgetsView(viewModel: viewModel)
                    case .icloudConfig:
                        iCloudConfigView(viewModel: viewModel)
                    case .dailyReminder:
                        DailyReminderConfigView(viewModel: viewModel)
                    case .proIntro:
                        ProIntroStepView(viewModel: viewModel)
                    case .onboardingCompletion:
                        OnboardingCompletionView(viewModel: viewModel)
                    }
                }
        }
        .tint(.primary) // Sets the back button color globally
        .onAppear {
            viewModel.modelContext = modelContext
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
        .postHogScreenView("Onboarding")
    }
}

// MARK: - Pro Intro Step

/// Onboarding step that shows the informative Joodle Pro trial intro
/// (value + 7-day trial timeline, no purchase). "Continue" advances without commitment.
struct ProIntroStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        PaywallContentView(configuration: PaywallConfiguration(
            context: .onboarding,
            paywallSource: "onboarding_pro_intro",
            onContinueFree: {
                viewModel.completeStep(.proIntro)
            }
        ))
        .postHogScreenView("Onboarding Pro Intro")
    }
}
