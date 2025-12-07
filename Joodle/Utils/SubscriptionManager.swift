//
//  SubscriptionManager.swift
//  Joodle
//
//  Created by Subscription Manager
//

import Foundation
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isSubscribed: Bool {
        didSet {
            UserDefaults.standard.set(isSubscribed, forKey: "isJoodleSuper")
        }
    }

    private init() {
        self.isSubscribed = UserDefaults.standard.bool(forKey: "isJoodleSuper")

        // Start monitoring subscription status
        Task {
            await updateSubscriptionStatus()
        }
    }

    // MARK: - Subscription Features

    var hasUnlimitedDoodles: Bool {
        isSubscribed
    }

    var hasAllWidgets: Bool {
        isSubscribed
    }

    var hasICloudSync: Bool {
        isSubscribed
    }

    var hasAllShareTemplates: Bool {
        isSubscribed
    }

    // Free plan limits
    var doodlesPerYear: Int {
        isSubscribed ? Int.max : 60
    }

    // MARK: - Update Status

    func updateSubscriptionStatus() async {
        let hasActive = StoreKitManager.shared.hasActiveSubscription
        self.isSubscribed = hasActive
    }

    func grantSubscription() {
        self.isSubscribed = true
    }

    func revokeSubscription() {
        self.isSubscribed = false
    }
}
