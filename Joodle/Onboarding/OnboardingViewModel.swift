import SwiftData
import SwiftUI
import Combine

// 1. The Steps: Easy to reorder or add new ones here.
enum OnboardingStep: Hashable, CaseIterable {
    case drawingEntry      // The greeting + drawing
    case valueProposition  // Confetti + Explanation
    case paywall           // Subscription choice
    // case icloudConfig   // Skipped for V1
    case widgetTutorial    // Final welcome (hidden for now)
    case onboardingCompletion // Completion step
}

// 2. The Brain: Manages data and navigation logic
@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()

    // Data collected during onboarding
    // We store the raw JSON data representing [PathData]
    @Published var firstDoodleData: Data?
    @Published var isPremium: Bool = false
    @Published var shouldDismiss = false

    var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Monitor subscription status changes
        SubscriptionManager.shared.$isSubscribed
            .assign(to: &$isPremium)
    }

    // Actions
    func completeStep(_ step: OnboardingStep) {
        switch step {
        case .drawingEntry:
            navigationPath.append(OnboardingStep.valueProposition)

        case .valueProposition:
            // Skip paywall and finish immediately if user already has an active subscription
            if StoreKitManager.shared.hasActiveSubscription {
                finishOnboarding()
            } else {
                navigationPath.append(OnboardingStep.paywall)
            }

        case .paywall:
            // Skip widget tutorial (not ready), go straight to completion
            navigationPath.append(OnboardingStep.onboardingCompletion)

        case .widgetTutorial:
            // Widget tutorial is currently hidden, but if somehow reached, go to completion
            navigationPath.append(OnboardingStep.onboardingCompletion)

        case .onboardingCompletion:
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        // Save flags to UserDefaults to hide onboarding on next launch
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Update subscription status if premium was set during onboarding
        if isPremium {
            SubscriptionManager.shared.grantSubscription()
        }

        shouldDismiss = true

        if let data = firstDoodleData, let context = modelContext {
            let today = Date()
            let startOfDay = Calendar.current.startOfDay(for: today)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

            // Check for existing entry to avoid duplicates
            let predicate = #Predicate<DayEntry> { entry in
                entry.createdAt >= startOfDay && entry.createdAt < endOfDay
            }
            let descriptor = FetchDescriptor<DayEntry>(predicate: predicate)

            let entryToUpdate: DayEntry

            do {
                let existingEntries = try context.fetch(descriptor)
                if let existing = existingEntries.first {
                    entryToUpdate = existing
                    entryToUpdate.drawingData = data
                } else {
                    entryToUpdate = DayEntry(body: "", createdAt: today, drawingData: data)
                    context.insert(entryToUpdate)
                }

                // Generate thumbnails
                Task {
                    let thumbnails = await DrawingThumbnailGenerator.shared.generateThumbnails(from: data)
                    entryToUpdate.drawingThumbnail20 = thumbnails.0
                    entryToUpdate.drawingThumbnail200 = thumbnails.1
                    entryToUpdate.drawingThumbnail1080 = thumbnails.2
                    try? context.save()
                }
            } catch {
                print("Failed to fetch/save entry: \(error)")
            }
        }
    }
}
