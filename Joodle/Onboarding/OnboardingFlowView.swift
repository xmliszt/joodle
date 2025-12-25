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
                    case .featureIntroWidgets:
                        FeatureIntroWidgetsView(viewModel: viewModel)
                    case .paywall:
                        PaywallView(viewModel: viewModel)
                    case .icloudConfig:
                        iCloudConfigView(viewModel: viewModel)
                    case .dailyReminder:
                        DailyReminderConfigView(viewModel: viewModel)
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
    }
}
