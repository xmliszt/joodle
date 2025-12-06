import SwiftData
import SwiftUI

// 1. The Steps: Easy to reorder or add new ones here.
enum OnboardingStep: Hashable, CaseIterable {
    case drawingEntry      // The greeting + drawing
    case valueProposition  // Confetti + Explanation
    case paywall           // Subscription choice
    // case icloudConfig   // Skipped for V1
    case widgetTutorial    // Final welcome
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

    // Actions
    func completeStep(_ step: OnboardingStep) {
        switch step {
        case .drawingEntry:
            navigationPath.append(OnboardingStep.valueProposition)

        case .valueProposition:
            navigationPath.append(OnboardingStep.paywall)

        case .paywall:
            // V1: Skip iCloud config, go straight to widget tutorial
            navigationPath.append(OnboardingStep.widgetTutorial)

        case .widgetTutorial:
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        // Save flags to UserDefaults to hide onboarding on next launch
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
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
